//
//  SpotifyService.swift
//  pulseprompt
//
//  Extracted from SpotifyManager.swift - handles pure Spotify business logic
//

import Foundation
import SpotifyiOS
import UIKit
import Combine

protocol SpotifyServiceDelegate: AnyObject {
    func spotifyServiceDidConnect()
    func spotifyServiceDidDisconnect(error: Error?)
    func spotifyServicePlayerStateDidChange(isPlaying: Bool, trackName: String)
}

class SpotifyService: NSObject {
    weak var delegate: SpotifyServiceDelegate?
    
    // Authentication state
    private(set) var isAuthenticated = false
    private(set) var accessToken: String?
    
    // Connection state
    private(set) var isAppRemoteConnected = false
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    
    // Device activation state
    private var isDeviceActivating = false
    private var deviceActivationCompleted = false
    private var isStartingTrainingPlaylist = false
    
    // Configuration
    private let clientID: String
    private let clientSecret: String
    private let redirectURLString = "pulseprompt://spotify-login-callback"
    
    // App lifecycle monitoring
    private var cancellables = Set<AnyCancellable>()
    
    init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        super.init()
        setupSpotify()
        setupAppLifecycleMonitoring()
    }
    
    // MARK: - Setup
    
    private func setupSpotify() {
        print("Setting up Spotify with Client ID: \(clientID)")
        
        guard let redirectURL = URL(string: redirectURLString) else { 
            print("ERROR: Invalid redirect URL: \(redirectURLString)")
            return 
        }
        
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        configuration.playURI = nil // Don't auto-play during setup
        
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        
        print("Spotify setup complete - ready for authentication")
    }
    
    private func setupAppLifecycleMonitoring() {
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 App returning to foreground - checking Spotify connection...")
        
        if accessToken != nil && !isAppRemoteConnected {
            print("🔄 Attempting to reconnect AppRemote after returning to foreground...")
            attemptAppRemoteReconnection()
        }
    }
    
    // MARK: - Public Authentication API
    
    func connect() {
        print("Attempting to connect to Spotify...")
        
        guard !clientID.isEmpty else {
            print("ERROR: Spotify Client ID is not configured!")
            return
        }
        
        let scopes: SPTScope = [
            .playlistReadPrivate,
            .userReadPlaybackState,
            .userModifyPlaybackState,
            .userReadCurrentlyPlaying,
            .streaming,
            .appRemoteControl
        ]
        sessionManager?.initiateSession(with: scopes, options: [], campaign: "pulseprompt")
    }
    
    func handleCallback(url: URL) {
        print("🔄 Handling Spotify authentication callback: \(url)")
        sessionManager?.application(UIApplication.shared, open: url, options: [:])
    }
    
    func disconnect() {
        appRemote?.disconnect()
        resetConnectionState()
    }
    
    func reconnect() {
        print("🔄 Manual reconnection requested...")
        
        guard accessToken != nil else {
            print("Not authenticated - need to authenticate first")
            return
        }
        
        guard !isAppRemoteConnected else {
            print("AppRemote already connected")
            return
        }
        
        attemptAppRemoteReconnection()
    }
    
    // MARK: - Device Management
    
    func activateDeviceForTraining(playlistID: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let appRemote = appRemote else {
            print("❌ AppRemote not available for activation")
            completion(false)
            return
        }
        
        // Check if already connected or activation completed
        if appRemote.isConnected || deviceActivationCompleted {
            print("✅ Device already active and ready")
            
            if let playlistID = playlistID {
                startPlaylistDirectly(playlistID: playlistID)
            }
            
            completion(true)
            return
        }
        
        // Prevent multiple simultaneous activation attempts
        if isDeviceActivating {
            print("⏳ Device activation already in progress, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                completion(appRemote.isConnected || self.deviceActivationCompleted)
            }
            return
        }
        
        performDeviceActivation(playlistID: playlistID, completion: completion)
    }
    
    private func performDeviceActivation(playlistID: String?, completion: @escaping (Bool) -> Void) {
        guard let appRemote = appRemote else {
            completion(false)
            return
        }
        
        isDeviceActivating = true
        
        let playURI: String
        if let playlistID = playlistID {
            playURI = "spotify:playlist:\(playlistID)"
            isStartingTrainingPlaylist = true
            print("🎵 Starting training with playlist: \(playlistID)")
        } else {
            playURI = ""
            isStartingTrainingPlaylist = false
            print("📱 Connecting AppRemote and activating iPhone as Spotify device...")
        }
        
        // Use authorizeAndPlayURI to wake up device
        appRemote.authorizeAndPlayURI(playURI)
        appRemote.delegate = self
        
        // Connect for control
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            appRemote.connect()
        }
        
        // Check activation result
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.handleActivationCompletion(playlistID: playlistID, completion: completion)
        }
    }
    
    private func handleActivationCompletion(playlistID: String?, completion: @escaping (Bool) -> Void) {
        isDeviceActivating = false
        deviceActivationCompleted = true
        
        if let appRemote = appRemote, appRemote.isConnected {
            print("✅ Device activation successful - ready for training playlist control")
            if playlistID != nil {
                notifyPlayerStateChange(isPlaying: true, trackName: "Training Playlist")
            }
            completion(true)
        } else {
            if playlistID != nil {
                print("ℹ️ AppRemote not connected yet, but training playlist should be playing")
                notifyPlayerStateChange(isPlaying: true, trackName: "Training Playlist")
                completion(true)
            } else {
                print("ℹ️ AppRemote connection not established - using Web API for playlist control")
                completion(false)
            }
        }
    }
    
    func resetDeviceActivationState() {
        print("🔄 Resetting device activation state")
        deviceActivationCompleted = false
        isDeviceActivating = false
        isStartingTrainingPlaylist = false
    }
    
    // MARK: - Playback Control
    
    func playHighIntensityPlaylist(playlistID: String) {
        guard !playlistID.isEmpty else {
            print("Warning: High intensity playlist ID not configured")
            return
        }
        
        print("Attempting to play high intensity playlist...")
        
        let isBackground = UIApplication.shared.applicationState != .active
        if isBackground {
            handleBackgroundPlayback(playlistID: playlistID, isHighIntensity: true)
            return
        }
        
        // Check if already playing from device activation
        if deviceActivationCompleted && isStartingTrainingPlaylist {
            print("✅ High intensity playlist already playing from device activation")
            notifyPlayerStateChange(isPlaying: true, trackName: "High Intensity Playlist")
            return
        }
        
        playPlaylist(playlistID: playlistID, playlistName: "High Intensity Playlist")
    }
    
    func playRestPlaylist(playlistID: String) {
        guard !playlistID.isEmpty else {
            print("Warning: Rest playlist ID not configured")
            return
        }
        
        print("Attempting to play rest playlist...")
        
        let isBackground = UIApplication.shared.applicationState != .active
        if isBackground {
            handleBackgroundPlayback(playlistID: playlistID, isHighIntensity: false)
            return
        }
        
        playPlaylist(playlistID: playlistID, playlistName: "Rest Playlist")
    }
    
    private func playPlaylist(playlistID: String, playlistName: String) {
        // Try AppRemote first
        if let appRemote = appRemote, appRemote.isConnected {
            print("Using AppRemote to play \(playlistName)...")
            let playlistURI = "spotify:playlist:\(playlistID)"
            playPlaylistViaAppRemote(playlistURI: playlistURI, playlistName: playlistName)
        } else if let accessToken = accessToken {
            print("Using Web API to start playback...")
            playPlaylistViaWebAPI(playlistID: playlistID, playlistName: playlistName)
        } else {
            print("No access token available, using content linking...")
            playPlaylistViaURL(playlistID: playlistID, playlistName: playlistName)
        }
    }
    
    func pause() {
        if let appRemote = appRemote, appRemote.isConnected {
            print("Pausing via AppRemote...")
            appRemote.playerAPI?.pause { _, error in
                if let error = error {
                    print("Error pausing via AppRemote: \(error)")
                    self.pauseViaWebAPI()
                } else {
                    print("Successfully paused via AppRemote")
                    self.notifyPlayerStateChange(isPlaying: false, trackName: "")
                }
            }
        } else {
            print("ℹ️ AppRemote not available - trying Web API pause...")
            pauseViaWebAPI()
        }
    }
    
    func resume() {
        if let appRemote = appRemote, appRemote.isConnected {
            print("Resuming via AppRemote...")
            appRemote.playerAPI?.resume { _, error in
                if let error = error {
                    print("Error resuming via AppRemote: \(error)")
                    self.resumeViaWebAPI()
                } else {
                    print("Successfully resumed via AppRemote")
                    self.notifyPlayerStateChange(isPlaying: true, trackName: "Current Track")
                }
            }
        } else {
            print("ℹ️ AppRemote not available - trying Web API resume...")
            resumeViaWebAPI()
        }
    }
    
    // MARK: - Private Implementation
    
    private func attemptAppRemoteReconnection() {
        guard let appRemote = appRemote else { return }
        
        appRemote.delegate = self
        appRemote.connect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if appRemote.isConnected {
                print("✅ Successfully reconnected AppRemote")
            } else {
                print("ℹ️ AppRemote reconnection failed - Web API fallback available")
            }
        }
    }
    
    private func resetConnectionState() {
        isAppRemoteConnected = false
        isAuthenticated = false
        accessToken = nil
        resetDeviceActivationState()
    }
    
    private func startPlaylistDirectly(playlistID: String) {
        guard let appRemote = appRemote else { return }
        
        isStartingTrainingPlaylist = true
        let playlistURI = "spotify:playlist:\(playlistID)"
        print("🎵 Starting training playlist on already-active device: \(playlistID)")
        
        appRemote.playerAPI?.play(playlistURI) { _, error in
            if let error = error {
                print("Error starting playlist via AppRemote: \(error)")
            } else {
                print("✅ Successfully started training playlist via AppRemote")
                self.notifyPlayerStateChange(isPlaying: true, trackName: "Training Playlist")
            }
        }
    }
    
    private func handleBackgroundPlayback(playlistID: String, isHighIntensity: Bool) {
        guard let accessToken = accessToken else { return }
        
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        let taskName = isHighIntensity ? "PlayHighIntensityBG" : "PlayRestBG"
        
        bgTask = UIApplication.shared.beginBackgroundTask(withName: taskName) { 
            UIApplication.shared.endBackgroundTask(bgTask)
            bgTask = .invalid
        }
        
        activateIPhoneDeviceForPlayback { [weak self] success in
            guard let self = self else { return }
            if success {
                let playlistName = isHighIntensity ? "High Intensity Playlist" : "Rest Playlist"
                self.playPlaylistViaWebAPI(playlistID: playlistID, playlistName: playlistName)
            } else {
                print("Background: Could not activate device; skipping URL scheme (not allowed in background)")
            }
            UIApplication.shared.endBackgroundTask(bgTask)
        }
    }
    
    private func notifyPlayerStateChange(isPlaying: Bool, trackName: String) {
        delegate?.spotifyServicePlayerStateDidChange(isPlaying: isPlaying, trackName: trackName)
    }
}

