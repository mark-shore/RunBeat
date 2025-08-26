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
    @StateObject private var spotifyManager = SpotifyManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyManager)
                .onOpenURL { url in
                    spotifyManager.handleCallback(url: url)
                }
        }
    }
}
