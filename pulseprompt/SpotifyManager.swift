//
//  SpotifyManager.swift
//  pulseprompt
//
//  Created by Mark Shore on 7/25/25.
//

import Foundation
import SpotifyiOS
import UIKit
import Combine

class SpotifyManager: NSObject, ObservableObject {
    static let shared = SpotifyManager()
    
    @Published var isConnected = false  // OAuth authentication status (for UI)
    @Published var currentTrack: String = ""
    @Published var isPlaying = false
    
    // Internal state tracking
    private var isAppRemoteConnected = false  // AppRemote connection status
    
    private var accessToken: String?
    var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    private var isDeviceActivating = false
    private var deviceActivationCompleted = false
    private var isStartingTrainingPlaylist = false
    private var cancellables = Set<AnyCancellable>()
    
    // Spotify configuration from environment
    private let clientID: String
    private let clientSecret: String
    private let redirectURLString = "pulseprompt://spotify-login-callback"
    
    override init() {
        self.clientID = ConfigurationManager.shared.spotifyClientID
        self.clientSecret = ConfigurationManager.shared.spotifyClientSecret
        super.init()
        setupSpotify()
        setupAppLifecycleMonitoring()
    }
    
    private func setupSpotify() {
        print("Setting up Spotify with Client ID: \(clientID)")
        
        guard let redirectURL = URL(string: redirectURLString) else { 
            print("ERROR: Invalid redirect URL: \(redirectURLString)")
            return 
        }
        
        print("Redirect URL is valid: \(redirectURL)")
        
        let configuration = SPTConfiguration(clientID: clientID, redirectURL: redirectURL)
        
        // IMPORTANT: Leave playURI as default (nil) initially
        // We'll set it programmatically when needed to wake up the device
        configuration.playURI = nil
        
        // Set up session manager for OAuth authentication
        sessionManager = SPTSessionManager(configuration: configuration, delegate: self)
        
        // Set up app remote for playback control during training
        appRemote = SPTAppRemote(configuration: configuration, logLevel: .debug)
        
        print("Spotify setup complete - ready for training playlist control")
    }
    
    private func setupAppLifecycleMonitoring() {
        // Monitor when app comes to foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
    }
    
    private func handleAppWillEnterForeground() {
        print("📱 App returning to foreground - checking Spotify connection...")
        
        // If we're authenticated but AppRemote is disconnected, try to reconnect
        if accessToken != nil && !isAppRemoteConnected {
            print("🔄 Attempting to reconnect AppRemote after returning to foreground...")
            attemptAppRemoteReconnection()
        } else if accessToken == nil {
            print("ℹ️ Not authenticated - user will need to connect Spotify")
        } else if isAppRemoteConnected {
            print("✅ AppRemote already connected")
        }
    }
    
