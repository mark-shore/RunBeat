//
//  RunBeatApp.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import SpotifyiOS

@main
struct RunBeatApp: App {
    // TEMPORARY: Disabled during Apple Music migration
    // @StateObject private var spotifyManager = SpotifyManager.shared
    // @StateObject private var firebaseService = FirebaseService.shared
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate


    var body: some Scene {
        WindowGroup {
            ContentView()
                // TEMPORARY: Disabled during Apple Music migration
                // .environmentObject(spotifyManager)
                // .onOpenURL { url in
                //     spotifyManager.handleCallback(url: url)
                // }
        }
    }
}
