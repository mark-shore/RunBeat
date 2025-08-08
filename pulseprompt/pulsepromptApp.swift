//
//  pulsepromptApp.swift
//  pulseprompt
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import SpotifyiOS

@main
struct pulsepromptApp: App {
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