    private func attemptAppRemoteReconnection() {
        guard let appRemote = appRemote else { return }
        
        // Set up delegate and try to connect
        appRemote.delegate = self
        appRemote.connect()
        
        // Give it a moment to connect
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if appRemote.isConnected {
                print("✅ Successfully reconnected AppRemote")
            } else {
                print("ℹ️ AppRemote reconnection failed - Web API fallback available")
            }
        }
    }
    
    func connect() {
        print("Attempting to connect to Spotify...")
        print("Client ID: \(clientID)")
        print("Redirect URL: \(redirectURLString)")
        
        if clientID.isEmpty {
            print("ERROR: Spotify Client ID is not configured!")
            print("Please add your Spotify Client ID to the .env file or Config.plist")
            return
        }
        
        // Start OAuth authentication flow - this should NOT trigger automatic playback
        print("Starting OAuth authentication...")
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
        
        // Handle the OAuth callback
        sessionManager?.application(UIApplication.shared, open: url, options: [:])
    }
    
    func disconnect() {
        appRemote?.disconnect()
    }
    
    /// Manually attempt to reconnect AppRemote - useful if connection was lost
    func reconnect() {
        print("🔄 Manual reconnection requested...")
        
        if accessToken == nil {
            print("Not authenticated - need to authenticate first")
            return
        }
        
        if isAppRemoteConnected {
            print("AppRemote already connected")
            return
        }
        
        attemptAppRemoteReconnection()
    }
    
    private func updateConnectionStatus() {
        // isConnected represents OAuth authentication status for UI purposes
        let hasValidAuth = accessToken != nil
        
        DispatchQueue.main.async {
            self.isConnected = hasValidAuth
        }
        
        print("📊 Connection status - OAuth: \(hasValidAuth), AppRemote: \(isAppRemoteConnected)")
    }
    
    /// Resets device activation state - call this when training sessions end
    func resetDeviceActivationState() {
        print("🔄 Resetting device activation state")
        deviceActivationCompleted = false
        isDeviceActivating = false
        isStartingTrainingPlaylist = false
        isPlaying = false
        currentTrack = ""
    }
    
    /// Resets all connection state - useful for debugging
    func resetConnectionState() {
        print("🔄 Resetting all connection state")
        isAppRemoteConnected = false
        accessToken = nil
        updateConnectionStatus()
        resetDeviceActivationState()
    }
    
    /// Activates the Spotify device and optionally starts a playlist
    func activateDeviceForTraining(playlistID: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let appRemote = appRemote else {
            print("❌ AppRemote not available for activation")
            completion(false)
            return
        }
        
        // Check if already connected or activation completed
        if appRemote.isConnected || deviceActivationCompleted {
            print("✅ Device already active and ready")
            
            // If we need to start a specific playlist, do that even if device is active
            if let playlistID = playlistID {
                isStartingTrainingPlaylist = true
                let playlistURI = "spotify:playlist:\(playlistID)"
                print("🎵 Starting training playlist on already-active device: \(playlistID)")
                
                // Start the playlist directly via AppRemote
                appRemote.playerAPI?.play(playlistURI) { _, error in
                    if let error = error {
                        print("Error starting playlist via AppRemote: \(error)")
                    } else {
                        print("✅ Successfully started training playlist via AppRemote")
                        DispatchQueue.main.async {
                            self.isPlaying = true
                            self.currentTrack = "Training Playlist"
                        }
                    }
                }
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
        
        isDeviceActivating = true
        
        // Determine what to play for device activation
        let playURI: String
        if let playlistID = playlistID {
            playURI = "spotify:playlist:\(playlistID)"
            isStartingTrainingPlaylist = true
            print("🎵 Starting training with playlist: \(playlistID)")
        } else {
            playURI = ""
            isStartingTrainingPlaylist = false
            print("📱 Connecting AppRemote and activating iPhone as Spotify device...")
            print("🎵 Brief music will play to activate device - this is normal for training setup")
        }
        
        // Use authorizeAndPlayURI to wake up device and optionally start playlist
        appRemote.authorizeAndPlayURI(playURI)
        
        // Also explicitly set up the AppRemote connection for playback control
        appRemote.delegate = self
        
        // Wait a moment for authorization, then connect for control
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            print("📱 Attempting AppRemote connection for playback control...")
            appRemote.connect()
        }
        
        // Wait for connection and then check if successful
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.isDeviceActivating = false
            if appRemote.isConnected {
                self.deviceActivationCompleted = true
                // If we started with a playlist, mark as playing
                if playlistID != nil {
                    self.isPlaying = true
                    self.currentTrack = "Training Playlist"
                }
                print("✅ Device activation successful - ready for training playlist control")
                completion(true)
            } else {
                print("ℹ️ AppRemote connection not established - using Web API for playlist control")
                // Mark as completed to avoid retries, Web API should work
                self.deviceActivationCompleted = true
                completion(false)
            }
        }
    }
    
    /// Pauses playback via Web API
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
                    DispatchQueue.main.async {
                        self.isPlaying = false
                    }
                } else {
                    print("Failed to pause playback via Web API. Status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    
    /// Resumes playback via Web API
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
                    DispatchQueue.main.async {
                        self.isPlaying = true
                    }
                } else {
                    print("Failed to resume playback via Web API. Status: \(httpResponse.statusCode)")
                }
            }
        }.resume()
    }
    

    
    func playHighIntensityPlaylist() {
        let playlistID = ConfigurationManager.shared.spotifyHighIntensityPlaylistID
        guard !playlistID.isEmpty else {
            print("Warning: High intensity playlist ID not configured")
            return
        }
        
        print("Attempting to play high intensity playlist...")
        
        // Check if this playlist might already be playing from device activation
        if deviceActivationCompleted && isPlaying && currentTrack.contains("Training Playlist") {
            print("✅ High intensity playlist already playing from device activation - no action needed")
            // Update the track name to be more specific
            DispatchQueue.main.async {
                self.currentTrack = "High Intensity Playlist"
            }
            return
        }
        
        // Try AppRemote first (should be activated during training start)
        if isConnected, let appRemote = appRemote, appRemote.isConnected {
            print("Using AppRemote to play high intensity playlist...")
            let playlistURI = "spotify:playlist:\(playlistID)"
            playPlaylistViaAppRemote(playlistURI: playlistURI, playlistName: "High Intensity Playlist")
        } else if let accessToken = accessToken {
            print("Using Web API to start playback...")
            // First try to activate iPhone device, then start playback
            activateIPhoneDeviceForPlayback { [weak self] success in
                if success {
                    print("iPhone device activated, starting playback...")
                    self?.playHighIntensityPlaylistViaWebAPI(playlistID: playlistID, accessToken: accessToken)
                } else {
                    print("Failed to activate iPhone device, using content linking...")
                    DispatchQueue.main.async {
                        self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                    }
                }
            }
        } else {
            print("No access token available, using content linking...")
            playHighIntensityPlaylistViaURL(playlistID: playlistID)
        }
    }
    
    private func playHighIntensityPlaylistViaWebAPI(playlistID: String, accessToken: String) {
        // Try to start playback directly - Spotify will use the active device
        let playURL = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: playURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["context_uri": "spotify:playlist:\(playlistID)"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("Attempting to start high intensity playlist via Web API...")
        print("Playlist URI: spotify:playlist:\(playlistID)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error starting playback: \(error)")
                // Fallback to URL scheme
                DispatchQueue.main.async {
                    self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Playback start response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 204 {
                    print("Successfully started high intensity playlist via Web API")
                    DispatchQueue.main.async {
                        self?.isPlaying = true
                        self?.currentTrack = "High Intensity Playlist"
                    }
                } else if httpResponse.statusCode == 404 {
                    print("No active device found (404). This usually means Spotify is not actively playing.")
                    print("Trying to start playback with URL scheme...")
                    DispatchQueue.main.async {
                        self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                    }
                } else {
                    print("Failed to start playback. Status: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Playback error response: \(responseString)")
                    }
                    // Fallback to URL scheme
                    DispatchQueue.main.async {
                        self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                    }
                }
            } else {
                print("No HTTP response received for playback")
                // Fallback to URL scheme
                DispatchQueue.main.async {
                    self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                }
            }
        }.resume()
    }
    
    private func activateDeviceForPlayback(completion: @escaping (Bool) -> Void) {
        guard let accessToken = accessToken else {
            print("No access token available for device activation")
            completion(false)
            return
        }
        
        // Get available devices
        let devicesURL = URL(string: "https://api.spotify.com/v1/me/player/devices")!
        var request = URLRequest(url: devicesURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("Requesting available devices from Spotify...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting devices: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Devices API response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {
                    print("Devices API returned error status: \(httpResponse.statusCode)")
                    completion(false)
                    return
                }
            }
            
            guard let data = data else {
                print("No data received from devices API")
                completion(false)
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Raw devices response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let devices = json["devices"] as? [[String: Any]] {
                    
                    print("Found \(devices.count) devices:")
                    for (index, device) in devices.enumerated() {
                        if let name = device["name"] as? String,
                           let type = device["type"] as? String,
                           let isActive = device["is_active"] as? Bool {
                            print("  Device \(index + 1): \(name) (\(type)) - Active: \(isActive)")
                        } else {
                            print("  Device \(index + 1): \(device)")
                        }
                    }
                    
                    // Try to find an active device first
                    let activeDevice = devices.first { device in
                        return device["is_active"] as? Bool == true
                    }
                    
                    // Use active device if available, otherwise use the first device
                    let deviceToUse = activeDevice ?? devices.first
                    
                    if let device = deviceToUse,
                       let deviceID = device["id"] as? String {
                        let deviceName = device["name"] as? String ?? "Unknown"
                        print("Activating device: \(deviceName) (\(deviceID))")
                        self.transferPlaybackToDevice(deviceID: deviceID, accessToken: accessToken) { success in
                            completion(success)
                        }
                    } else {
                        print("No devices available for activation")
                        print("Please ensure Spotify is running on at least one device (phone, computer, etc.)")
                        completion(false)
                    }
                } else {
                    print("No devices found in response")
                    print("Please ensure Spotify is running on at least one device (phone, computer, etc.)")
                    completion(false)
                }
            } catch {
                print("Failed to parse devices response: \(error)")
                completion(false)
            }
        }.resume()
    }
    
    private func startPlaybackViaWebAPI(playlistID: String, deviceID: String, accessToken: String, isResume: Bool = false) {
        let playURL = URL(string: "https://api.spotify.com/v1/me/player/play?device_id=\(deviceID)")!
        var request = URLRequest(url: playURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if isResume {
            // For resume, just send an empty body to start playback
            body = [:]
        } else {
            // For playlist playback, include the context URI
            body = ["context_uri": "spotify:playlist:\(playlistID)"]
        }
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error starting playback via Web API: \(error)")
                if !isResume {
                    DispatchQueue.main.async {
                        self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                    }
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                if httpResponse.statusCode == 204 {
                    if isResume {
                        print("Successfully resumed playback via Web API")
                    } else {
                        print("Successfully started high intensity playlist via Web API")
                    }
                    DispatchQueue.main.async {
                        self?.isPlaying = true
                        self?.currentTrack = isResume ? "Current Track" : "High Intensity Playlist"
                    }
                } else {
                    print("Failed to start playback via Web API. Status: \(httpResponse.statusCode)")
                    if !isResume {
                        DispatchQueue.main.async {
                            self?.playHighIntensityPlaylistViaURL(playlistID: playlistID)
                        }
                    }
                }
            }
        }.resume()
    }
    
    private func playHighIntensityPlaylistViaURL(playlistID: String) {
        print("Using content linking to open high intensity playlist...")
        
        // Use Spotify's recommended content linking approach with web URL and campaign tracking
        let bundleId = Bundle.main.bundleIdentifier ?? "com.pulseprompt.app"
        let canonicalURL = "https://open.spotify.com/playlist/\(playlistID)"
        let contentLinkURL = "https://spotify.link/content_linking?~campaign=\(bundleId)&$canonical_url=\(canonicalURL)"
        
        if let url = URL(string: contentLinkURL) {
            print("Opening playlist via content linking: \(contentLinkURL)")
            UIApplication.shared.open(url) { success in
                if success {
                    print("Successfully opened high intensity playlist via content linking")
                    DispatchQueue.main.async {
                        self.isPlaying = true  // Assume playback will start
                        self.currentTrack = "High Intensity Playlist"
                    }
                } else {
                    print("Failed to open playlist via content linking, trying direct URI...")
                    // Fallback to direct Spotify URI
                    let spotifyURI = "spotify:playlist:\(playlistID)"
                    if let fallbackUrl = URL(string: spotifyURI) {
                        UIApplication.shared.open(fallbackUrl) { fallbackSuccess in
                            if fallbackSuccess {
                                print("Successfully opened playlist via direct URI")
                                DispatchQueue.main.async {
                                    self.isPlaying = true
                                    self.currentTrack = "High Intensity Playlist"
                                }
                            } else {
                                print("Failed to open playlist via any method")
                            }
                        }
                    }
                }
            }
        } else {
            print("Invalid content linking URL")
        }
    }
    

    
    func playRestPlaylist() {
        let playlistID = ConfigurationManager.shared.spotifyRestPlaylistID
        guard !playlistID.isEmpty else {
            print("Warning: Rest playlist ID not configured")
            return
        }
        
        print("Attempting to play rest playlist...")
        
        // Try AppRemote first if connected
        if isConnected, let appRemote = appRemote, appRemote.isConnected {
            print("Using AppRemote to play rest playlist...")
            let playlistURI = "spotify:playlist:\(playlistID)"
            playPlaylistViaAppRemote(playlistURI: playlistURI, playlistName: "Rest Playlist")
        } else if let accessToken = accessToken {
            print("Using Web API to start playback...")
            // First try to activate iPhone device, then start playback
            activateIPhoneDeviceForPlayback { [weak self] success in
                if success {
                    print("iPhone device activated, starting playback...")
                    self?.playRestPlaylistViaWebAPI(playlistID: playlistID, accessToken: accessToken)
                } else {
                    print("Failed to activate iPhone device, using content linking...")
                    DispatchQueue.main.async {
                        self?.playRestPlaylistViaURL(playlistID: playlistID)
                    }
                }
            }
        } else {
            print("No access token available, using content linking...")
            playRestPlaylistViaURL(playlistID: playlistID)
        }
    }
    
    private func playRestPlaylistViaWebAPI(playlistID: String, accessToken: String) {
        // Try to start playback directly - Spotify will use the active device
        let playURL = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: playURL)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["context_uri": "spotify:playlist:\(playlistID)"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("Attempting to start rest playlist via Web API...")
        print("Playlist URI: spotify:playlist:\(playlistID)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                print("Error starting playback: \(error)")
                // Fallback to URL scheme
                DispatchQueue.main.async {
                    self?.playRestPlaylistViaURL(playlistID: playlistID)
                }
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Playback start response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 204 {
                    print("Successfully started rest playlist via Web API")
                    DispatchQueue.main.async {
                        self?.isPlaying = true
                        self?.currentTrack = "Rest Playlist"
                    }
                } else if httpResponse.statusCode == 404 {
                    print("No active device found (404). This usually means Spotify is not actively playing.")
                    print("Trying to start playback with URL scheme...")
                    DispatchQueue.main.async {
                        self?.playRestPlaylistViaURL(playlistID: playlistID)
                    }
                } else {
                    print("Failed to start playback. Status: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Playback error response: \(responseString)")
                    }
                    // Fallback to URL scheme
                    DispatchQueue.main.async {
                        self?.playRestPlaylistViaURL(playlistID: playlistID)
                    }
                }
            } else {
                print("No HTTP response received for playback")
                // Fallback to URL scheme
                DispatchQueue.main.async {
                    self?.playRestPlaylistViaURL(playlistID: playlistID)
                }
            }
        }.resume()
    }
    
    private func playRestPlaylistViaURL(playlistID: String) {
        print("Using content linking to open rest playlist...")
        
        // Use Spotify's recommended content linking approach with web URL and campaign tracking
        let bundleId = Bundle.main.bundleIdentifier ?? "com.pulseprompt.app"
        let canonicalURL = "https://open.spotify.com/playlist/\(playlistID)"
        let contentLinkURL = "https://spotify.link/content_linking?~campaign=\(bundleId)&$canonical_url=\(canonicalURL)"
        
        if let url = URL(string: contentLinkURL) {
            print("Opening playlist via content linking: \(contentLinkURL)")
            UIApplication.shared.open(url) { success in
                if success {
                    print("Successfully opened rest playlist via content linking")
                    DispatchQueue.main.async {
                        self.isPlaying = true  // Assume playback will start
                        self.currentTrack = "Rest Playlist"
                    }
                } else {
                    print("Failed to open playlist via content linking, trying direct URI...")
                    // Fallback to direct Spotify URI
                    let spotifyURI = "spotify:playlist:\(playlistID)"
                    if let fallbackUrl = URL(string: spotifyURI) {
                        UIApplication.shared.open(fallbackUrl) { fallbackSuccess in
                            if fallbackSuccess {
                                print("Successfully opened playlist via direct URI")
                                DispatchQueue.main.async {
                                    self.isPlaying = true
                                    self.currentTrack = "Rest Playlist"
                                }
                            } else {
                                print("Failed to open playlist via any method")
                            }
                        }
                    }
                }
            }
        } else {
            print("Invalid content linking URL")
        }
    }
    
    func pause() {
        if isConnected, let appRemote = appRemote, appRemote.isConnected {
            print("Pausing via AppRemote...")
            appRemote.playerAPI?.pause { _, error in
                if let error = error {
                    print("Error pausing via AppRemote: \(error)")
                    // Try Web API as fallback
                    self.pauseViaWebAPI()
                } else {
                    print("Successfully paused via AppRemote")
                    DispatchQueue.main.async {
                        self.isPlaying = false
                    }
                }
            }
        } else {
            print("ℹ️ AppRemote not available - trying Web API pause...")
            pauseViaWebAPI()
        }
    }
    
    func resume() {
        if isConnected, let appRemote = appRemote, appRemote.isConnected {
            print("Resuming via AppRemote...")
            appRemote.playerAPI?.resume { _, error in
                if let error = error {
                    print("Error resuming via AppRemote: \(error)")
                    // Try Web API as fallback
                    self.resumeViaWebAPI()
                } else {
                    print("Successfully resumed via AppRemote")
                    DispatchQueue.main.async {
                        self.isPlaying = true
                    }
                }
            }
        } else {
            print("ℹ️ AppRemote not available - trying Web API resume...")
            resumeViaWebAPI()
        }
    }
    
    /// Plays a playlist using AppRemote if connected, otherwise falls back to URL
    private func playPlaylistViaAppRemote(playlistURI: String, playlistName: String) {
        if isConnected, let appRemote = appRemote, appRemote.isConnected {
            print("Playing \(playlistName) via AppRemote...")
            appRemote.playerAPI?.play(playlistURI) { _, error in
                if let error = error {
                    print("Error playing \(playlistName) via AppRemote: \(error)")
                } else {
                    print("Successfully started \(playlistName) via AppRemote")
                    DispatchQueue.main.async {
                        self.isPlaying = true
                        self.currentTrack = playlistName
                    }
                }
            }
        } else {
            print("AppRemote not connected for \(playlistName) playback")
        }
    }
    
    func skipNext() {
        appRemote?.playerAPI?.skip(toNext: { _, error in
            if let error = error {
                print("Error skipping track: \(error)")
            }
        })
    }
    
    func skipPrevious() {
        appRemote?.playerAPI?.skip(toPrevious: { _, error in
            if let error = error {
                print("Error skipping to previous track: \(error)")
            }
        })
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyManager: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("OAuth authentication successful!")
        print("Access token: \(session.accessToken)")
        
        accessToken = session.accessToken
        updateConnectionStatus()
        
        // Authentication complete - setup AppRemote for training use
        print("✅ Spotify authentication successful - ready for training")
        
        // Set up AppRemote with access token and connect immediately
        if let appRemote = appRemote {
            appRemote.delegate = self
            appRemote.connectionParameters.accessToken = session.accessToken
            
            // Attempt to connect AppRemote immediately after authentication
            print("🔗 Attempting to connect AppRemote after authentication...")
            appRemote.connect()
        }
    }
    
    private func activateIPhoneDeviceForPlayback(completion: @escaping (Bool) -> Void) {
        guard let accessToken = accessToken else {
            print("No access token available for device activation")
            completion(false)
            return
        }
        
        // First get available devices
        let devicesURL = URL(string: "https://api.spotify.com/v1/me/player/devices")!
        var request = URLRequest(url: devicesURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        print("Getting available devices for playback activation...")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error getting devices for activation: \(error)")
                completion(false)
                return
            }
            
            guard let data = data else {
                print("No data received from devices API")
                completion(false)
                return
            }
            
            // Print raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("Devices API response: \(responseString)")
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let devices = json["devices"] as? [[String: Any]] {
                    
                    print("Found \(devices.count) available devices")
                    
                    // First, look for an already active iPhone device
                    let activeIPhoneDevice = devices.first { device in
                        if let name = device["name"] as? String,
                           let type = device["type"] as? String,
                           let isActive = device["is_active"] as? Bool {
                            let isIPhone = name.lowercased().contains("iphone") || 
                                          type.lowercased().contains("smartphone") ||
                                          type.lowercased().contains("mobile")
                            print("Device: \(name) (\(type)) - Active: \(isActive) - iPhone: \(isIPhone)")
                            return isIPhone && isActive
                        }
                        return false
                    }
                    
                    if activeIPhoneDevice != nil {
                        print("iPhone device is already active!")
                        completion(true)
                        return
                    }
                    
                    // Look for any iPhone device to activate
                    let iPhoneDevice = devices.first { device in
                        if let name = device["name"] as? String,
                           let type = device["type"] as? String {
                            return name.lowercased().contains("iphone") || 
                                   type.lowercased().contains("smartphone") ||
                                   type.lowercased().contains("mobile")
                        }
                        return false
                    }
                    
                    if let iPhoneDevice = iPhoneDevice,
                       let deviceID = iPhoneDevice["id"] as? String,
                       let deviceName = iPhoneDevice["name"] as? String {
                        print("Found iPhone device for activation: \(deviceName) (\(deviceID))")
                        // Try to transfer playback to iPhone
                        self.transferPlaybackToDevice(deviceID: deviceID, accessToken: accessToken) { success in
                            completion(success)
                        }
                    } else {
                        print("No iPhone device found for activation")
                        print("Available devices: \(devices.map { $0["name"] ?? "Unknown" })")
                        completion(false)
                    }
                } else {
                    print("No devices found in response or invalid format")
                    completion(false)
                }
            } catch {
                print("Failed to parse devices for activation: \(error)")
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
        
        print("Transferring playback to device: \(deviceID)")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error transferring playback: \(error)")
                completion(false)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Transfer playback response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 204 {
                    print("Successfully transferred playback to device")
                    completion(true)
                } else {
                    print("Failed to transfer playback. Status: \(httpResponse.statusCode)")
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("Transfer error response: \(responseString)")
                    }
                    completion(false)
                }
            } else {
                print("No HTTP response received for transfer")
                completion(false)
            }
        }.resume()
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("OAuth authentication failed: \(error.localizedDescription)")
        accessToken = nil
        updateConnectionStatus()
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("Session renewed successfully")
        accessToken = session.accessToken
        updateConnectionStatus()
        
        // Update AppRemote access token if needed
        if let appRemote = appRemote {
            appRemote.connectionParameters.accessToken = session.accessToken
        }
    }
}

