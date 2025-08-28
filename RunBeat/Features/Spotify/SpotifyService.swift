//
//  SpotifyService.swift
//  RunBeat
//
//  Extracted from SpotifyManager.swift - handles pure Spotify business logic
//

import Foundation
import SpotifyiOS
import UIKit
import Combine
import Security

protocol SpotifyServiceDelegate: AnyObject {
    func spotifyServiceDidConnect()
    func spotifyServiceDidDisconnect(error: Error?)
    func spotifyServicePlayerStateDidChange(isPlaying: Bool, trackName: String, artistName: String, artworkURL: String)
    func spotifyServiceConnectionStateDidChange(_ state: SpotifyConnectionState)
}

class SpotifyService: NSObject {
    weak var delegate: SpotifyServiceDelegate?
    
    // Unified connection management
    private let connectionManager = SpotifyConnectionManager()
    
    // Legacy properties for backward compatibility
    var isAuthenticated: Bool { connectionManager.connectionState.isAuthenticated }
    var accessToken: String? { connectionManager.connectionState.accessToken }
    var isAppRemoteConnected: Bool { connectionManager.connectionState.isAppRemoteConnected }
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    
    // Device activation state
    private var isDeviceActivating = false
    private var deviceActivationCompleted = false
    private var isStartingTrainingPlaylist = false
    
    // Configuration
    private let clientID: String
    private let clientSecret: String
    private let redirectURLString = "runbeat://spotify-login-callback"
    
    // App lifecycle monitoring
    private var cancellables = Set<AnyCancellable>()
    
    // Keychain storage
    private let keychainWrapper = KeychainWrapper.shared
    private let tokenKeychainKey = "spotify_access_token"
    
    // Data source prioritization
    private enum TrackDataSource {
        case appRemote
        case webAPI
        case none
    }
    private var currentDataSource: TrackDataSource = .none
    private var lastAppRemoteUpdate: Date = Date.distantPast
    
    // Track polling for real-time updates
    private var trackPollingTimer: Timer?
    private var isPollingActive = false
    private var isFetchingFreshData = false
    private var lastFetchedTrackName: String?
    private var workoutStartTime: Date?
    
    
    init(clientID: String, clientSecret: String) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        super.init()
        setupSpotify()
        setupAppLifecycleMonitoring()
        setupConnectionManagerObservation()
        
