//
//  RunBeatApp.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import SwiftUI
import SpotifyiOS
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions

@main
struct RunBeatApp: App {
    @StateObject private var spotifyManager = SpotifyManager.shared
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
        
        // Configure Firebase Auth for anonymous authentication
        configureFirebaseAuth()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(spotifyManager)
                .onOpenURL { url in
                    spotifyManager.handleCallback(url: url)
                }
        }
    }
    
    private func configureFirebaseAuth() {
        // Anonymous authentication for RunBeat users
        Auth.auth().signInAnonymously { authResult, error in
            if let error = error {
                print("Firebase Auth error: \(error.localizedDescription)")
            } else if let user = authResult?.user {
                print("Firebase Auth success: \(user.uid)")
            }
        }
    }
    
}