// MARK: - SPTAppRemoteDelegate
extension SpotifyManager: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("🎵 AppRemote: Connected successfully! Device is now active.")
        isAppRemoteConnected = true
        print("📊 AppRemote connection status: \(isAppRemoteConnected)")
        appRemote.playerAPI?.delegate = self
        
        // Subscribe to player state to track playback
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
                        print("Note: Could not pause initial playback (might not be playing): \(error)")
                    } else {
                        print("✅ Paused device activation playback - ready for training playlist control")
                    }
                }
            }
        } else {
            print("🎵 Keeping training playlist playing - device activation complete")
        }
        
        print("🎵 AppRemote connected successfully. Device should now appear in Web API.")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didFailConnectionAttemptWithError error: Error?) {
        print("AppRemote: Failed connection attempt with error: \(error?.localizedDescription ?? "Unknown error")")
        isAppRemoteConnected = false
        print("📊 AppRemote connection status: \(isAppRemoteConnected)")
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("AppRemote: Disconnected with error: \(error?.localizedDescription ?? "No error")")
        isAppRemoteConnected = false
        print("📊 AppRemote connection status: \(isAppRemoteConnected)")
        
        // If this was an unexpected disconnection (not during reset), note it
        if error != nil {
            print("ℹ️ AppRemote disconnected unexpectedly - will auto-reconnect when app returns to foreground")
        }
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate
extension SpotifyManager: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        DispatchQueue.main.async {
            self.isPlaying = !playerState.isPaused
            self.currentTrack = playerState.track.name
        }
    }
}