// MARK: - Web API Implementation
extension SpotifyService {
    private func pauseViaWebAPI() {
        guard let accessToken = accessToken else { 
            print("No access token available for Web API pause")
            return 
        }
        
        let pauseURL = URL(string: "https://api.spotify.com/v1/me/player/pause")!
        var request = URLRequest(url: pauseURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("⏸️ Pausing playback via Web API...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error pausing via Web API: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    print("✅ Successfully paused playback via Web API")
                    self.notifyPlayerStateChange(isPlaying: false, trackName: "")
                } else {
                    print("Failed to pause playback via Web API. Status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func resumeViaWebAPI() {
        guard let accessToken = accessToken else { 
            print("No access token available for Web API resume")
            return 
        }
        
        let resumeURL = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: resumeURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("▶️ Resuming playback via Web API...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error resuming via Web API: \(error)")
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    print("✅ Successfully resumed playback via Web API")
                    self.notifyPlayerStateChange(isPlaying: true, trackName: "Current Track")
                } else {
                    print("Failed to resume playback via Web API. Status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    private func playPlaylistViaWebAPI(playlistID: String, playlistName: String) {
        guard let accessToken = accessToken else { return }
        
        activateIPhoneDeviceForPlayback { [weak self] success in
            if success {
                print("iPhone device activated, starting playback...")
                self?.startPlaybackViaWebAPI(playlistID: playlistID, playlistName: playlistName)
            } else {
                print("Failed to activate iPhone device, using content linking...")
                DispatchQueue.main.async {
                    self?.playPlaylistViaURL(playlistID: playlistID, playlistName: playlistName)
                }
            }
        }
    }
    
    private func startPlaybackViaWebAPI(playlistID: String, playlistName: String) {
        guard let accessToken = accessToken else { return }
        
        let playURL = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: playURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["context_uri": "spotify:playlist:\(playlistID)"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("Attempting to start \(playlistName) via Web API...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error starting playback: \(error)")
                DispatchQueue.main.async {
                    self?.playPlaylistViaURL(playlistID: playlistID, playlistName: playlistName)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    print("Successfully started \(playlistName) via Web API")
                    self?.notifyPlayerStateChange(isPlaying: true, trackName: playlistName)
                } else {
                    print("Failed to start playback. Status: \(httpResponse.statusCode)")
                    DispatchQueue.main.async {
                        self?.playPlaylistViaURL(playlistID: playlistID, playlistName: playlistName)
                    }
                }
            }
        }.resume()
    }
    
    private func activateIPhoneDeviceForPlayback(completion: @escaping (Bool) -> Void) {
        guard let accessToken = accessToken else {
            completion(false)
            return
        }
        
        let devicesURL = URL(string: "https://api.spotify.com/v1/me/player/devices")!
        var request = URLRequest(url: devicesURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let devices = json["devices"] as? [[String: Any]] else {
                completion(false)
                return
            }
            
            // Look for active iPhone device first
            let activeIPhoneDevice = devices.first { device in
                guard let name = device["name"] as? String,
                      let type = device["type"] as? String,
                      let isActive = device["is_active"] as? Bool else { return false }
                
                let isIPhone = name.lowercased().contains("iphone") || 
                              type.lowercased().contains("smartphone") ||
                              type.lowercased().contains("mobile")
                return isIPhone && isActive
            }
            
            if activeIPhoneDevice != nil {
                print("iPhone device is already active!")
                completion(true)
                return
            }
            
            // Find any iPhone device to activate
            let iPhoneDevice = devices.first { device in
                guard let name = device["name"] as? String,
                      let type = device["type"] as? String else { return false }
                
                return name.lowercased().contains("iphone") || 
                       type.lowercased().contains("smartphone") ||
                       type.lowercased().contains("mobile")
            }
            
            if let iPhoneDevice = iPhoneDevice,
               let deviceID = iPhoneDevice["id"] as? String {
                self.transferPlaybackToDevice(deviceID: deviceID, accessToken: accessToken, completion: completion)
            } else {
                print("No iPhone device found for activation")
                completion(false)
            }
        }.resume()
    }
    
    private func transferPlaybackToDevice(deviceID: String, accessToken: String, completion: @escaping (Bool) -> Void) {
        let transferURL = URL(string: "https://api.spotify.com/v1/me/player")!
        var request = URLRequest(url: transferURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["device_ids": [deviceID], "play": false]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let httpResponse = response as? HTTPURLResponse {
                completion(httpResponse.statusCode == 204)
            } else {
                completion(false)
            }
        }.resume()
    }
}

// MARK: - URL Scheme Implementation  
extension SpotifyService {
    private func playPlaylistViaURL(playlistID: String, playlistName: String) {
        print("Using content linking to open \(playlistName)...")
        
        let bundleId = Bundle.main.bundleIdentifier ?? "com.pulseprompt.app"
        let canonicalURL = "https://open.spotify.com/playlist/\(playlistID)"
        let contentLinkURL = "https://spotify.link/content_linking?~campaign=\(bundleId)&$canonical_url=\(canonicalURL)"
        
        if let url = URL(string: contentLinkURL) {
            UIApplication.shared.open(url) { success in
                if success {
                    print("Successfully opened \(playlistName) via content linking")
                    self.notifyPlayerStateChange(isPlaying: true, trackName: playlistName)
                } else {
                    // Fallback to direct URI
                    let spotifyURI = "spotify:playlist:\(playlistID)"
                    if let fallbackUrl = URL(string: spotifyURI) {
                        UIApplication.shared.open(fallbackUrl) { fallbackSuccess in
                            if fallbackSuccess {
                                self.notifyPlayerStateChange(isPlaying: true, trackName: playlistName)
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - AppRemote Implementation
extension SpotifyService {
    private func playPlaylistViaAppRemote(playlistURI: String, playlistName: String) {
        guard let appRemote = appRemote, appRemote.isConnected else {
            print("AppRemote not connected for \(playlistName) playback")
            return
        }
        
        print("Playing \(playlistName) via AppRemote...")
        appRemote.playerAPI?.play(playlistURI) { _, error in
            if let error = error {
                print("Error playing \(playlistName) via AppRemote: \(error)")
            } else {
                print("Successfully started \(playlistName) via AppRemote")
                self.notifyPlayerStateChange(isPlaying: true, trackName: playlistName)
            }
        }
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyService: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("OAuth authentication successful!")
        
        accessToken = session.accessToken
        isAuthenticated = true
        delegate?.spotifyServiceDidConnect()
        
        // Set up AppRemote with access token
        if let appRemote = appRemote {
            appRemote.delegate = self
            appRemote.connectionParameters.accessToken = session.accessToken
            
            print("🔗 Attempting to connect AppRemote after authentication...")
            appRemote.connect()
        }
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("OAuth authentication failed: \(error.localizedDescription)")
        resetConnectionState()
        delegate?.spotifyServiceDidDisconnect(error: error)
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("Session renewed successfully")
        accessToken = session.accessToken
        isAuthenticated = true
        
        if let appRemote = appRemote {
            appRemote.connectionParameters.accessToken = session.accessToken
        }
    }
}

// MARK: - SPTAppRemoteDelegate  
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("🎵 AppRemote: Connected successfully! Device is now active.")
        isAppRemoteConnected = true
        appRemote.playerAPI?.delegate = self
        
        // Subscribe to player state
        appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                print("Error subscribing to player state: \(error)")
            } else {
                print("✅ Successfully subscribed to player state updates")
            }
        })
        
        // Only pause automatic playback if we're not starting training music
        if !isStartingTrainingPlaylist {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                appRemote.playerAPI?.pause { _, error in
                    if let error = error {
                        print("Note: Could not pause initial playback: \(error)")
                    } else {
                        print("✅ Paused device activation playback - ready for training playlist control")
                    }
                }
            }
        }
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("AppRemote: Failed connection attempt with error: \(error?.localizedDescription ?? "Unknown error")")
        isAppRemoteConnected = false
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("AppRemote: Disconnected with error: \(error?.localizedDescription ?? "No error")")
        isAppRemoteConnected = false
        delegate?.spotifyServiceDidDisconnect(error: error)
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate
extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        let isPlaying = !playerState.isPaused
        let trackName = playerState.track.name
        notifyPlayerStateChange(isPlaying: isPlaying, trackName: trackName)
    }
}