        // Try to restore persisted authentication
        attemptTokenRestoration()
    }
    
    private func setupConnectionManagerObservation() {
        connectionManager.$connectionState
            .sink { [weak self] newState in
                self?.handleConnectionStateChange(newState)
            }
            .store(in: &cancellables)
    }
    
    private func handleConnectionStateChange(_ state: SpotifyConnectionState) {
        print("🔄 [SpotifyService] Connection state changed to: \(state.statusMessage)")
        
        // Notify delegate about state changes
        delegate?.spotifyServiceConnectionStateDidChange(state)
        
        // Handle state-specific logic
        switch state {
        case .authenticated(let token):
            // When we have a token, try to connect AppRemote
            if let appRemote = appRemote {
                appRemote.connectionParameters.accessToken = token
                appRemote.delegate = self
                connectionManager.startAppRemoteConnection()
                appRemote.connect()
            }
            
        case .connected:
            // Fully connected - notify legacy delegate
            delegate?.spotifyServiceDidConnect()
            
        case .disconnected:
            // Disconnected - notify legacy delegate
            delegate?.spotifyServiceDidDisconnect(error: nil)
            
        case .authenticationFailed(let error), .connectionError(_, let error):
            // Error states - notify legacy delegate
            delegate?.spotifyServiceDidDisconnect(error: error)
            
        default:
            break
        }
    }
    
    // MARK: - Keychain Token Management
    
    private func storeToken(_ token: String) {
        let success = keychainWrapper.store(token, forKey: tokenKeychainKey)
        if success {
            print("✅ [SpotifyService] Successfully stored access token in keychain")
        } else {
            print("❌ [SpotifyService] Failed to store access token in keychain")
        }
    }
    
    private func retrieveStoredToken() -> String? {
        let token = keychainWrapper.retrieve(forKey: tokenKeychainKey)
        if token != nil {
            print("✅ [SpotifyService] Successfully retrieved access token from keychain")
        } else {
            print("ℹ️ [SpotifyService] No stored access token found in keychain")
        }
        return token
    }
    
    private func removeStoredToken() {
        let success = keychainWrapper.remove(forKey: tokenKeychainKey)
        if success {
            print("✅ [SpotifyService] Successfully removed access token from keychain")
        } else {
            print("❌ [SpotifyService] Failed to remove access token from keychain")
        }
    }
    
    private func attemptTokenRestoration() {
        print("🔍 [SpotifyService] Attempting to restore persisted authentication...")
        
        guard let storedToken = retrieveStoredToken() else {
            print("ℹ️ [SpotifyService] No stored token found - fresh authentication required")
            return
        }
        
        print("🔍 [SpotifyService] Found stored token, validating...")
        validateStoredToken(storedToken)
    }
    
    private func validateStoredToken(_ token: String) {
        print("🔍 [SpotifyService] Validating stored access token...")
        
        // Test the stored token with a simple API call
        let profileURL = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // Quick validation timeout
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ [SpotifyService] Token validation failed: \(error.localizedDescription)")
                self.handleInvalidStoredToken()
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [SpotifyService] Invalid response during token validation")
                self.handleInvalidStoredToken()
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ [SpotifyService] Stored token is valid - restoring session")
                self.restoreSessionWithValidToken(token)
            } else {
                print("❌ [SpotifyService] Stored token is invalid (status: \(httpResponse.statusCode))")
                self.handleInvalidStoredToken()
            }
        }.resume()
    }
    
    private func restoreSessionWithValidToken(_ token: String) {
        DispatchQueue.main.async {
            print("✅ [SpotifyService] Session restored from keychain")
            self.connectionManager.authenticationSucceeded(token: token)
            
            // If we have active polling, retry track fetch now that auth is working
            if self.isPollingActive {
                print("🔄 [SpotifyService] Authentication restored - retrying track fetch")
                self.fetchCurrentTrackViaWebAPI()
            }
        }
    }
    
    private func handleInvalidStoredToken() {
        print("🗑️ [SpotifyService] Removing invalid stored token")
        removeStoredToken()
        
        DispatchQueue.main.async {
            self.connectionManager.disconnect()
        }
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
        print("🔗 [SpotifyService] Attempting to connect to Spotify...")
        
        guard !clientID.isEmpty else {
            print("❌ [SpotifyService] ERROR: Spotify Client ID is not configured!")
            return
        }
        
        // First, check if we already have a valid session
        if isAuthenticated && accessToken != nil {
            print("✅ [SpotifyService] Already authenticated, attempting AppRemote connection...")
            if let appRemote = appRemote {
                appRemote.connect()
            }
            delegate?.spotifyServiceDidConnect()
            return
        }
        
        // Try to restore from keychain first
        if let storedToken = retrieveStoredToken() {
            print("🔍 [SpotifyService] Found stored token, validating before OAuth...")
            validateStoredTokenForConnect(storedToken)
            return
        }
        
        // No stored token or invalid token - proceed with OAuth
        initiateOAuthFlow()
    }
    
    private func validateStoredTokenForConnect(_ token: String) {
        print("🔍 [SpotifyService] Quick validation of stored token before OAuth...")
        
        let profileURL = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // Quick timeout for connect flow
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                print("✅ [SpotifyService] Stored token valid - using it for connection")
                self.restoreSessionWithValidToken(token)
            } else {
                print("❌ [SpotifyService] Stored token invalid - proceeding with OAuth")
                self.handleInvalidStoredToken()
                DispatchQueue.main.async {
                    self.initiateOAuthFlow()
                }
            }
        }.resume()
    }
    
    private func initiateOAuthFlow() {
        print("🔐 [SpotifyService] Initiating OAuth authentication flow...")
        
        connectionManager.startAuthentication()
        
        let scopes: SPTScope = [
            .playlistReadPrivate,
            .userReadPlaybackState,
            .userModifyPlaybackState,
            .userReadCurrentlyPlaying,
            .streaming,
            .appRemoteControl
        ]
        sessionManager?.initiateSession(with: scopes, options: [], campaign: "runbeat")
    }
    
    func handleCallback(url: URL) {
        print("🔄 Handling Spotify authentication callback: \(url)")
        sessionManager?.application(UIApplication.shared, open: url, options: [:])
    }
    
    func disconnect() {
        print("🔌 [SpotifyService] Disconnecting from Spotify...")
        stopTrackPolling()
        appRemote?.disconnect()
        
        // Remove stored token on explicit disconnect
        removeStoredToken()
        
        connectionManager.disconnect()
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
                // Get real data after playlist starts
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.fetchCurrentTrackViaWebAPI()
                }
            }
            completion(true)
        } else {
            if playlistID != nil {
                print("ℹ️ AppRemote not connected yet, but training playlist should be playing")
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
    
    // MARK: - Track Polling
    
    func startTrackPolling() {
        guard !isPollingActive else {
            print("🔄 Track polling already active")
            return
        }
        
        print("🎵 Starting track polling for real-time updates")
        isPollingActive = true
        workoutStartTime = Date()
        
        // Two-stage fetch for workout start to avoid stale data
        fetchFreshTrackDataForWorkout()
        
        // Set up timer for periodic updates (every 10 seconds to avoid rate limiting)
        trackPollingTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.fetchCurrentTrackViaWebAPI()
        }
    }
    
    private func fetchFreshTrackDataForWorkout() {
        guard !isFetchingFreshData else { return }
        
        print("🎵 Starting fast retry mechanism for real track data...")
        isFetchingFreshData = true
        
        // Start immediately with fast retries (300ms intervals, fewer attempts)
        fetchCurrentTrackViaWebAPIWithFastRetry(attempt: 1, maxAttempts: 10)
    }
    
    private func fetchCurrentTrackViaWebAPIWithFastRetry(attempt: Int, maxAttempts: Int) {
        guard attempt <= maxAttempts else {
            print("❌ Max fast retry attempts reached - using predicted data")
            isFetchingFreshData = false
            return
        }
        
        guard let accessToken = accessToken else {
            print("❌ No access token available for fast retry")
            isFetchingFreshData = false
            return
        }
        
        let currentlyPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: currentlyPlayingURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        let requestTimestamp = Date()
        print("🔄 Fast retry \(attempt)/\(maxAttempts) (300ms intervals)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let responseTimestamp = Date()
            
            if let error = error {
                print("❌ Network error on fast retry \(attempt): \(error)")
                self.scheduleNextFastRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response on fast retry \(attempt)")
                self.scheduleNextFastRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                return
            }
            
            switch httpResponse.statusCode {
            case 200:
                // Success! Parse and replace predicted data
                if let data = data {
                    print("✅ Got real track data on fast retry \(attempt)")
                    self.parseCurrentlyPlayingResponseWithDebug(data, requestTimestamp: requestTimestamp, responseTimestamp: responseTimestamp)
                    self.isFetchingFreshData = false
                } else {
                    self.scheduleNextFastRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                }
            case 204:
                // No music playing yet - continue fast retries
                if attempt < maxAttempts {
                    self.scheduleNextFastRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
                } else {
                    print("ℹ️ Fast retries exhausted - keeping predicted data")
                    self.isFetchingFreshData = false
                }
            case 401:
                print("❌ Token expired during fast retry")
                self.handleTokenExpired()
                self.isFetchingFreshData = false
            case 429:
                // Rate limited - slow down but continue
                print("⚠️ Rate limited - switching to slower retries")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: true)
                }
            default:
                self.scheduleNextFastRetry(attempt: attempt + 1, maxAttempts: maxAttempts)
            }
        }.resume()
    }
    
    private func scheduleNextFastRetry(attempt: Int, maxAttempts: Int) {
        guard attempt <= maxAttempts else {
            isFetchingFreshData = false
            return
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.fetchCurrentTrackViaWebAPIWithFastRetry(attempt: attempt, maxAttempts: maxAttempts)
        }
    }
    
    private func fetchCurrentTrackViaWebAPIWithRetry(attempt: Int, maxAttempts: Int, isInitialWorkoutFetch: Bool = false) {
        guard attempt <= maxAttempts else {
            print("❌ Max retry attempts reached for track fetch")
            isFetchingFreshData = false
            return
        }
        
        print("🎵 Retry attempt \(attempt)/\(maxAttempts)")
        
        guard let accessToken = accessToken else {
            print("❌ No access token available for Web API track fetch")
            isFetchingFreshData = false
            return
        }
        
        let currentlyPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: currentlyPlayingURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Network error fetching currently playing (attempt \(attempt)): \(error)")
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response from currently-playing API (attempt \(attempt))")
                // Retry after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                }
                return
            }
            
            print("📊 Currently-playing API response status: \(httpResponse.statusCode) (attempt \(attempt))")
            
            switch httpResponse.statusCode {
            case 200:
                // Music is playing - success!
                if let data = data {
                    self.parseCurrentlyPlayingResponse(data)
                    self.isFetchingFreshData = false
                    print("✅ Successfully got track data on attempt \(attempt)")
                } else {
                    print("❌ No data in currently-playing response (attempt \(attempt))")
                    // Retry after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                    }
                }
            case 204:
                // No music currently playing - retry as playlist may still be starting
                print("ℹ️ No music currently playing (attempt \(attempt)) - playlist may still be starting")
                if attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                        self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                    }
                } else {
                    print("⚠️ Max attempts reached - playlist may not have started")
                    self.notifyPlayerStateChange(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
                    self.isFetchingFreshData = false
                }
            case 401:
                print("❌ Unauthorized - access token expired")
                self.handleTokenExpired()
                self.isFetchingFreshData = false
            case 429:
                print("❌ Rate limited - will retry with longer delay")
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                }
            default:
                print("❌ API Error - Status: \(httpResponse.statusCode) (attempt \(attempt))")
                if attempt < maxAttempts {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                    }
                } else {
                    self.isFetchingFreshData = false
                }
            }
        }.resume()
    }
    
    private func validateAndRefetchIfStale() {
        // This method is no longer needed as retry mechanism handles validation
        print("🔄 Validation not needed - using retry mechanism instead")
    }
    
    func stopTrackPolling() {
        guard isPollingActive else { return }
        
        print("🎵 Stopping track polling")
        isPollingActive = false
        isFetchingFreshData = false
        workoutStartTime = nil
        lastFetchedTrackName = nil
        trackPollingTimer?.invalidate()
        trackPollingTimer = nil
    }
    
    var isTrackPollingActive: Bool {
        return isPollingActive
    }
    
    func refreshCurrentTrack() {
        // Try AppRemote first, fallback to Web API
        if let appRemote = appRemote, appRemote.isConnected {
            print("🔄 Refreshing track via AppRemote")
            appRemote.playerAPI?.getPlayerState { (playerState, error) in
                if let error = error {
                    print("Error refreshing track info via AppRemote: \(error)")
                    self.fetchCurrentTrackViaWebAPI()
                } else if let playerState = playerState as? SPTAppRemotePlayerState {
                    print("🔄 Refreshed current track info via AppRemote")
                    self.playerStateDidChange(playerState)
                }
            }
        } else {
            print("🔄 AppRemote not available, using Web API for track info")
            fetchCurrentTrackViaWebAPI()
        }
    }
    
    private func fetchCurrentTrackViaWebAPI(isInitialWorkoutFetch: Bool = false, isValidationFetch: Bool = false) {
        guard let accessToken = accessToken else {
            print("❌ No access token available for Web API track fetch")
            return
        }
        
        let currentlyPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: currentlyPlayingURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        let fetchType = isInitialWorkoutFetch ? "workout start" : (isValidationFetch ? "validation" : "regular")
        let requestTimestamp = Date()
        
        print("🔍 [WEB API DEBUG] Starting Web API track fetch")
        print("🔍 [WEB API DEBUG] Endpoint: \(currentlyPlayingURL.absoluteString)")
        print("🔍 [WEB API DEBUG] Fetch type: \(fetchType)")
        print("🔍 [WEB API DEBUG] Request timestamp: \(requestTimestamp)")
        print("🔍 [WEB API DEBUG] Access token prefix: \(accessToken.prefix(20))...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let responseTimestamp = Date()
            let requestDuration = responseTimestamp.timeIntervalSince(requestTimestamp)
            
            print("🔍 [WEB API DEBUG] Response received after \(String(format: "%.3f", requestDuration))s")
            print("🔍 [WEB API DEBUG] Response timestamp: \(responseTimestamp)")
            
            if let error = error {
                print("❌ [WEB API DEBUG] Network error: \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ [WEB API DEBUG] Invalid response from currently-playing API")
                return
            }
            
            print("🔍 [WEB API DEBUG] HTTP Status: \(httpResponse.statusCode)")
            print("🔍 [WEB API DEBUG] Response Headers:")
            for (key, value) in httpResponse.allHeaderFields {
                print("  \(key): \(value)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                if let data = data {
                    print("🔍 [WEB API DEBUG] Response data size: \(data.count) bytes")
                    self.parseCurrentlyPlayingResponseWithDebug(data, requestTimestamp: requestTimestamp, responseTimestamp: responseTimestamp)
                } else {
                    print("❌ [WEB API DEBUG] No data in currently-playing response")
                }
            case 204:
                print("ℹ️ [WEB API DEBUG] No music currently playing (204 response)")
                self.notifyPlayerStateChange(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
            case 401:
                print("❌ [WEB API DEBUG] Unauthorized - access token expired")
                self.handleTokenExpired()
            case 429:
                print("❌ [WEB API DEBUG] Rate limited - will retry later")
            default:
                print("❌ [WEB API DEBUG] API Error - Status: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("❌ [WEB API DEBUG] Error response body: \(errorString)")
                }
            }
        }.resume()
    }
    
    private func parseCurrentlyPlayingResponseWithDebug(_ data: Data, requestTimestamp: Date, responseTimestamp: Date) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Log the complete API response
                print("🔍 [WEB API DEBUG] Complete API Response JSON:")
                if let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted),
                   let prettyString = String(data: jsonData, encoding: .utf8) {
                    print(prettyString)
                } else {
                    print("Could not pretty-print JSON")
                }
                
                // Extract timing information
                let timestamp = json["timestamp"] as? Int64
                let progressMs = json["progress_ms"] as? Int
                let isPlaying = json["is_playing"] as? Bool ?? false
                
                print("🔍 [WEB API DEBUG] Playback State:")
                print("  - Is Playing: \(isPlaying)")
                print("  - Progress (ms): \(progressMs ?? -1)")
                print("  - Spotify Timestamp: \(timestamp ?? -1)")
                
                // Extract device information
                if let device = json["device"] as? [String: Any] {
                    let deviceId = device["id"] as? String ?? ""
                    let deviceName = device["name"] as? String ?? ""
                    let deviceType = device["type"] as? String ?? ""
                    let isActive = device["is_active"] as? Bool ?? false
                    let isPrivateSession = device["is_private_session"] as? Bool ?? false
                    let isRestricted = device["is_restricted"] as? Bool ?? false
                    let volumePercent = device["volume_percent"] as? Int ?? -1
                    
                    print("🔍 [WEB API DEBUG] Device Information:")
                    print("  - Device ID: \(deviceId)")
                    print("  - Device Name: \(deviceName)")
                    print("  - Device Type: \(deviceType)")
                    print("  - Is Active: \(isActive)")
                    print("  - Is Private Session: \(isPrivateSession)")
                    print("  - Is Restricted: \(isRestricted)")
                    print("  - Volume: \(volumePercent)%")
                }
                
                // Extract context information
                if let context = json["context"] as? [String: Any] {
                    let contextType = context["type"] as? String ?? ""
                    let contextUri = context["uri"] as? String ?? ""
                    let externalUrls = context["external_urls"] as? [String: Any]
                    let spotifyUrl = externalUrls?["spotify"] as? String ?? ""
                    
                    print("🔍 [WEB API DEBUG] Context Information:")
                    print("  - Context Type: \(contextType)")
                    print("  - Context URI: \(contextUri)")
                    print("  - Spotify URL: \(spotifyUrl)")
                }
                
                if let item = json["item"] as? [String: Any] {
                    let trackName = item["name"] as? String ?? ""
                    let trackId = item["id"] as? String ?? ""
                    let trackUri = item["uri"] as? String ?? ""
                    let durationMs = item["duration_ms"] as? Int ?? 0
                    let popularity = item["popularity"] as? Int ?? 0
                    let explicit = item["explicit"] as? Bool ?? false
                    
                    print("🔍 [WEB API DEBUG] Track Information:")
                    print("  - Track Name: '\(trackName)'")
                    print("  - Track ID: \(trackId)")
                    print("  - Track URI: \(trackUri)")
                    print("  - Duration (ms): \(durationMs)")
                    print("  - Popularity: \(popularity)")
                    print("  - Explicit: \(explicit)")
                    
                    // Get artist name(s) with detailed info
                    var artistName = ""
                    if let artists = item["artists"] as? [[String: Any]], !artists.isEmpty {
                        print("🔍 [WEB API DEBUG] Artist Information:")
                        for (index, artist) in artists.enumerated() {
                            let name = artist["name"] as? String ?? ""
                            let id = artist["id"] as? String ?? ""
                            let uri = artist["uri"] as? String ?? ""
                            print("  - Artist \(index + 1): '\(name)' (ID: \(id), URI: \(uri))")
                        }
                        let artistNames = artists.compactMap { $0["name"] as? String }
                        artistName = artistNames.joined(separator: ", ")
                    }
                    
                    // Get album info with detailed logging
                    var artworkURL = ""
                    if let album = item["album"] as? [String: Any] {
                        let albumName = album["name"] as? String ?? ""
                        let albumId = album["id"] as? String ?? ""
                        let albumType = album["album_type"] as? String ?? ""
                        let releaseDate = album["release_date"] as? String ?? ""
                        
                        print("🔍 [WEB API DEBUG] Album Information:")
                        print("  - Album Name: '\(albumName)'")
                        print("  - Album ID: \(albumId)")
                        print("  - Album Type: \(albumType)")
                        print("  - Release Date: \(releaseDate)")
                        
                        if let images = album["images"] as? [[String: Any]], !images.isEmpty {
                            print("🔍 [WEB API DEBUG] Album Images (\(images.count) available):")
                            for (index, image) in images.enumerated() {
                                let url = image["url"] as? String ?? ""
                                let width = image["width"] as? Int ?? 0
                                let height = image["height"] as? Int ?? 0
                                print("  - Image \(index + 1): \(width)x\(height) - \(url)")
                            }
                            
                            // Get the smallest image (usually 64x64) for efficiency
                            let sortedImages = images.sorted { (img1, img2) in
                                let height1 = img1["height"] as? Int ?? 0
                                let height2 = img2["height"] as? Int ?? 0
                                return height1 < height2
                            }
                            artworkURL = sortedImages.first?["url"] as? String ?? ""
                            print("🔍 [WEB API DEBUG] Selected artwork URL: \(artworkURL)")
                        }
                    }
                    
                    // Timing analysis
                    let timeSinceRequest = Date().timeIntervalSince(requestTimestamp)
                    let timeSinceResponse = Date().timeIntervalSince(responseTimestamp)
                    
                    print("🔍 [WEB API DEBUG] Timing Analysis:")
                    print("  - Time since request started: \(String(format: "%.3f", timeSinceRequest))s")
                    print("  - Time since response received: \(String(format: "%.3f", timeSinceResponse))s")
                    if let timestamp = timestamp {
                        let spotifyTimestamp = Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
                        let timeSinceSpotifyTimestamp = Date().timeIntervalSince(spotifyTimestamp)
                        print("  - Time since Spotify timestamp: \(String(format: "%.3f", timeSinceSpotifyTimestamp))s")
                    }
                    
                    print("✅ [WEB API DEBUG] Final parsed Web API track data:")
                    print("  - Track: '\(trackName)'")
                    print("  - Artist: '\(artistName)'")
                    print("  - Playing: \(isPlaying)")
                    print("  - Artwork: '\(artworkURL)'")
                    
                    // Track the last fetched track for stale data detection
                    self.lastFetchedTrackName = trackName
                    
                    // Ensure artwork URL is in displayable format
                    let displayableArtworkURL = self.convertToDisplayableImageURL(artworkURL)
                    
                    // Check data source prioritization before updating UI
                    self.handleWebAPITrackData(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: displayableArtworkURL)
                } else {
                    print("ℹ️ [WEB API DEBUG] No track item in currently-playing response")
                    // Only update UI with "no music" if AppRemote is not providing data
                    self.handleWebAPITrackData(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
                }
            }
        } catch {
            print("❌ [WEB API DEBUG] Error parsing currently-playing response: \(error)")
        }
    }
    
    private func parseCurrentlyPlayingResponse(_ data: Data) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let isPlaying = json["is_playing"] as? Bool ?? false
                
                if let item = json["item"] as? [String: Any] {
                    let trackName = item["name"] as? String ?? ""
                    
                    // Get artist name(s)
                    var artistName = ""
                    if let artists = item["artists"] as? [[String: Any]], !artists.isEmpty {
                        let artistNames = artists.compactMap { $0["name"] as? String }
                        artistName = artistNames.joined(separator: ", ")
                    }
                    
                    // Get album artwork URL
                    var artworkURL = ""
                    if let album = item["album"] as? [String: Any],
                       let images = album["images"] as? [[String: Any]], !images.isEmpty {
                        // Get the smallest image (usually 64x64) for efficiency
                        let sortedImages = images.sorted { (img1, img2) in
                            let height1 = img1["height"] as? Int ?? 0
                            let height2 = img2["height"] as? Int ?? 0
                            return height1 < height2
                        }
                        artworkURL = sortedImages.first?["url"] as? String ?? ""
                    }
                    
                    print("✅ Parsed Web API track data:")
                    print("  - Track: '\(trackName)'")
                    print("  - Artist: '\(artistName)'")
                    print("  - Playing: \(isPlaying)")
                    print("  - Artwork: '\(artworkURL)'")
                    
                    // Track the last fetched track for stale data detection
                    self.lastFetchedTrackName = trackName
                    
                    // Ensure artwork URL is in displayable format
                    let displayableArtworkURL = self.convertToDisplayableImageURL(artworkURL)
                    
                    // Check data source prioritization before updating UI
                    self.handleWebAPITrackData(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: displayableArtworkURL)
                } else {
                    print("ℹ️ No track item in currently-playing response")
                    // Only update UI with "no music" if AppRemote is not providing data
                    self.handleWebAPITrackData(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
                }
            }
        } catch {
            print("❌ Error parsing currently-playing response: \(error)")
        }
    }
    
    private func handleTokenExpired() {
        print("🔄 [SpotifyService] Access token expired - clearing authentication state")
        
        // Remove expired token from keychain
        removeStoredToken()
        
        connectionManager.tokenExpired()
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
            // Get real track data instead of placeholder
            fetchCurrentTrackViaWebAPI()
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
        } else if accessToken != nil {
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
                    print("✅ Successfully paused via AppRemote")
                    // Don't immediately clear track data - let AppRemote delegate update with actual state
                    // AppRemote will call playerStateDidChange with correct track info + isPlaying: false
                    print("🎵 Waiting for AppRemote to confirm pause state with track info...")
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
    
    // MARK: - Public Connection Manager Access
    
    var connectionState: SpotifyConnectionState {
        return connectionManager.connectionState
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
        guard accessToken != nil else { return }
        
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
    
    // MARK: - Image URL Conversion
    
    /// Converts Spotify image identifiers to displayable URLs
    /// Handles both AppRemote identifiers (spotify:image:hash) and Web API URLs
    private func convertToDisplayableImageURL(_ artworkString: String) -> String {
        // Return empty string if input is empty
        guard !artworkString.isEmpty else {
            return ""
        }
        
        // Check if it's a Spotify image identifier format
        if artworkString.hasPrefix("spotify:image:") {
            // Extract the hash by removing the "spotify:image:" prefix
            let hash = String(artworkString.dropFirst("spotify:image:".count))
            let convertedURL = "https://i.scdn.co/image/\(hash)"
            
            print("🖼️ [IMAGE CONVERSION] Spotify identifier → URL:")
            print("  - Original: '\(artworkString)'")
            print("  - Converted: '\(convertedURL)'")
            
            return convertedURL
        } else if artworkString.hasPrefix("https://") || artworkString.hasPrefix("http://") {
            // Already a full URL - return as-is
            print("🖼️ [IMAGE CONVERSION] Already a URL: '\(artworkString)'")
            return artworkString
        } else {
            // Assume it's just a hash without prefix (AppRemote sometimes provides just the hash)
            let convertedURL = "https://i.scdn.co/image/\(artworkString)"
            
            print("🖼️ [IMAGE CONVERSION] Hash → URL:")
            print("  - Original: '\(artworkString)'")  
            print("  - Converted: '\(convertedURL)'")
            
            return convertedURL
        }
    }
    
    // MARK: - Data Source Prioritization
    
    private func handleWebAPITrackData(isPlaying: Bool, trackName: String, artistName: String, artworkURL: String) {
        let currentTime = Date()
        let timeSinceAppRemote = currentTime.timeIntervalSince(lastAppRemoteUpdate)
        
        // Only use Web API data if:
        // 1. No AppRemote data has been received, OR
        // 2. AppRemote data is older than 30 seconds (connection likely lost)
        let shouldUseWebAPIData = currentDataSource == .none || timeSinceAppRemote > 30.0
        
        if shouldUseWebAPIData {
            print("✅ [DATA SOURCE] Using Web API data (AppRemote unavailable or stale)")
            print("  - Data source priority: Web API (fallback)")
            print("  - Time since AppRemote: \(String(format: "%.1f", timeSinceAppRemote))s")
            
            currentDataSource = .webAPI
            notifyPlayerStateChange(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: artworkURL)
        } else {
            print("🚫 [DATA SOURCE] Ignoring Web API data - AppRemote data is more recent")
            print("  - Data source priority: AppRemote (preferred)")
            print("  - Time since AppRemote: \(String(format: "%.1f", timeSinceAppRemote))s")
            print("  - Discarding Web API track: '\(trackName)'")
        }
    }
    
    private func notifyPlayerStateChange(isPlaying: Bool, trackName: String, artistName: String = "", artworkURL: String = "") {
        print("🎵 [SpotifyService] Notifying delegate with player state:")
        print("  - Track: '\(trackName)'")
        print("  - Artist: '\(artistName)'")
        print("  - Artwork: '\(artworkURL)'")
        print("  - Playing: \(isPlaying)")
        
        delegate?.spotifyServicePlayerStateDidChange(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: artworkURL)
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
                    // Don't immediately clear track data - fetch current state to get actual paused track info
                    print("🎵 Fetching current track state after Web API pause...")
                    self.fetchCurrentTrackViaWebAPI()
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
        guard accessToken != nil else { return }
        
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
        
        let bundleId = Bundle.main.bundleIdentifier ?? "com.runbeat.app"
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
                // Get real track info via Web API after starting playback
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.fetchCurrentTrackViaWebAPI()
                }
            }
        }
    }
}

