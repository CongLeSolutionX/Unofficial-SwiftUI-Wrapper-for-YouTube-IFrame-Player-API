//
// Copyright Cong Le 2025
// Portions derived from work Copyright 2014 Google Inc. All rights reserved.
//
// See LICENSE file for licensing information (Apache License, Version 2.0).
//
//
//  youtube_ios_player_helper_cloneApp.swift
//  youtube_ios_player_helper_clone
//
//  Created by Cong Le on March 31, 2025.
//


import SwiftUI

@main
struct YouTubePlayerSwiftUIApp: App {
    // If AppDelegate logic is needed (e.g., global setup), use an adaptor:
     @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            TabView {
                NavigationView { // Embed each view in a NavigationView for titles
                     SingleVideoView()
                 }
                .tabItem {
                    Label("Single Video", systemImage: "video")
                }
                .navigationViewStyle(.stack) // Use stack style

                NavigationView {
                    PlaylistView()
                }
                .tabItem {
                    Label("Playlist", systemImage: "list.and.film")
                }
                 .navigationViewStyle(.stack)
            }
        }
    }
}


// Optional: If you needed an AppDelegate for specific setup
 class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("App Delegate: Did finish launching")
        // Perform any initial setup here if needed
        return true
    }
 }
