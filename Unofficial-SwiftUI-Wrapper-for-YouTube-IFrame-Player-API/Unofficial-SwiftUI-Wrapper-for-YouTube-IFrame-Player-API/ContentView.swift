//
//  ContentView.swift
//  youtube-ios-player-helper-clone
//
//  Created by Cong Le on March 31, 2025.
//  Copyright © 2025 Cong Le. All rights reserved.
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack {
            Image("My-meme-original")
                .resizable() // Make it resizable
                .scaledToFit() // Scale to fit COMPLETELY within the frame, preserving aspect ratio
                // Add a frame modifier to control the size
                // Adjust the height (or width) value to make it larger/smaller as desired
                .frame(height: 300) // Example height constraint
                // .frame(width: 250) // Alternatively, constrain by width

            Text("CongLeSolutionX")
                .padding(.top, 5)

            // Optional: Add a Spacer to push the content towards the top if desired
            // Spacer()
        }
        .padding() // Keep padding around the VStack content
    }
}

#Preview {
    ContentView()
}