// MARK: - SPTSessionManagerDelegate
extension SpotifyService: SPTSessionManagerDelegate {
    func sessionManager(manager: SPTSessionManager, didInitiate session: SPTSession) {
        print("✅ [SpotifyService] OAuth authentication successful!")
        
        // Store the token in keychain for future use
        storeToken(session.accessToken)
        
        // Validate token works before updating connection state
        validateAuthenticationAndConnect(session: session)
    }
    
    private func validateAuthenticationAndConnect(session: SPTSession) {
        print("🔍 Validating access token...")
        
        // Test the access token with a simple API call
        let profileURL = URL(string: "https://api.spotify.com/v1/me")!
        var request = URLRequest(url: profileURL)
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("❌ Token validation failed: \(error)")
                self.connectionManager.authenticationFailed(error: error)
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid response during token validation")
                let validationError = SpotifyConnectionError.tokenValidationFailed
                self.connectionManager.authenticationFailed(error: validationError)
                return
            }
            
            if httpResponse.statusCode == 200 {
                print("✅ Access token validated successfully")
                
                DispatchQueue.main.async {
                    self.connectionManager.authenticationSucceeded(token: session.accessToken)
                    
                    // If we have active polling, retry track fetch now that auth is working
                    if self.isPollingActive {
                        print("🔄 Authentication restored - retrying track fetch")
                        self.fetchCurrentTrackViaWebAPI()
                    }
                }
            } else {
                print("❌ Token validation failed with status: \(httpResponse.statusCode)")
                self.connectionManager.authenticationFailed(error: SpotifyError.tokenExpired)
            }
        }.resume()
    }
    
    func sessionManager(manager: SPTSessionManager, didFailWith error: Error) {
        print("❌ [SpotifyService] OAuth authentication failed: \(error.localizedDescription)")
        
        // Clear any potentially invalid stored token on auth failure
        removeStoredToken()
        
        connectionManager.authenticationFailed(error: error)
    }
    
    func sessionManager(manager: SPTSessionManager, didRenew session: SPTSession) {
        print("✅ [SpotifyService] Session renewed successfully")
        
        // Update stored token with renewed one
        storeToken(session.accessToken)
        
        // Update connection manager with new token
        connectionManager.authenticationSucceeded(token: session.accessToken)
    }
}

