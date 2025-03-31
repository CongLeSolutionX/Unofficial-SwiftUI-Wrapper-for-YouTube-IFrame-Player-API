---
created: 2025-03-31 05:31:26
author: Cong Le
version: "1.0"
license(s): Apache License 2.0, CC BY 4.0
copyright: Copyright (c) 2025 Cong Le. All Rights Reserved.
based_on: "https://github.com/youtube/youtube-ios-player-helper"
---


# Documentation: Unofficial SwiftUI Wrapper for YouTube IFrame Player API
> **Important Disclaimer & Notice:**
>
> This document and the accompanying code represent **personal notes and an unofficial implementation** created for educational purposes, study, and reference, based on the publicly available **YouTube IFrame Player API** and inspired by the official `youtube-ios-player-helper` project (available at [https://github.com/youtube/youtube-ios-player-helper](https://github.com/youtube/youtube-ios-player-helper)).
>
> **This project is NOT an official YouTube or Google product.** It is not affiliated with, endorsed by, or sponsored by Google LLC or YouTube. All trademarks, logos, and brand names associated with YouTube and Google are the property of their respective owners. Use of the YouTube IFrame Player API is subject to the [YouTube API Services Terms of Service](https://developers.google.com/youtube/terms/api-services-terms-of-service).
>
> The materials herein are provided "as is" without warranty of any kind. The author assumes no responsibility or liability for any errors or omissions in the content or for any actions taken based on the information provided.
>
> **Licensing:**
> The content is dual-licensed:
> 1.  **Apache License 2.0:** Applies to all **code implementations** (Swift, JavaScript snippets within the HTML, etc.). See the [LICENSE](LICENSE) file.
> 2.  **Creative Commons Attribution 4.0 International License (CC BY 4.0):** Applies to all **non-code content**, including explanatory text, diagrams (as visual representations), and illustrations. See the [LICENSE-CC-BY](LICENSE-CC-BY) file.
> ---

## Overall Purpose - A Diagrammatic Guide

This code implements a reusable SwiftUI view (`YouTubePlayerView`) that embeds a YouTube player using a `WKWebView`. It acts as a bridge between the JavaScript-based **YouTube IFrame Player API** and the native Swift/SwiftUI environment. This allows developers to control the player (play, pause, seek, etc.) from Swift and receive player events (state changes, errors, playback time) back into their SwiftUI application. The implementation handles both single video and playlist playback and includes mechanisms for coordinating multiple player instances within an app.

**Key Concepts Illustrated:**

1.  **Core Components and Structure**
2.  **SwiftUI <-> WKWebView Bridge (`UIViewRepresentable`)**
3.  **JavaScript <-> Swift Communication**
4.  **State Management (Player & View)**
5.  **Action Handling Flow**
6.  **Navigation and Security (`WKNavigationDelegate`)**
7.  **Multi-Player Interaction (`NotificationCenter`)**
8.  **Initialization and Parameter Injection**

---

### 1. Core Components and Structure

This diagram shows the main building blocks of the player implementation and their high-level relationships.

```mermaid
---
title: "Core Component Structure"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'sequenceDiagram': { 'htmlLabels': false},
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#BEF',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F29',
      'secondaryColor': '#EEE2'
    }
  }
}%%
graph TD
    subgraph SwiftUI_Layer["SwiftUI Layer"]
    style SwiftUI_Layer fill:#fee,stroke:#333,stroke-width:2px
        A["App Entry Point<br/>(YouTubePlayerSwiftUIApp)"] --> B(TabView)
        B --> C1(NavigationView)
        B --> C2(NavigationView)
        C1 --> V1[SingleVideoView]
        C2 --> V2[PlaylistView]
        V1 --> YPV((YouTubePlayerView))
        V2 --> YPV((YouTubePlayerView))
    end

    subgraph Bridge_Layer["Bridge Layer"]
    style Bridge_Layer fill:#bbb,stroke:#333,stroke-width:2px
        YPV -- Creates & Updates --> WV[WKWebView]
        YPV -- Owns & Configures --> CO[Coordinator]
    end

    subgraph WebKit_Layer["WebKit Layer"]
    style WebKit_Layer fill:#fb2,stroke:#333,stroke-width:2px
        WV -- Loads --> HTML["HTML/JS Content<br/>(youtubeHTML)"]
        WV -- Interacts via --> JSAPI["YouTube IFrame Player API"]
    end

    subgraph Communication_and_Delegate_Layer["Communication & Delegate Layer"]
    style Communication_and_Delegate_Layer fill:#bb2,stroke:#333,stroke-width:2px
        CO -- Conforms to --> WKMH(WKScriptMessageHandler)
        CO -- Conforms to --> WKND(WKNavigationDelegate)
        CO -- Conforms to --> WKUID(WKUIDelegate)
        WV -- Forwards JS Messages --> CO
        WV -- Forwards Navigation Events --> CO
        WV -- Forwards UI Events --> CO
        CO -- Calls Callbacks --> YPV
        YPV -- Receives Actions via Binding --> V1 & V2
        V1 & V2 -- Trigger Actions --> YPV
    end

    subgraph Data_Models["Data Models"]
    style Data_Models fill:#cf2,stroke:#333,stroke-width:2px
        DM1["Enums<br/>(PlayerState, PlaybackQuality, PlayerError)"]
        DM2[PlayerAction Enum]
    end

    CO -- Uses --> DM1 & DM2
    V1 & V2 -- Use --> DM2
    YPV -- Uses Callbacks with --> DM1

    style WV fill:#f9f,stroke:#333,stroke-width:2px
    style YPV fill:#ccf,stroke:#333,stroke-width:2px
    style CO fill:#ff9,stroke:#333,stroke-width:2px
    style HTML fill:#9cf,stroke:#333,stroke-width:1px

```

**Explanation:**

*   The SwiftUI layer contains the main App structure and the specific views (`SingleVideoView`, `PlaylistView`) that *use* the `YouTubePlayerView`.
*   `YouTubePlayerView` acts as the `UIViewRepresentable` bridge, creating and managing the `WKWebView` and its `Coordinator`.
*   The `WKWebView` loads the bundled `youtubeHTML` which contains the JavaScript code to interact with the **YouTube IFrame Player API**.
*   The `Coordinator` is the central hub, handling delegate methods from `WKWebView` (navigation, UI, JS messages) and translating communication between the web content and the SwiftUI view.
*   Data models (Enums) define the states, qualities, errors, and actions used throughout the system.

---

### 2. SwiftUI <-> WKWebView Bridge (`UIViewRepresentable` Lifecycle)

This diagram illustrates the lifecycle and data flow managed by the `YouTubePlayerView` struct conforming to `UIViewRepresentable`.

```mermaid
---
title: "UIViewRepresentable Lifecycle & Data Flow"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'sequenceDiagram': { 'htmlLabels': false},
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#BEF',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F29',
      'secondaryColor': '#EEE2'
    }
  }
}%%
graph LR
    subgraph SwiftUI["SwiftUI"]
    style SwiftUI fill:#fee,stroke:#333,stroke-width:2px
        SWUI["SwiftUI View<b/r>(e.g., SingleVideoView)"]
        StateProps["/State Properties<br/>(videoId, playlistId, playerVars, playerAction)/"]
        Callbacks["/Callback Closures<br/>(onReady, onStateChange, etc.)/"]
    end

    subgraph UIViewRepresentable["UIViewRepresentable"]
    style UIViewRepresentable fill:#ffb,stroke:#333,stroke-width:2px
        YPV[YouTubePlayerView]
        MakeUI(makeUIView)
        UpdateUI(updateUIView)
        MakeCoord(makeCoordinator)
    end

    subgraph Coordinator_and_WebView["Coordinator & WebView"]
    style Coordinator_and_WebView fill:#bfb,stroke:#333,stroke-width:2px
        Coord[Coordinator]
        WV[WKWebView]
        JS[JavaScript Bridge]
    end

    SWUI -- Passes Data --> StateProps
    SWUI -- Provides --> Callbacks
    StateProps -- Read By --> YPV
    Callbacks -- Stored By --> YPV

    YPV -- Creates --> MakeCoord
    MakeCoord --> Coord
    YPV -- Creates --> MakeUI
    MakeUI -- Configures & Returns --> WV
    MakeUI -- Sets Delegates --> Coord
    MakeUI -- Adds Script Handler --> Coord
    MakeUI -- Stores Ref --> Coord --> WV
    MakeUI -- Calls --> Coord --> Method1(performInitialLoad)

    SWUI -- Triggers Update --> YPV -- Calls --> UpdateUI
    UpdateUI -- Accesses --> Coord
    UpdateUI -- Reads --> StateProps
    UpdateUI -- Checks Binding --> StateProps --> Action{playerAction Changed?}
    Action -- Yes --> UpdateUI -- Calls --> Coord --> HandleAction(handleAction)
    UpdateUI -- Calls --> Coord --> UpdateSize(updateSize)
    UpdateUI -- Checks IDs --> StateProps --> Reload{ID Changed?}
    Reload -- Yes & Player Ready --> UpdateUI -- Calls --> Coord --> Method1

    Coord -- Receives JS Event --> Callbacks --> SWUI
    HandleAction -- Calls --> WV --> EvalJS(evaluateJavaScript)
    UpdateSize -- Calls --> WV --> EvalJS
    Method1 -- Calls --> WV --> LoadHTML(loadHTMLString)

    style YPV fill:#ccf,stroke:#333,stroke-width:2px
    style Coord fill:#ff9,stroke:#333,stroke-width:2px

```

**Explanation:**

*   SwiftUI provides initial data (`videoId`, callbacks, etc.) to `YouTubePlayerView`.
*   `makeCoordinator` creates the `Coordinator` instance.
*   `makeUIView` creates and configures the `WKWebView`, setting the `Coordinator` as its delegate and script message handler. It also triggers the initial HTML load via the `Coordinator`.
*   `updateUIView` is called when SwiftUI detects changes. It reads the latest state properties, checks for actions triggered via the `@Binding`, handles potential reloads if IDs change, and informs the JS player about size changes.
*   The `Coordinator` handles calls from `makeUIView`/`updateUIView` and translates them into actions on the `WKWebView` (loading HTML, evaluating JavaScript). It also receives events from JS and invokes the callback closures provided by the SwiftUI view.

---

### 3. JavaScript <-> Swift Communication Flow

This sequence diagram details how messages are passed between the JavaScript environment within the `WKWebView` and the native Swift `Coordinator`.

```mermaid
---
title: "JavaScript <-> Swift Communication"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'sequenceDiagram': { 'htmlLabels': false},
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#BEF',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F29',
      'secondaryColor': '#EEE2'
    }
  }
}%%
sequenceDiagram
    autonumber

    participant JS as JavaScript<br>(in WKWebView)
    participant WV as WKWebView
    participant CO as Coordinator<br>(WKScriptMessageHandler)
    participant YPV as YouTubePlayerView
    participant SWUI as SwiftUI View

    Note over JS, SWUI: Initial Load Sequence
    SWUI ->> YPV: Initialize with videoId/playlistId
    YPV ->> CO: makeCoordinator()
    YPV ->> WV: makeUIView() -> Creates WKWebView
    WV ->> CO: set delegates & message handler
    YPV ->> CO: performInitialLoad()
    CO ->> WV: loadHTMLString(finalHTML, baseURL)
    WV ->> JS: Execute HTML & JavaScript
    JS ->> WV: YouTube API Loads
    JS ->> JS: YT.Player() created
    
    
    alt API Load Success
        rect rgb(50, 10, 10)
            JS ->> JS: onYouTubeIframeAPIReady() called
            JS ->> JS: postMessageToNative('jsReady')
            WV ->> CO: userContentController(didReceive: 'jsReady')
            CO ->> YPV: (Optional logging)
            JS ->> JS: Player triggers 'onReady' event
            JS ->> JS: onReady() -> postMessageToNative('onReady')
            WV ->> CO: userContentController(didReceive: 'onReady')
            CO ->> CO: Set isPlayerReady = true
            CO ->> YPV: parent.onReady?()
            YPV ->> SWUI: Execute onReady Closure
        end
    else API Load Error
        rect rgb(50, 50, 10)
            JS ->> JS: handleApiLoadError() -> postMessageToNative('apiLoadError')
            WV ->> CO: userContentController(didReceive: 'apiLoadError')
            CO ->> YPV: parent.onError?(.html5Error)
            YPV ->> SWUI: Execute onError Closure
        end
    end


    Note over JS, SWUI: Swift Action -> JS Execution
    SWUI ->> YPV: Update @Binding playerAction = .play
    YPV ->> CO: updateUIView() -> handleAction(.play)
    CO ->> CO: Post Notification(.playbackStarted)
    CO ->> WV: evaluateJavaScript(player.playVideo())
    WV ->> JS: Execute "player.playVideo()"

    Note over JS, SWUI: JS Event -> Swift Callback
    JS ->> JS: Player state changes<br>(e.g., to Playing)
    JS ->> JS: onStateChange(YT.PlayerState.PLAYING)
    JS ->> JS: postMessageToNative('onStateChange', 1)
    WV ->> CO: userContentController(didReceive: 'onStateChange', data: 1)
    CO ->> CO: Parse data -> PlayerState.playing
    CO ->> YPV: parent.onStateChange?(.playing)
    YPV ->> SWUI: Execute onStateChange Closure

    Note over JS, SWUI: Play Time Update

    rect rgb(150, 150, 10)
        loop Every 500ms<br>(while playing)
            JS ->> JS: playTimeInterval fires
            JS ->> JS: currentTime = player.getCurrentTime()
            JS ->> JS: postMessageToNative('onPlayTime', currentTime)
            WV ->> CO: userContentController(didReceive: 'onPlayTime', data: ...)
            CO ->> CO: Parse data -> Float time
            CO ->> YPV: parent.onPlayTime?(time)
            YPV ->> SWUI: Execute onPlayTime Closure
        end
    end

```

**Explanation:**

*   **Initial Load:** Shows the sequence from SwiftUI initialization through HTML loading, JS execution, API readiness checks, and the final `onReady` signal back to Swift. It includes the API error handling path.
*   **Swift Action:** Demonstrates how a SwiftUI action (like setting `playerAction = .play`) flows through the `UIViewRepresentable` to the `Coordinator`, which evaluates the corresponding JavaScript command.
*   **JS Event:** Illustrates how an event triggered within the JS player (like a state change) is sent back via `postMessageToNative`, received by the `Coordinator`'s `userContentController` method, parsed, and finally triggers the appropriate Swift callback.
*   **Play Time:** Shows the periodic nature of the `onPlayTime` update using `setInterval` in JS.

---

### 4. Player State Management (`PlayerState` Enum & Transitions)

This state diagram visualizes the possible states of the YouTube player as defined by the `PlayerState` enum and typical transitions initiated by user actions or player events, reflecting the YouTube IFrame Player API states.

```mermaid
---
title: "Player State Transitions (YouTube API)"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'stateDiagram-v2': { 'htmlLabels': false, 'curve': 'linear' },
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#BEF',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F8B229',
      'secondaryColor': '#EE2',
      'tertiaryColor': '#fff',
      'stateBkgColor': '#eee',    # State background
      'stateBorderColor': '#666' # State border
    }
  }
}%%
stateDiagram-v2
    [*] --> Unstarted : Initial State (-1)

    Unstarted --> Buffering : loadVideo()/loadPlaylist()
    Buffering --> Playing : Buffering Complete (Event)
    Unstarted --> Cued : loadVideo()/loadPlaylist()<br>(Autoplay Off)
    Cued --> Playing : playVideo()

    Playing --> Paused : pauseVideo()
    Playing --> Buffering : Network Issue / seekTo()
    Playing --> Ended : Video Finishes (Event)
    Playing --> Unstarted : stopVideo() / New Load Call

    Paused --> Playing : playVideo()
    Paused --> Unstarted : stopVideo() / New Load Call

    Buffering --> Paused: pauseVideo()
    Buffering --> Unstarted: stopVideo() / New Load Call

    Ended --> Playing : playVideo() (Replay/Loop)
    Ended --> Unstarted: stopVideo() / New Load Call

    state Error <<error>> {
       [*] --> PlayerError : API Error / Not Found / etc. (Event)
       note right of PlayerError : Any non-error state<br>can transition to Error
    }

    Unstarted --> Error
    Buffering --> Error
    Playing --> Error
    Paused --> Error
    Ended --> Error
    Cued --> Error

    note "State numbers (-1, 0, 1, 2, 3, 5)<br>correspond to YT.PlayerState values" as N1

    style Error fill:#fcc,stroke:#c00,stroke-width:2px

```

**Explanation:**

*   Shows the lifecycle of the player's state based on the `PlayerState` enum values (which directly map to the YouTube API states).
*   Arrows indicate common transitions triggered by specific API calls (like `playVideo()`, `pauseVideo()`) or internal player events (buffering, video end, errors).
*   An `Error` state can theoretically be entered from any other state upon receiving an error event from the JS API.
*   The `Unstarted` state often serves as a reset point when stopping or loading new content.

---

### 5. Action Handling Flow (`PlayerAction` Enum)

This flowchart details how a `PlayerAction` initiated from SwiftUI is processed and translated into JavaScript API calls.

```mermaid
---
title: "PlayerAction Handling Flow"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'graph': { 'htmlLabels': false, 'curve': 'linear' },
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#ffff',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F8B229',
      'tertiaryColor': '#fff'
    }
  }
}%%
flowchart TD
    A["SwiftUI View<br>(e.g., Button Tap)"] --> B{"Set @State playerAction = .someAction"}
    B --> C{"SwiftUI Rerenders View"}
    C --> D{"YouTubePlayerView.updateUIView() Called"}
    D --> E{"Read playerAction binding"}
    E --> F{"Action != nil?"}
    F -- Yes --> G["Call coordinator.handleAction(action)"]
    F -- No --> X["End Update Check"]
    G --> H{"Reset playerAction = nil<br>(async)"}
    G --> I{"Switch on action type"}

    subgraph Coordinator_handleAction["Coordinator handleAction()"]
        I -- .loadVideo / .loadPlaylist --> J["Log:<br>Action handled by ID change in updateUIView"]
        I -- .play --> K["Post Notification(.playbackStarted)"]
        K --> L["JS Command = 'player.playVideo()'"]
        I -- .pause --> M["JS Command = 'player.pauseVideo()'"]
        I -- .stop --> N["JS Command = 'player.stopVideo()'"]
        I -- .seek --> O["JS Command = 'player.seekTo(seconds, true)'"]
        I -- .next --> P["JS Command = 'player.nextVideo()'"]
        I -- .previous --> Q["JS Command = 'player.previousVideo()'"]
    end

    J --> R{"Player Ready?"}
    L --> R
    M --> R
    N --> R
    O --> R
    P --> R
    Q --> R

    R -- Yes --> S["webView.evaluateJavaScript(JS Command)"]
    R -- No --> T["Log:<br>Action Ignored<br>(Player Not Ready)"]
    S --> U{"JS Execution Result?"}
    U -- Success --> V["Optional Logging"]
    U -- Error --> W["Log Error"]
    T --> X
    V --> X
    W --> X
    

```

**Explanation:**

*   Starts with a user interaction in SwiftUI setting the `playerAction` state variable.
*   This triggers `updateUIView` in the `YouTubePlayerView`.
*   The `Coordinator`'s `handleAction` method is invoked if an action exists.
*   The action binding is reset asynchronously.
*   **Crucially**, it first checks if the player `isPlayerReady` *before* attempting to execute commands.
*   A switch statement determines the appropriate JavaScript API call string based on the action type.
*   Load actions (`loadVideo`, `loadPlaylist`) primarily rely on the ID change detection logic in `updateUIView`, not direct JS evaluation here.
*   Playback/control actions result in `evaluateJavaScript` being called.
*   Results or errors from JavaScript execution are optionally logged.

---

### 6. Navigation and Security (`WKNavigationDelegate` Logic)

This flowchart outlines the decision process within the `webView(_:decidePolicyFor:)` delegate method to control navigation attempts within the `WKWebView`, prioritizing security and expected behavior.

```mermaid
---
title: "WKNavigationDelegate Policy Decisions"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'flowchart': { 'htmlLabels': false, 'curve': 'linear' },
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#ffff',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F8B229',
      'tertiaryColor': '#fff'
    }
  }
}%%
flowchart TD
    A[Navigation Action Received] --> B{Extract URL from request};
    B -- No URL --> C[Allow Decision]:::allow;
    B -- Has URL --> D{"URL Scheme == 'ytplayer'?<br>(Legacy Fallback)"};
    D -- Yes --> E[Handle Legacy URL Callback];
    E --> F[Cancel Decision]:::cancel;
    D -- No --> G{"Get URL Host & Scheme"};
    G --> H{"Host Matches Allowed List<br>OR Matches Origin?"};
    H -- Yes --> C;
    H -- No --> I{"Scheme is http OR https?"};
    I -- Yes --> J["External Web URL:<br>Attempt to Open in System Browser (Safari)"];
    J --> F;
    I -- No --> K["Allow Other Schemes<br>(e.g., mailto:, tel:)"];
    K --> C;

    subgraph Allowed_Hosts_Check [Allowed Hosts Check]
        style Allowed_Hosts_Check fill:#dde,stroke:#99f,stroke-width:1px
        direction LR
        L[youtube.com]
        M[google.com]
        N[accounts.google.com]
        O[googlesyndication.com]
        P[doubleclick.net]
        Q[googleads.g.doubleclick.net]
        R[googleapis.com]
        CongLeSolutionX["tech.conglesolutionx.youtube-ios-player-helper-clone"]
        S["Origin Host<br>(from baseURL used in loadHTMLString)"]
        CongLe["tech.conglesolutionx.unofficial-swiftui-wrapper-for-youtube-iframe-player-api"]
    end

    classDef cancel fill:#ffff,stroke:#c00,stroke-width:1px,color:#a00
    classDef allow fill:#ffff,stroke:#0c0,stroke-width:1px,color:#0a0

```

**Explanation:**

*   Starts when the `WKWebView` attempts to navigate.
*   It first checks for the custom `ytplayer://` scheme (legacy fallback). If matched, the URL is handled, and navigation is **cancelled**.
*   Otherwise, it checks if the URL's host is within the `Allowed Hosts Check` list (YouTube domains, necessary Google services, the origin specified during loading). If allowed, navigation proceeds **within** the WebView (`Allow Decision`).
*   If the host isn't allowed but the scheme is HTTP/HTTPS, it's an external link. The system attempts to open it in the default browser (Safari), and navigation is **cancelled** within the WebView.
*   Other URL schemes (like `mailto:`, `tel:`) are generally **allowed**, letting the operating system handle them appropriately.

---

### 7. Multi-Player Interaction (`NotificationCenter`)

This sequence diagram shows how two instances of the player coordinate using `NotificationCenter` to pause one player when another starts playing.

```mermaid
---
title: "Multi-Player Coordination via NotificationCenter"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
config:
  theme: base
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'sequenceDiagram': { 'htmlLabels': false, 'actorMargin': 30 },
    'fontFamily': 'Helvetica',
    'themeVariables': {
      'primaryColor': '#E6F2FF', # Light blue background
      'primaryTextColor': '#003366', # Dark blue text
      'primaryBorderColor': '#99CCFF', # Medium blue border
      'lineColor': '#0059b3', # Darker blue lines
      'secondaryColor': '#CCE0FF', # Lighter blue for boxes
      'tertiaryColor': '#F0F8FF' # Very light blue for notes
    }
  }
}%%
sequenceDiagram
    autonumber

    participant SWUI as SwiftUI App
    box "Player Instances" LightBlue
        participant P1 as Player 1<br>(Coordinator)
        participant P2 as Player 2<br>(Coordinator)
    end
    participant NC as NotificationCenter

    SWUI ->> P1: Create Instance
    P1 ->> NC: addObserver(forName: .playbackStarted, ...)
    SWUI ->> P2: Create Instance
    P2 ->> NC: addObserver(forName: .playbackStarted, ...)

    Note right of SWUI: User initiates playback on Player 1
    SWUI ->> P1: Set playerAction = .play
    P1 ->> P1: handleAction(.play)
    P1 ->> NC: post(name: .playbackStarted, object: self)

    NC -->> P1: Delivers Notification (object is P1)
    P1 ->> P1: Check: notification.object === self (True)
    P1 ->> P1: Action: Ignore (Notification from self)

    NC -->> P2: Delivers Notification (object is P1)
    P2 ->> P2: Check: notification.object === self (False)
    P2 ->> P2: Action: Evaluate JS 'player.pauseVideo()'

    Note right of SWUI: Later, user initiates playback on Player 2
    SWUI ->> P2: Set playerAction = .play
    P2 ->> P2: handleAction(.play)
    P2 ->> NC: post(name: .playbackStarted, object: self)

    NC -->> P2: Delivers Notification (object is P2)
    P2 ->> P2: Check: notification.object === self (True)
    P2 ->> P2: Action: Ignore (Notification from self)

    NC -->> P1: Delivers Notification (object is P2)
    P1 ->> P1: Check: notification.object === self (False)
    P1 ->> P1: Action: Evaluate JS 'player.pauseVideo()'

    Note right of SWUI: Cleanup on Deinitialization
    SWUI ->> P1: Deinit Instance
    P1 ->> NC: removeObserver(...)
    SWUI ->> P2: Deinit Instance
    P2 ->> NC: removeObserver(...)

```

**Explanation:**

*   Both player instances register with `NotificationCenter` to observe the `.playbackStarted` notification.
*   When Player 1 starts playing, its `Coordinator` posts the notification, including `self` as the `object`.
*   Player 1 receives the notification but ignores it because the sending `object` is itself.
*   Player 2 receives the notification, sees the `object` is different (it's Player 1's Coordinator), and executes the JavaScript to pause its own video.
*   The process reverses if Player 2 starts playing.
*   Observers are removed during deinitialization (`deinit`) to prevent issues.

---

### 8. Initialization and Parameter Injection

This diagram details the process of constructing the parameters dictionary and injecting it into the HTML template before loading the `WKWebView`.

```mermaid
---
title: "Player Initialization & Parameter Injection"
author: "Cong Le"
version: "1.0"
license(s): "Apache License 2.0, CC BY 4.0" # CORRECTED License
copyright: "Copyright (c) 2025 Cong Le. All Rights Reserved."
config:
  layout: elk
  look: handDrawn
  theme: dark
---
%%%%%%%% Mermaid version v11.4.1-b.14
%%%%%%%% Toggle theme value to `base` to activate the initilization below for the customized theme version.
%%%%%%%% Available curve styles include the following keywords:
%% basis, bumpX, bumpY, cardinal, catmullRom, linear, monotoneX, monotoneY, natural, step, stepAfter, stepBefore.
%%{
  init: {
    'graph': { 'htmlLabels': false, 'curve': 'linear' },
    'fontFamily': 'Monospace',
    'themeVariables': {
      'primaryColor': '#BEF',
      'primaryTextColor': '#55ff',
      'primaryBorderColor': '#7c2',
      'lineColor': '#F8B229',
      'secondaryColor': '#EE2',
      'tertiaryColor': '#fff'
    }
  }
}%%
graph TD
    A["Coordinator.performInitialLoad()"] --> B{"Build Player Parameters Dictionary<br>(via createPlayerParameters)"};

    subgraph Parameter_Construction_Logic["Parameter Construction Logic"]
    style Parameter_Construction_Logic fill:#3a3a,stroke:#777,stroke-width:1px
        B --> C["Start with base 'playerVars' & 'events' mapping"]
        C --> D["Ensure 'origin' is Correctly Set in playerVars<br>(Critical for JS API)"]
        D --> E["Ensure 'playsinline = 1' in playerVars<br>(Allows inline playback)"]
        E --> G{"Content Type?"}
        G -- Single Video --> H["Add 'videoId' to top level"]
        G -- Playlist --> I["Add 'listType:playlist' & 'list:playlistId' to playerVars"]
        G -- Neither --> J["Log Warning / Handle Default?"]
        H --> K["Add Placeholder 'width'/'height' ('100%')"]
        I --> K
        J --> K
        K --> R["Return Final Parameters Dictionary"]
    end

    B --> S{"Serialize Dictionary to JSON String"};
    S -- Success --> T["Inject JSON into HTML Template<br>(Replace '%@' marker)"]
    S -- Failure --> U["Trigger onError(.invalidParam)<br>Log Serialization Error"];
    T --> V{"Determine valid 'baseURL' for Origin"};
    V --> W["Call webView.loadHTMLString(html, baseURL)"];

    style W fill:#555, stroke:#aaa, stroke-width:2px

```

**Explanation:**

*   The process starts with `performInitialLoad`.
*   `createPlayerParameters` builds the dictionary needed for the `YT.Player` constructor in JavaScript.
*   **Key Steps:**
    *   Sets essential `playerVars`: `origin` (for security) and `playsinline` (for behavior).
    *   Maps Swift event names to JS function names (e.g., `onReady` -> `"onReady"`).
    *   Adds either `videoId` or playlist-specific variables (`listType`, `list`) based on input.
    *   Includes placeholder dimensions (native code resizes later).
*   The dictionary is converted to JSON.
*   The JSON replaces the `"%@"` placeholder in the `youtubeHTML` string.
*   `loadHTMLString` is called with the finalized HTML and a `baseURL`, setting the web content's origin. Failures in JSON serialization trigger an error.

---

**Licenses:**

*   **Code:** The Swift and JavaScript code components of this project are licensed under the **Apache License 2.0**. The full license text should be included in a `LICENSE` file. [![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
*   **Documentation & Visuals:** The explanatory text, diagrams, and other non-code content in this document are licensed under the **Creative Commons Attribution 4.0 International License (CC BY 4.0)**. The full license text should be included in a `LICENSE-CC-BY` file and can be found at the [Creative Commons website](http://creativecommons.org/licenses/by/4.0/). [![License: CC BY 4.0](https://licensebuttons.net/l/by/4.0/88x31.png)](http://creativecommons.org/licenses/by/4.0/)

---
