//
//  Unofficial_SwiftUI_Wrapper_for_YouTube_IFrame_Player_APIUITestsLaunchTests.swift
//  Unofficial-SwiftUI-Wrapper-for-YouTube-IFrame-Player-APIUITests
//
//  Created by Cong Le on 3/31/25.
//

import XCTest

final class Unofficial_SwiftUI_Wrapper_for_YouTube_IFrame_Player_APIUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // Insert steps here to perform after app launch but before taking a screenshot,
        // such as logging into a test account or navigating somewhere in the app

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