// MARK: - SPTAppRemoteDelegate  
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("🎵 AppRemote: Connected successfully! Device is now active.")
        connectionManager.appRemoteConnectionSucceeded()
        appRemote.playerAPI?.delegate = self
        
        // Subscribe to player state for real-time track info
        appRemote.playerAPI?.subscribe(toPlayerState: { (result, error) in
            if let error = error {
                print("Error subscribing to player state: \(error)")
            } else {
                print("✅ Successfully subscribed to player state updates")
            }
        })
        
        // Also get current player state immediately
        appRemote.playerAPI?.getPlayerState { (playerState, error) in
            if let error = error {
                print("Error getting initial player state: \(error)")
            } else if let playerState = playerState as? SPTAppRemotePlayerState {
                print("🎵 Got initial player state")
                self.playerStateDidChange(playerState)
            }
        }
        
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
        let connectionError = error ?? SpotifyConnectionError.appRemoteConnectionTimeout
        connectionManager.appRemoteConnectionFailed(error: connectionError)
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("AppRemote: Disconnected with error: \(error?.localizedDescription ?? "No error")")
        // Reset data source tracking when AppRemote disconnects
        print("🔄 [DATA SOURCE] AppRemote disconnected - allowing Web API fallback")
        currentDataSource = .none
        lastAppRemoteUpdate = Date.distantPast
        
        connectionManager.appRemoteDisconnected(error: error)
    }
}

// MARK: - SPTAppRemotePlayerStateDelegate
extension SpotifyService: SPTAppRemotePlayerStateDelegate {
    func playerStateDidChange(_ playerState: SPTAppRemotePlayerState) {
        let timestamp = Date()
        let isPlaying = !playerState.isPaused
        let trackName = playerState.track.name
        let artistName = playerState.track.artist.name
        let trackURI = playerState.track.uri
        let duration = playerState.track.duration
        let playbackPosition = playerState.playbackPosition
        
        // Convert Spotify image identifier to actual URL using utility function
        let imageIdentifier = playerState.track.imageIdentifier
        let artworkURL = convertToDisplayableImageURL(imageIdentifier)
        
        print("🎵 [APPREMOTE DEBUG] Player state changed at \(timestamp)")
        print("🎵 [APPREMOTE DEBUG] Track Details:")
        print("  - Track Name: '\(trackName)'")
        print("  - Artist Name: '\(artistName)'")  
        print("  - Track URI: \(trackURI)")
        print("  - Duration: \(duration)ms")
        print("  - Playback Position: \(playbackPosition)ms")
        print("  - Is Playing: \(isPlaying)")
        print("  - Image Identifier: \(imageIdentifier)")
        print("  - Artwork URL: \(artworkURL)")
        
        // AppRemote data is always prioritized as the authoritative source
        // Update data source tracking
        currentDataSource = .appRemote
        lastAppRemoteUpdate = Date()
        
        print("✅ [DATA SOURCE] AppRemote data received - setting as authoritative source")
        print("  - Data source priority: AppRemote (highest)")
        
        notifyPlayerStateChange(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: artworkURL)
    }
}

// MARK: - Playlist Management
extension SpotifyService {
    func fetchUserPlaylists(completion: @escaping (Result<[SpotifyPlaylist], Error>) -> Void) {
        guard let accessToken = accessToken else {
            print("❌ No access token available for playlist fetch")
            completion(.failure(SpotifyError.notAuthenticated))
            return
        }
        
        guard isAuthenticated else {
            print("❌ Not authenticated with Spotify")
            completion(.failure(SpotifyError.notAuthenticated))
            return
        }
        
        let playlistsURL = URL(string: "https://api.spotify.com/v1/me/playlists?limit=50&offset=0")!
        var request = URLRequest(url: playlistsURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        print("🎵 Fetching user playlists from Spotify Web API...")
        print("🔑 Using access token: \(accessToken.prefix(20))...")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            // Handle network errors
            if let error = error {
                print("❌ Network error fetching playlists: \(error.localizedDescription)")
                completion(.failure(SpotifyError.networkError(error.localizedDescription)))
                return
            }
            
            guard let data = data else {
                print("❌ No data received from playlists API")
                completion(.failure(SpotifyError.noData))
                return
            }
            
            // Log response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 Playlist API Response: \(responseString.prefix(500))...")
            }
            
            // Handle HTTP errors
            if let httpResponse = response as? HTTPURLResponse {
                print("📊 Playlists API response status: \(httpResponse.statusCode)")
                
                switch httpResponse.statusCode {
                case 200:
                    // Success - continue to parsing
                    break
                case 401:
                    print("❌ Unauthorized - access token expired or invalid")
                    self?.handleTokenExpired()
                    completion(.failure(SpotifyError.tokenExpired))
                    return
                case 403:
                    print("❌ Forbidden - insufficient permissions")
                    completion(.failure(SpotifyError.insufficientPermissions))
                    return
                case 429:
                    print("❌ Rate limited")
                    completion(.failure(SpotifyError.rateLimited))
                    return
                default:
                    print("❌ API Error - Status: \(httpResponse.statusCode)")
                    completion(.failure(SpotifyError.apiError(httpResponse.statusCode)))
                    return
                }
            }
            
            // Parse JSON response
            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(SpotifyPlaylist.APIResponse.self, from: data)
                let playlists = apiResponse.items.map { SpotifyPlaylist.from($0) }
                
                print("✅ Successfully fetched \(playlists.count) playlists")
                for playlist in playlists.prefix(5) {
                    print("   - \(playlist.name) (\(playlist.trackCount) tracks)")
                }
                
                completion(.success(playlists))
            } catch let decodingError {
                print("❌ Error decoding playlists response: \(decodingError)")
                if let decodingError = decodingError as? DecodingError {
                    self?.logDecodingError(decodingError)
                }
                completion(.failure(SpotifyError.decodingError(decodingError.localizedDescription)))
            }
        }.resume()
    }
    
    private func logDecodingError(_ error: DecodingError) {
        switch error {
        case .typeMismatch(let type, let context):
            print("Type mismatch for type \(type): \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        case .valueNotFound(let type, let context):
            print("Value not found for type \(type): \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        case .keyNotFound(let key, let context):
            print("Key not found: \(key.stringValue): \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        case .dataCorrupted(let context):
            print("Data corrupted: \(context.debugDescription)")
            print("Coding path: \(context.codingPath)")
        @unknown default:
            print("Unknown decoding error: \(error)")
        }
    }
}

// MARK: - Error Types
enum SpotifyError: LocalizedError {
    case notAuthenticated
    case noData
    case apiError(Int)
    case networkError(String)
    case tokenExpired
    case insufficientPermissions
    case rateLimited
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Not authenticated with Spotify"
        case .noData:
            return "No data received from Spotify"
        case .apiError(let code):
            return "Spotify API error (code: \(code))"
        case .networkError(let message):
            return "Network error: \(message)"
        case .tokenExpired:
            return "Spotify session expired. Please reconnect."
        case .insufficientPermissions:
            return "Insufficient Spotify permissions"
        case .rateLimited:
            return "Too many requests. Please try again later."
        case .decodingError(let message):
            return "Data parsing error: \(message)"
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .tokenExpired, .networkError, .rateLimited:
            return true
        case .notAuthenticated, .insufficientPermissions:
            return false
        case .noData, .apiError, .decodingError:
            return true
        }
    }
}
