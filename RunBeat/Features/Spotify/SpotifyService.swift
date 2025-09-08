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
    
    // Unified data source coordination
    private let dataCoordinator = SpotifyDataCoordinator()
    
    // Structured error handling and recovery
    private let errorHandler = SpotifyErrorHandler()
    
    // Legacy properties for backward compatibility
    var isAuthenticated: Bool { connectionManager.connectionState.isAuthenticated }
    var accessToken: String? { connectionManager.connectionState.accessToken }
    var isAppRemoteConnected: Bool { connectionManager.connectionState.isAppRemoteConnected }
    private var appRemote: SPTAppRemote?
    private var sessionManager: SPTSessionManager?
    
    // Connection management
    private var isAppRemoteConnectionInProgress = false
    private var appRemoteSubscriptionID: Any?
    private var isAutomaticSpotifyActivationInProgress = false
    
    // Device activation state
    private var isDeviceActivating = false
    private var deviceActivationCompleted = false
    private var isStartingTrainingPlaylist = false
    
    // Token refresh state
    private var isTokenRefreshInProgress = false
    
    // Training state tracking for API optimization
    
    // Resource-aware recovery management
    private var activeRecoveryTasks: [ErrorPriority: [String: Task<Void, Never>]] = [
        .trainingCritical: [:],
        .trainingEnhancing: [:], 
        .background: [:]
    ]
    
    private let recoveryLimits: [ErrorPriority: Int] = [
        .trainingCritical: 2,    // Device activation + playlist operations
        .trainingEnhancing: 1,   // Track polling, artwork loading
        .background: 1           // Token refresh, maintenance
    ]
    
    // Configuration
    private let clientID: String
    private let clientSecret: String
    private let redirectURLString = "runbeat://spotify-login-callback"
    
    // App lifecycle monitoring
    private var cancellables = Set<AnyCancellable>()
    
    // Keychain storage
    private let keychainWrapper = KeychainWrapper.shared
    private let tokenKeychainKey = "spotify_access_token"
    private let refreshTokenKeychainKey = "spotify_refresh_token"
    
    // Coordinated track data access
    var currentTrack: SpotifyTrackInfo { dataCoordinator.currentTrack }
    var hasValidTrackData: Bool { dataCoordinator.hasValidData }
    var trackDataSource: String { dataCoordinator.dataSourceInUse.rawValue }
    var dataCoordinatorPublisher: SpotifyDataCoordinator { dataCoordinator }
    
    // Error handling access
    var errorHandlerPublisher: SpotifyErrorHandler { errorHandler }
    
    // Device activation state access
    var wasAutomaticSpotifyActivationRecent: Bool { isAutomaticSpotifyActivationInProgress }
    
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
    
    /// Helper method to start AppRemote connection without race conditions
    private func startAppRemoteConnectionWithToken(_ token: String) {
        connectionManager.startAppRemoteConnectionWithToken(token)
    }
    
    /// Connects to AppRemote on-demand when actually needed
    private func ensureAppRemoteConnection() {
        guard let appRemote = appRemote,
              let token = accessToken else {
            print("⚠️ [SpotifyService] Cannot ensure AppRemote connection - missing app remote or token")
            return
        }
        
        // Only connect if not already connected or connecting
        guard !appRemote.isConnected && !isAppRemoteConnectionInProgress else {
            print("✅ [SpotifyService] AppRemote already connected or connecting")
            return
        }
        
        print("🔄 [SpotifyService] Connecting AppRemote on-demand...")
        isAppRemoteConnectionInProgress = true
        startAppRemoteConnectionWithToken(token)
        appRemote.connect()
    }
    
    private func handleConnectionStateChange(_ state: SpotifyConnectionState) {
        print("🔄 [SpotifyService] Connection state changed to: \(state.statusMessage)")
        
        // Notify delegate about state changes
        delegate?.spotifyServiceConnectionStateDidChange(state)
        
        // Handle state-specific logic
        switch state {
        case .authenticated(let token):
            // When we have a token, prepare AppRemote but don't auto-connect
            // AppRemote connection will happen on-demand when user needs it
            if let appRemote = appRemote {
                appRemote.connectionParameters.accessToken = token
                appRemote.delegate = self
                print("✅ [SpotifyService] AppRemote configured with token - ready for on-demand connection")
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
    
    /// Stores both access token and refresh token from SPTSession
    private func storeAuthenticationTokens(session: SPTSession) {
        // Store access token (keeping keychain as offline fallback)
        let accessSuccess = keychainWrapper.store(session.accessToken, forKey: tokenKeychainKey)
        
        // Store refresh token if available
        var refreshSuccess = true
        let refreshToken = session.refreshToken
        if !refreshToken.isEmpty {
            refreshSuccess = keychainWrapper.store(refreshToken, forKey: refreshTokenKeychainKey)
            
            // Send tokens to backend immediately after OAuth success
            Task {
                do {
                    try await BackendService.shared.storeSpotifyTokens(
                        accessToken: session.accessToken,
                        refreshToken: refreshToken,
                        expiresIn: Int(session.expirationDate.timeIntervalSinceNow)
                    )
                    print("✅ [SpotifyService] Tokens sent to backend successfully")
                } catch {
                    print("⚠️ [SpotifyService] Failed to send tokens to backend: \(error.localizedDescription)")
                    // Continue with keychain fallback - don't fail authentication
                }
            }
            print("✅ [SpotifyService] Stored refresh token in keychain: \(refreshSuccess)")
        } else {
            print("⚠️ [SpotifyService] No refresh token available in session")
        }
        
        if accessSuccess && refreshSuccess {
            print("✅ [SpotifyService] Successfully stored authentication tokens in keychain")
        } else {
            print("❌ [SpotifyService] Failed to store some authentication tokens in keychain")
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
    
    private func retrieveStoredRefreshToken() -> String? {
        let token = keychainWrapper.retrieve(forKey: refreshTokenKeychainKey)
        if token != nil {
            print("✅ [SpotifyService] Successfully retrieved refresh token from keychain")
        } else {
            print("ℹ️ [SpotifyService] No stored refresh token found in keychain")
        }
        return token
    }
    
    private func removeStoredToken() {
        let accessTokenSuccess = keychainWrapper.remove(forKey: tokenKeychainKey)
        let refreshTokenSuccess = keychainWrapper.remove(forKey: refreshTokenKeychainKey)
        
        if accessTokenSuccess && refreshTokenSuccess {
            print("✅ [SpotifyService] Successfully removed authentication tokens from keychain")
        } else {
            print("❌ [SpotifyService] Failed to remove some authentication tokens from keychain")
        }
    }
    
    private func attemptTokenRestoration() {
        print("🔍 [SpotifyService] Attempting to restore persisted authentication...")
        
        // Check what's in keychain
        let storedAccessToken = keychainWrapper.retrieve(forKey: tokenKeychainKey)
        let storedRefreshToken = keychainWrapper.retrieve(forKey: refreshTokenKeychainKey)
        
        print("🔍 [SpotifyService] Keychain state:")
        print("   - Has access token: \(storedAccessToken != nil)")
        print("   - Has refresh token: \(storedRefreshToken != nil)")
        print("   - Connection state: \(connectionManager.connectionState)")
        
        guard let storedToken = storedAccessToken else {
            print("ℹ️ [SpotifyService] No stored access token found - fresh authentication required")
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
        print("🗑️ [SpotifyService] Access token invalid - attempting refresh...")
        
        // Try to refresh the token before giving up
        if let refreshToken = retrieveStoredRefreshToken() {
            refreshAccessToken(refreshToken: refreshToken) { [weak self] success in
                if !success {
                    // Refresh failed, remove tokens and disconnect
                    print("🗑️ [SpotifyService] Token refresh failed - removing invalid stored tokens")
                    self?.removeStoredToken()
                    DispatchQueue.main.async {
                        self?.connectionManager.disconnect()
                    }
                }
            }
        } else {
            // No refresh token available, remove tokens and disconnect
            print("🗑️ [SpotifyService] No refresh token available - removing invalid stored token")
            removeStoredToken()
            DispatchQueue.main.async {
                self.connectionManager.disconnect()
            }
        }
    }
    
    /// Refreshes the access token using the backend service
    private func refreshAccessToken(refreshToken: String, completion: @escaping (Bool) -> Void) {
        // Prevent concurrent refresh attempts
        guard !isTokenRefreshInProgress else {
            print("🔄 [SpotifyService] Token refresh already in progress, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.refreshAccessToken(refreshToken: refreshToken, completion: completion)
            }
            return
        }
        
        print("🔄 [SpotifyService] Attempting to get fresh token from backend...")
        isTokenRefreshInProgress = true
        
        Task {
            do {
                // Get fresh token from backend (backend handles refresh automatically)
                let tokenResponse = try await BackendService.shared.getFreshSpotifyToken()
                
                // Update local keychain with fresh token (fallback storage)
                let success = keychainWrapper.store(tokenResponse.accessToken, forKey: tokenKeychainKey)
                
                if let newRefreshToken = tokenResponse.refreshToken {
                    keychainWrapper.store(newRefreshToken, forKey: refreshTokenKeychainKey)
                }
                
                // Update connection manager with new token
                DispatchQueue.main.async { [weak self] in
                    self?.isTokenRefreshInProgress = false
                    self?.connectionManager.authenticationSucceeded(token: tokenResponse.accessToken)
                    print("✅ [SpotifyService] Successfully refreshed access token via backend")
                    completion(true)
                }
                
            } catch {
                print("❌ [SpotifyService] Backend token refresh failed: \(error.localizedDescription)")
                
                // Fallback to local token refresh if backend is unavailable
                if let backendError = error as? BackendError, backendError.isNetworkUnavailable {
                    print("🔄 [SpotifyService] Backend unavailable, attempting local token refresh fallback...")
                    self.refreshAccessTokenLocal(refreshToken: refreshToken, completion: completion)
                } else {
                    DispatchQueue.main.async { [weak self] in
                        self?.isTokenRefreshInProgress = false
                        completion(false)
                    }
                }
            }
        }
    }
    
    /// Local token refresh fallback when backend is unavailable
    private func refreshAccessTokenLocal(refreshToken: String, completion: @escaping (Bool) -> Void) {
        let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Create credentials for Basic auth (client_id:client_secret base64 encoded)
        let credentials = "\(clientID):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let credentialsBase64 = credentialsData.base64EncodedString()
        request.setValue("Basic \(credentialsBase64)", forHTTPHeaderField: "Authorization")
        
        // Create form data
        let formData = "grant_type=refresh_token&refresh_token=\(refreshToken)"
        request.httpBody = formData.data(using: .utf8)
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            defer {
                self?.isTokenRefreshInProgress = false
            }
            
            guard let self = self else { 
                completion(false)
                return 
            }
            
            if let error = error {
                print("❌ [SpotifyService] Token refresh network error: \(error.localizedDescription)")
                completion(false)
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse else {
                print("❌ [SpotifyService] Invalid response during token refresh")
                completion(false)
                return
            }
            
            if httpResponse.statusCode == 200 {
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let newAccessToken = json["access_token"] as? String {
                    
                    print("✅ [SpotifyService] Successfully refreshed access token")
                    
                    // Store new access token
                    self.storeToken(newAccessToken)
                    
                    // If there's a new refresh token, store that too
                    if let newRefreshToken = json["refresh_token"] as? String {
                        let success = self.keychainWrapper.store(newRefreshToken, forKey: self.refreshTokenKeychainKey)
                        print("🔄 [SpotifyService] Updated refresh token: \(success)")
                    }
                    
                    // Update connection manager with new token
                    DispatchQueue.main.async {
                        self.connectionManager.authenticationSucceeded(token: newAccessToken)
                    }
                    
                    completion(true)
                } else {
                    print("❌ [SpotifyService] Invalid JSON in token refresh response")
                    completion(false)
                }
            } else {
                print("❌ [SpotifyService] Token refresh failed with status: \(httpResponse.statusCode)")
                if let responseData = String(data: data, encoding: .utf8) {
                    print("❌ [SpotifyService] Response: \(responseData)")
                }
                completion(false)
            }
        }.resume()
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
        
        // Delay clearing automatic activation flag to allow connection state changes to see it
        if isAutomaticSpotifyActivationInProgress {
            print("🔄 [DeviceActivation] Scheduling automatic activation flag clearance in 3 seconds")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.isAutomaticSpotifyActivationInProgress {
                    print("🔄 [DeviceActivation] Clearing automatic activation flag after delay")
                    self.isAutomaticSpotifyActivationInProgress = false
                }
            }
        }
        
        // Don't auto-connect AppRemote on foreground - let it connect on-demand when needed
        if accessToken != nil {
            print("✅ [SpotifyService] Token available - AppRemote ready for on-demand connection")
        }
    }
    
    /// Check if there's an active training session that shouldn't be interrupted
    private func isTrainingSessionActive() -> Bool {
        // Use intent-based architecture - training intent indicates active session
        return getCurrentIntent() == .training
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
            print("✅ [SpotifyService] Already authenticated - ready for on-demand connection")
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
        
        // Check if connection is already in progress
        if isAppRemoteConnectionInProgress {
            print("⏳ AppRemote connection already in progress, waiting...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                completion(appRemote.isConnected || self.deviceActivationCompleted)
            }
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
    
    // MARK: - Centralized API Call with Auto Token Refresh
    
    /// Makes an authenticated API call with automatic token refresh on 401
    private func makeAuthenticatedAPICall(
        request: URLRequest,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        makeAuthenticatedAPICallWithRetry(request: request, isRetry: false, completion: completion)
    }
    
    private func makeAuthenticatedAPICallWithRetry(
        request: URLRequest,
        isRetry: Bool,
        completion: @escaping (Data?, URLResponse?, Error?) -> Void
    ) {
        // Get fresh token from backend if available, otherwise use local token
        Task {
            var tokenToUse: String?
            
            // Try to get fresh token from backend first
            do {
                let tokenResponse = try await BackendService.shared.getFreshSpotifyToken()
                tokenToUse = tokenResponse.accessToken
                print("🔄 [SpotifyService] Using fresh token from backend for API call")
                
                // Update local storage as fallback
                keychainWrapper.store(tokenResponse.accessToken, forKey: tokenKeychainKey)
                
            } catch {
                // Fallback to local token
                tokenToUse = accessToken
                print("🔄 [SpotifyService] Backend unavailable, using local token for API call")
            }
            
            guard let finalToken = tokenToUse else {
                completion(nil, nil, SpotifyError.notAuthenticated)
                return
            }
            
            // Add authorization header
            var authenticatedRequest = request
            authenticatedRequest.setValue("Bearer \(finalToken)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: authenticatedRequest) { [weak self] data, response, error in
                // Check for 401 (token expired)
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                    if !isRetry, let refreshToken = self?.retrieveStoredRefreshToken() {
                        print("🔄 Token expired (401) - attempting refresh and retry")
                        self?.refreshAccessToken(refreshToken: refreshToken) { success in
                            if success {
                                // Retry the original request with new token
                                self?.makeAuthenticatedAPICallWithRetry(request: request, isRetry: true, completion: completion)
                            } else {
                                // Refresh failed - disconnect
                                self?.handleTokenExpired()
                                completion(nil, response, SpotifyError.tokenExpired)
                            }
                        }
                    } else {
                        // Already retried or no refresh token - fail
                        self?.handleTokenExpired()
                        completion(nil, response, SpotifyError.tokenExpired)
                    }
                } else {
                    // Not a 401 - return result as-is
                    completion(data, response, error)
                }
            }.resume()
        }
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
        print("🔄 [DeviceActivation] Using authorizeAndPlayURI to activate device - setting automatic activation flag")
        isAutomaticSpotifyActivationInProgress = true
        appRemote.authorizeAndPlayURI(playURI)
        appRemote.delegate = self
        
        // Only connect if not already connected or connecting
        if !appRemote.isConnected && !isAppRemoteConnectionInProgress {
            isAppRemoteConnectionInProgress = true
            // Connect for control
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if !appRemote.isConnected {
                    print("🔄 [DeviceActivation] Connecting AppRemote after authorization")
                    appRemote.connect()
                }
            }
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
    
    // MARK: - Intent-Based State Management
    
    /// Spotify usage intent - drives all connection and recovery behavior
    enum SpotifyIntent {
        case training      // Active training - requires AppRemote connection and aggressive recovery
        case idle         // Not training - minimal connection, background-only recovery
        case disconnected // Explicitly disconnected - no recovery attempts
    }
    
    private var currentIntent: SpotifyIntent = .idle
    private let intentQueue = DispatchQueue(label: "spotify.intent", qos: .userInitiated)
    
    /// Synchronously sets Spotify usage intent and updates all dependent systems
    func setIntent(_ intent: SpotifyIntent) {
        intentQueue.sync {
            let oldIntent = currentIntent
            currentIntent = intent
            
            print("🎵 [Intent] Spotify intent: \(oldIntent) → \(intent)")
            
            // Update systems on main thread to handle UI-related operations
            if Thread.isMainThread {
                updateSystemsForIntentChange(from: oldIntent, to: intent)
            } else {
                DispatchQueue.main.async { [self] in
                    updateSystemsForIntentChange(from: oldIntent, to: intent)
                }
            }
        }
    }
    
    /// Thread-safe intent getter
    func getCurrentIntent() -> SpotifyIntent {
        return intentQueue.sync { currentIntent }
    }
    
    private func updateSystemsForIntentChange(from oldIntent: SpotifyIntent, to newIntent: SpotifyIntent) {
        switch (oldIntent, newIntent) {
        case (_, .training):
            activateForTraining()
            
        case (.training, .idle):
            deactivateFromTraining()
            
        case (.training, .disconnected):
            disconnectExplicitly()
            
        case (.idle, .disconnected):
            disconnectExplicitly()
            
        case (_, .idle):
            // Transition to idle from any other state
            transitionToIdle()
            
        case (.disconnected, .disconnected):
            // No-op: already disconnected
            print("🎯 [Intent] Already disconnected - no action needed")
        }
    }
    
    private func activateForTraining() {
        print("🎯 [Intent] Activating for training - enabling aggressive recovery")
        print("🎵 [Intent] Training mode activated - AppRemote failures will be aggressively recovered")
    }
    
    private func deactivateFromTraining() {
        print("🎯 [Intent] Deactivating from training - switching to dormant mode")
        
        // Cancel training-related recovery tasks
        cancelRecoveryTasks(for: .trainingCritical, reason: "Training stopped")
        cancelRecoveryTasks(for: .trainingEnhancing, reason: "Training stopped")
        
        // Don't proactively disconnect - just stop caring about events
        appRemoteSubscriptionID = nil
        print("🔌 [Intent] Training deactivated - AppRemote now dormant (connected but ignored)")
        print("🧹 [Intent] Cleaned up training-related systems")
    }
    
    private func disconnectExplicitly() {
        print("🎯 [Intent] Explicit disconnection - stopping all recovery")
        
        // Cancel all recovery tasks
        cancelAllRecoveryTasks(reason: "Explicit disconnection")
        
        // Only disconnect when explicitly requested (user logout, etc.)
        appRemoteSubscriptionID = nil
        appRemote?.disconnect()
        print("🔌 [Intent] AppRemote explicitly disconnected")
    }
    
    private func transitionToIdle() {
        print("🎯 [Intent] Transitioning to idle state")
        print("🎵 [Intent] Idle mode activated - minimal background recovery only")
    }
    
    
    private func cancelAllRecoveryTasks(reason: String) {
        print("🛑 [Recovery] Canceling all recovery tasks: \(reason)")
        for priority in [ErrorPriority.trainingCritical, .trainingEnhancing, .background] {
            cancelRecoveryTasks(for: priority, reason: reason)
        }
    }
    
    private func cancelRecoveryTasks(for priority: ErrorPriority, reason: String) {
        let tasksToCancel = activeRecoveryTasks[priority] ?? [:]
        
        for (operation, task) in tasksToCancel {
            print("🚫 [Recovery] Canceling \(priority) recovery for \(operation): \(reason)")
            task.cancel()
        }
        
        activeRecoveryTasks[priority] = [:]
    }
    
    /// NEW: Training-state-aware error handling with resource limits
    func handleErrorWithDecision(_ error: SpotifyRecoverableError, context: ErrorContext) {
        let decision = errorHandler.shouldRecover(from: error, context: context)
        
        print("🔍 [Recovery] \(decision.reasoning)")
        
        // Check resource limits before attempting recovery
        let currentCount = activeRecoveryTasks[decision.priority]?.count ?? 0
        let maxAllowed = recoveryLimits[decision.priority] ?? 1
        
        guard currentCount < maxAllowed else {
            print("🚫 [Recovery] Resource limit reached for \(decision.priority) (\(currentCount)/\(maxAllowed))")
            print("🔄 [Recovery] Applying fallback: \(decision.fallbackStrategy)")
            applyFallbackStrategy(decision.fallbackStrategy, error: error, context: context)
            return
        }
        
        // Training-state-aware decision making
        guard decision.shouldRetry && shouldExecuteRecovery(for: decision.priority) else {
            print("ℹ️ [Recovery] Not retrying \(context.operation) - \(decision.shouldRetry ? "training state mismatch" : "max attempts reached")")
            applyFallbackStrategy(decision.fallbackStrategy, error: error, context: context)
            return
        }
        
        // Schedule resource-managed recovery
        scheduleRecovery(decision, operation: context.operation)
    }
    
    private func shouldExecuteRecovery(for priority: ErrorPriority) -> Bool {
        let intent = getCurrentIntent()
        
        switch (priority, intent) {
        case (.trainingCritical, .training):
            return true  // Always recover critical training failures
            
        case (.trainingEnhancing, .training):
            return true  // Recover training enhancements during active training
            
        case (.background, .idle):
            return true  // Background maintenance when idle
            
        case (_, .disconnected):
            return false // Never recover when explicitly disconnected
            
        default:
            // All other combinations should not trigger recovery
            return false
        }
    }
    
    private func scheduleRecovery(_ decision: ErrorRecoveryDecision, operation: String) {
        let taskKey = "\(operation)-\(Date().timeIntervalSince1970)"
        
        let recoveryTask = Task {
            // Wait for suggested delay
            if decision.suggestedDelay > 0 {
                try? await Task.sleep(nanoseconds: UInt64(decision.suggestedDelay * 1_000_000_000))
            }
            
            // Double-check training state before executing (could have changed during delay)
            guard shouldExecuteRecovery(for: decision.priority) else {
                print("ℹ️ [Recovery] Training state changed during delay - canceling \(operation)")
                return
            }
            
            // Double-check if we were canceled
            guard !Task.isCancelled else {
                print("ℹ️ [Recovery] Task was canceled during delay - \(operation)")
                return
            }
            
            print("🔄 [Recovery] Executing \(decision.priority) recovery for \(operation)")
            await executeRecoveryAction(for: operation, priority: decision.priority)
            
            // Clean up task reference
            activeRecoveryTasks[decision.priority]?[taskKey] = nil
        }
        
        // Store task for potential cancellation
        activeRecoveryTasks[decision.priority]?[taskKey] = recoveryTask
        print("📋 [Recovery] Scheduled \(decision.priority) recovery for \(operation) (delay: \(decision.suggestedDelay)s)")
    }
    
    private func executeRecoveryAction(for operation: String, priority: ErrorPriority) async {
        // Route to appropriate recovery method based on operation type
        switch operation {
        case "AppRemote Connection":
            attemptAppRemoteReconnection()
        case "Track Fetch", "Current Track":
            refreshCurrentTrack()
        case "Playlist Fetch":
            // Could trigger playlist refresh
            break
        default:
            print("⚠️ [Recovery] Unknown recovery operation: \(operation)")
        }
    }
    
    private func applyFallbackStrategy(_ strategy: FallbackStrategy, error: SpotifyRecoverableError, context: ErrorContext) {
        switch strategy {
        case .degradeToWebAPI:
            print("🔄 [Fallback] Degrading to Web API for \(context.operation)")
            if context.operation.contains("Track") {
                fetchCurrentTrackViaWebAPI()
            }
            
        case .continueWithoutData:
            print("ℹ️ [Fallback] Continuing without data for \(context.operation)")
            // Already handled by not retrying
            
        case .notifyUser:
            print("📢 [Fallback] Notifying user about \(context.operation) failure")
            DispatchQueue.main.async { [weak self] in
                // Show error through ErrorHandler UI state 
                self?.errorHandler.currentError = error
                self?.errorHandler.recoveryMessage = error.recoveryMessage
            }
            
        case .silentFailure:
            print("🔇 [Fallback] Silent failure for \(context.operation)")
            // Just log and continue
        }
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
        
        guard accessToken != nil else {
            print("❌ No access token available for fast retry")
            isFetchingFreshData = false
            return
        }
        
        let currentlyPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: currentlyPlayingURL)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        let requestTimestamp = Date()
        print("🔄 Fast retry \(attempt)/\(maxAttempts) (300ms intervals)")
        
        makeAuthenticatedAPICall(request: request) { [weak self] data, response, error in
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
        }
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
                print("❌ Unauthorized - access token expired, attempting refresh")
                // Use new training-state-aware error recovery system
                let recoverableError = SpotifyRecoverableError.tokenExpired
                let context = ErrorContext(
                    operation: "Track Fetch",
                    attemptNumber: attempt,
                    lastSuccessTime: nil,
                    connectionState: self.connectionManager.connectionState,
                    currentIntent: self.getCurrentIntent()
                )
                
                self.handleErrorWithDecision(recoverableError, context: context)
                
                // For token expiration, always attempt refresh regardless of training state
                if true { // Token refresh is always needed
                    if let refreshToken = self.retrieveStoredRefreshToken() {
                        self.refreshAccessToken(refreshToken: refreshToken) { [weak self] success in
                            if success {
                                // Token refreshed, retry the request
                                self?.fetchCurrentTrackViaWebAPIWithRetry(attempt: attempt + 1, maxAttempts: maxAttempts, isInitialWorkoutFetch: isInitialWorkoutFetch)
                            } else {
                                // Refresh failed, stop trying
                                self?.isFetchingFreshData = false
                                self?.handleTokenExpired()
                            }
                        }
                    } else {
                        self.isFetchingFreshData = false
                        self.handleTokenExpired()
                    }
                } else {
                    self.isFetchingFreshData = false
                    self.handleTokenExpired()
                }
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
    
    /// Enhanced retry mechanism using structured error recovery
    private func fetchCurrentTrackWithRecovery(operation: String, completion: @escaping (Result<Void, SpotifyRecoverableError>) -> Void) {
        let context = ErrorContext(
            operation: operation,
            attemptNumber: (errorHandler.debugInfo.contains(operation) ? 1 : 0) + 1,
            lastSuccessTime: nil, // Could track this in the future
            connectionState: connectionManager.connectionState,
            currentIntent: self.getCurrentIntent() // Use instance variable instead of parameter
        )
        
        performTrackFetchWithContext(context: context, completion: completion)
    }
    
    private func performTrackFetchWithContext(context: ErrorContext, completion: @escaping (Result<Void, SpotifyRecoverableError>) -> Void) {
        guard let accessToken = accessToken else {
            let error = SpotifyRecoverableError.tokenExpired
            handleRecoverableError(error, context: context, completion: completion)
            return
        }
        
        let currentlyPlayingURL = URL(string: "https://api.spotify.com/v1/me/player/currently-playing")!
        var request = URLRequest(url: currentlyPlayingURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        request.timeoutInterval = 10.0 // Reasonable timeout
        
        print("🔄 [Enhanced] \(context.operation) attempt \(context.attemptNumber)")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            // Handle network errors
            if let error = error {
                let recoverableError = SpotifyErrorHandler.convertLegacyError(error, operation: context.operation)
                self.handleRecoverableError(recoverableError, context: context, completion: completion)
                return
            }
            
            // Handle HTTP response errors
            if let httpResponse = response as? HTTPURLResponse {
                if let recoverableError = self.handleHTTPResponse(httpResponse, data: data, context: context) {
                    self.handleRecoverableError(recoverableError, context: context, completion: completion)
                    return
                }
            }
            
            // Handle successful response
            if let data = data, !data.isEmpty {
                let responseTimestamp = Date()
                self.parseCurrentlyPlayingResponseWithDebug(data, requestTimestamp: Date(), responseTimestamp: responseTimestamp)
                self.errorHandler.recordSuccess(for: context.operation)
                completion(.success(()))
            } else {
                let error = SpotifyRecoverableError.noData(operation: context.operation)
                self.handleRecoverableError(error, context: context, completion: completion)
            }
        }.resume()
    }
    
    private func handleHTTPResponse(_ response: HTTPURLResponse, data: Data?, context: ErrorContext) -> SpotifyRecoverableError? {
        switch response.statusCode {
        case 200...299:
            return nil // Success
        case 401:
            return .tokenExpired
        case 403:
            return .insufficientPermissions
        case 429:
            // Extract retry-after header if available
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After").flatMap(Double.init)
            return .rateLimited(retryAfter: retryAfter)
        case 500...599:
            return .serviceUnavailable
        default:
            let message = data.flatMap { String(data: $0, encoding: .utf8) }
            return .apiError(code: response.statusCode, message: message)
        }
    }
    
    private func handleRecoverableError(_ error: SpotifyRecoverableError, context: ErrorContext, completion: @escaping (Result<Void, SpotifyRecoverableError>) -> Void) {
        // Use new training-state-aware error recovery system
        handleErrorWithDecision(error, context: context)
        
        // For compatibility, get decision to determine if we should retry
        let decision = errorHandler.shouldRecover(from: error, context: context)
        let recoveryAction: ErrorRecoveryAction = decision.shouldRetry ? .retryAfterDelay(decision.suggestedDelay) : .noAction
        
        switch recoveryAction {
        case .retryAfterDelay, .retryWithExponentialBackoff:
            errorHandler.executeRecovery(recoveryAction, for: context.operation) { [weak self] in
                // Retry with incremented attempt number
                let newContext = ErrorContext(
                    operation: context.operation,
                    attemptNumber: context.attemptNumber + 1,
                    lastSuccessTime: context.lastSuccessTime,
                    connectionState: context.connectionState,
                    currentIntent: context.currentIntent
                )
                self?.performTrackFetchWithContext(context: newContext, completion: completion)
            }
            
        case .refreshToken:
            // Trigger token refresh using stored refresh token
            print("🔄 [Recovery] Token refresh needed - attempting automatic refresh")
            if let refreshToken = retrieveStoredRefreshToken() {
                refreshAccessToken(refreshToken: refreshToken) { success in
                    if success {
                        print("✅ [Recovery] Token refreshed successfully - retrying original request")
                        completion(.success(()))
                    } else {
                        print("❌ [Recovery] Token refresh failed - authentication required")
                        completion(.failure(error))
                    }
                }
            } else {
                print("❌ [Recovery] No refresh token available - authentication required")
                completion(.failure(error))
            }
            
        case .degradeToWebAPIOnly:
            print("🔄 [Recovery] Degrading to Web API only mode")
            // Could set a flag to disable AppRemote attempts
            completion(.failure(error))
            
        case .showUserErrorMessage, .showUserAuthPrompt:
            completion(.failure(error))
            
        case .noAction:
            completion(.failure(error))
            
        default:
            completion(.failure(error))
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
        
        AppLogger.debug("Starting Web API track fetch (\(fetchType))", component: "WebAPI")
        AppLogger.verbose("Endpoint: \(currentlyPlayingURL.absoluteString)", component: "WebAPI")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            
            let responseTimestamp = Date()
            let requestDuration = responseTimestamp.timeIntervalSince(requestTimestamp)
            
            AppLogger.debug("Response received after \(String(format: "%.3f", requestDuration))s", component: "WebAPI")
            
            if let error = error {
                AppLogger.error("Network error: \(error)", component: "WebAPI")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                AppLogger.error("Invalid response from currently-playing API", component: "WebAPI")
                return
            }
            
            AppLogger.apiResponse("Currently-playing API response", statusCode: httpResponse.statusCode, dataSize: data?.count, component: "WebAPI")
            for (key, value) in httpResponse.allHeaderFields {
                print("  \(key): \(value)")
            }
            
            switch httpResponse.statusCode {
            case 200:
                if let data = data {
                    AppLogger.debug("Response data size: \(data.count) bytes", component: "WebAPI")
                    self.parseCurrentlyPlayingResponseWithDebug(data, requestTimestamp: requestTimestamp, responseTimestamp: responseTimestamp)
                } else {
                    AppLogger.warn("No data in currently-playing response", component: "WebAPI")
                }
            case 204:
                AppLogger.info("No music currently playing (204 response)", component: "WebAPI")
                self.notifyPlayerStateChange(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
            case 401:
                AppLogger.warn("Unauthorized - access token expired, attempting refresh", component: "WebAPI")
                // Use new training-state-aware error recovery system
                let recoverableError = SpotifyRecoverableError.tokenExpired
                let context = ErrorContext(
                    operation: "Current Track",
                    attemptNumber: 1,
                    lastSuccessTime: nil,
                    connectionState: self.connectionManager.connectionState,
                    currentIntent: self.getCurrentIntent()
                )
                
                self.handleErrorWithDecision(recoverableError, context: context)
                
                // For token expiration, always attempt refresh regardless of training state
                if true { // Token refresh is always needed
                    if let refreshToken = self.retrieveStoredRefreshToken() {
                        self.refreshAccessToken(refreshToken: refreshToken) { [weak self] success in
                            if success {
                                // Token refreshed, retry current track request
                                self?.fetchCurrentTrackViaWebAPI()
                            } else {
                                // Refresh failed
                                self?.handleTokenExpired()
                            }
                        }
                    } else {
                        self.handleTokenExpired()
                    }
                } else {
                    self.handleTokenExpired()
                }
            case 429:
                AppLogger.warn("Rate limited - will retry later", component: "WebAPI")
            default:
                AppLogger.error("API Error - Status: \(httpResponse.statusCode)", component: "WebAPI")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    AppLogger.error("Error response body: \(errorString)", component: "WebAPI")
                }
            }
        }.resume()
    }
    
    private func parseCurrentlyPlayingResponseWithDebug(_ data: Data, requestTimestamp: Date, responseTimestamp: Date) {
        do {
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                // Log complete JSON only at verbose level for debugging
                AppLogger.verbose("Complete API Response JSON: \(String(data: try! JSONSerialization.data(withJSONObject: json), encoding: .utf8) ?? "N/A")", component: "WebAPI")
                
                // Extract timing information
                let timestamp = json["timestamp"] as? Int64
                let progressMs = json["progress_ms"] as? Int
                let isPlaying = json["is_playing"] as? Bool ?? false
                
                AppLogger.debug("Playback state: \(isPlaying ? "▶️" : "⏸️") Progress: \(progressMs ?? -1)ms", component: "WebAPI")
                
                // Extract device information
                if let device = json["device"] as? [String: Any] {
                    let deviceId = device["id"] as? String ?? ""
                    let deviceName = device["name"] as? String ?? ""
                    let deviceType = device["type"] as? String ?? ""
                    let isActive = device["is_active"] as? Bool ?? false
                    let isPrivateSession = device["is_private_session"] as? Bool ?? false
                    let isRestricted = device["is_restricted"] as? Bool ?? false
                    let volumePercent = device["volume_percent"] as? Int ?? -1
                    
                    AppLogger.debug("Device: \(deviceName) (\(deviceType)) Active: \(isActive) Vol: \(volumePercent)%", component: "WebAPI")
                }
                
                // Extract context information
                if let context = json["context"] as? [String: Any] {
                    let contextType = context["type"] as? String ?? ""
                    let contextUri = context["uri"] as? String ?? ""
                    let externalUrls = context["external_urls"] as? [String: Any]
                    let spotifyUrl = externalUrls?["spotify"] as? String ?? ""
                    
                    AppLogger.debug("Context: \(contextType) URI: \(contextUri)", component: "WebAPI")
                }
                
                if let item = json["item"] as? [String: Any] {
                    let trackName = item["name"] as? String ?? ""
                    let trackId = item["id"] as? String ?? ""
                    let trackUri = item["uri"] as? String ?? ""
                    let durationMs = item["duration_ms"] as? Int ?? 0
                    let popularity = item["popularity"] as? Int ?? 0
                    let explicit = item["explicit"] as? Bool ?? false
                    
                    AppLogger.debug("Track: '\(trackName)' Duration: \(durationMs)ms", component: "WebAPI")
                    
                    // Get artist name(s) with detailed info
                    var artistName = ""
                    if let artists = item["artists"] as? [[String: Any]], !artists.isEmpty {
                        let artistNames = artists.compactMap { $0["name"] as? String }
                        AppLogger.debug("Artists: \(artistNames.joined(separator: ", "))", component: "WebAPI")
                        artistName = artistNames.joined(separator: ", ")
                    }
                    
                    // Get album info with detailed logging
                    var artworkURL = ""
                    if let album = item["album"] as? [String: Any] {
                        let albumName = album["name"] as? String ?? ""
                        let albumId = album["id"] as? String ?? ""
                        let albumType = album["album_type"] as? String ?? ""
                        let releaseDate = album["release_date"] as? String ?? ""
                        
                        AppLogger.debug("Album: '\(albumName)' (\(albumType)) Released: \(releaseDate)", component: "WebAPI")
                        
                        if let images = album["images"] as? [[String: Any]], !images.isEmpty {
                            AppLogger.verbose("Album has \(images.count) artwork images available", component: "WebAPI")
                            
                            // Get the smallest image (usually 64x64) for efficiency
                            let sortedImages = images.sorted { (img1, img2) in
                                let height1 = img1["height"] as? Int ?? 0
                                let height2 = img2["height"] as? Int ?? 0
                                return height1 < height2
                            }
                            artworkURL = sortedImages.first?["url"] as? String ?? ""
                            AppLogger.debug("Selected artwork URL: \(artworkURL)", component: "WebAPI")
                        }
                    }
                    
                    // Timing analysis
                    let timeSinceRequest = Date().timeIntervalSince(requestTimestamp)
                    let timeSinceResponse = Date().timeIntervalSince(responseTimestamp)
                    
                    AppLogger.verbose("Timing: Request took \(String(format: "%.3f", timeSinceRequest))s, processed in \(String(format: "%.3f", timeSinceResponse))s", component: "WebAPI")
                    
                    AppLogger.playerState("WebAPI parsed track data", trackName: trackName, artist: artistName, isPlaying: isPlaying, component: "WebAPI")
                    
                    // Track the last fetched track for stale data detection
                    self.lastFetchedTrackName = trackName
                    
                    // Ensure artwork URL is in displayable format
                    let displayableArtworkURL = self.convertToDisplayableImageURL(artworkURL)
                    
                    // Check data source prioritization before updating UI
                    self.handleWebAPITrackData(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: displayableArtworkURL)
                } else {
                    AppLogger.debug("No track item in currently-playing response", component: "WebAPI")
                    // Only update UI with "no music" if AppRemote is not providing data
                    self.handleWebAPITrackData(isPlaying: false, trackName: "", artistName: "", artworkURL: "")
                }
            }
        } catch {
            AppLogger.error("Error parsing currently-playing response: \(error)", component: "WebAPI")
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
        // Only connect if we're not already connected
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
        
        // Prevent duplicate reconnection attempts
        if isAppRemoteConnectionInProgress {
            print("⏳ AppRemote reconnection already in progress")
            return
        }
        
        if appRemote.isConnected {
            print("✅ AppRemote already connected, no need to reconnect")
            return
        }
        
        print("🔄 [Reconnection] Attempting AppRemote reconnection...")
        isAppRemoteConnectionInProgress = true
        appRemote.delegate = self
        appRemote.connect()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if appRemote.isConnected {
                print("✅ Successfully reconnected AppRemote")
            } else {
                print("ℹ️ AppRemote reconnection failed - Web API fallback available")
                self.isAppRemoteConnectionInProgress = false
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
        guard accessToken != nil else { 
            print("❌ [Background] No access token for playlist switch")
            return 
        }
        
        var bgTask: UIBackgroundTaskIdentifier = .invalid
        let playlistType = isHighIntensity ? "HighIntensity" : "Rest"
        let taskName = "PlaylistSwitch_\(playlistType)_\(Date().timeIntervalSince1970)"
        
        print("📱 [Background] Starting background task: \(taskName)")
        bgTask = UIApplication.shared.beginBackgroundTask(withName: taskName) { 
            print("⏰ [Background] Background task \(taskName) expired - cleaning up")
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        guard bgTask != .invalid else {
            print("❌ [Background] Failed to start background task for playlist switch")
            return
        }
        
        // Use longer timeout for background playlist switches
        let timeoutDelay: TimeInterval = 15.0
        let timeoutTimer = Timer.scheduledTimer(withTimeInterval: timeoutDelay, repeats: false) { _ in
            print("⏰ [Background] Playlist switch timeout after \(timeoutDelay)s")
            if bgTask != .invalid {
                UIApplication.shared.endBackgroundTask(bgTask)
                bgTask = .invalid
            }
        }
        
        activateIPhoneDeviceForPlayback { [weak self] success in
            defer {
                timeoutTimer.invalidate()
                if bgTask != .invalid {
                    print("✅ [Background] Completing background task: \(taskName)")
                    UIApplication.shared.endBackgroundTask(bgTask)
                    bgTask = .invalid
                }
            }
            
            guard let self = self else { return }
            
            if success {
                let playlistName = isHighIntensity ? "High Intensity Playlist" : "Rest Playlist"
                print("🎵 [Background] Switching to \(playlistName) via Web API")
                self.playPlaylistViaWebAPI(playlistID: playlistID, playlistName: playlistName)
            } else {
                print("📱 [Background] Device activation failed - playlist switch skipped")
                // In background, this is expected behavior, not an error
            }
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
            
            AppLogger.rateLimited(.debug, message: "Spotify identifier → URL: \(artworkString) → \(convertedURL)", key: "image_convert_\(hash)", component: "ImageConvert")
            
            return convertedURL
        } else if artworkString.hasPrefix("https://") || artworkString.hasPrefix("http://") {
            // Already a full URL - return as-is
            AppLogger.rateLimited(.debug, message: "Already a URL: \(artworkString)", key: "image_already_url", component: "ImageConvert")
            return artworkString
        } else {
            // Assume it's just a hash without prefix (AppRemote sometimes provides just the hash)
            let convertedURL = "https://i.scdn.co/image/\(artworkString)"
            
            AppLogger.rateLimited(.debug, message: "Hash → URL: \(artworkString) → \(convertedURL)", key: "image_convert_hash_\(artworkString)", component: "ImageConvert")
            
            return convertedURL
        }
    }
    
    // MARK: - Data Source Prioritization
    
    private func handleWebAPITrackData(isPlaying: Bool, trackName: String, artistName: String, artworkURL: String, duration: TimeInterval = 0, position: TimeInterval = 0, uri: String = "") {
        // Always update data coordinator with Web API data - it will handle prioritization
        dataCoordinator.updateFromWebAPI(
            name: trackName,
            artist: artistName,
            uri: uri,
            artworkURL: artworkURL,
            duration: duration,
            position: position,
            isPlaying: isPlaying
        )
        
        let currentTime = Date()
        let timeSinceAppRemote = currentTime.timeIntervalSince(lastAppRemoteUpdate)
        
        // Only use Web API data for legacy notification if:
        // 1. No AppRemote data has been received, OR
        // 2. AppRemote data is older than 30 seconds (connection likely lost)
        let shouldUseWebAPIData = currentDataSource == .none || timeSinceAppRemote > 30.0
        
        if shouldUseWebAPIData {
            print("✅ [DATA SOURCE] Using Web API data for legacy notifications (AppRemote unavailable or stale)")
            print("  - Data source priority: Web API (fallback)")
            print("  - Time since AppRemote: \(String(format: "%.1f", timeSinceAppRemote))s")
            
            currentDataSource = .webAPI
            notifyPlayerStateChange(isPlaying: isPlaying, trackName: trackName, artistName: artistName, artworkURL: artworkURL)
        } else {
            print("📊 [DATA SOURCE] Web API data sent to coordinator but not used for legacy notifications")
            print("  - Data coordinator will prioritize AppRemote data")
            print("  - Time since AppRemote: \(String(format: "%.1f", timeSinceAppRemote))s")
        }
    }
    
    private func notifyPlayerStateChange(isPlaying: Bool, trackName: String, artistName: String = "", artworkURL: String = "") {
        AppLogger.playerState("Player state change", trackName: trackName, artist: artistName, isPlaying: isPlaying, component: "Spotify")
        
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
        guard accessToken != nil else { return }
        
        let playURL = URL(string: "https://api.spotify.com/v1/me/player/play")!
        var request = URLRequest(url: playURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["context_uri": "spotify:playlist:\(playlistID)"]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        print("Attempting to start \(playlistName) via Web API...")
        
        makeAuthenticatedAPICall(request: request) { [weak self] data, response, error in
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
        }
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
            print("🔄 [URLScheme] Opening Spotify via URL scheme - setting automatic activation flag")
            isAutomaticSpotifyActivationInProgress = true
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
        
        // Store both access token and refresh token in keychain for future use
        storeAuthenticationTokens(session: session)
        
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
        
        // Update stored tokens with renewed ones
        storeAuthenticationTokens(session: session)
        
        // Update connection manager with new token
        connectionManager.authenticationSucceeded(token: session.accessToken)
    }
}

// MARK: - SPTAppRemoteDelegate  
extension SpotifyService: SPTAppRemoteDelegate {
    func appRemoteDidEstablishConnection(_ appRemote: SPTAppRemote) {
        print("🎵 AppRemote: Connected successfully! Device is now active.")
        isAppRemoteConnectionInProgress = false // Reset connection flag
        connectionManager.appRemoteConnectionSucceeded()
        appRemote.playerAPI?.delegate = self
        
        // Only subscribe once - prevent duplicate subscriptions
        if appRemoteSubscriptionID == nil {
            appRemote.playerAPI?.subscribe(toPlayerState: { [weak self] (result, error) in
                if let error = error {
                    AppLogger.error("Error subscribing to player state: \(error)", component: "Spotify")
                } else {
                    AppLogger.info("Successfully subscribed to player state updates", component: "Spotify")
                    // Store subscription ID to prevent duplicates
                    self?.appRemoteSubscriptionID = result
                }
            })
        } else {
            AppLogger.debug("Already subscribed to player state, skipping duplicate subscription", component: "Spotify")
        }
        
        // Also get current player state immediately
        appRemote.playerAPI?.getPlayerState { (playerState, error) in
            if let error = error {
                AppLogger.error("Error getting initial player state: \(error)", component: "Spotify")
            } else if let playerState = playerState as? SPTAppRemotePlayerState {
                AppLogger.debug("Got initial player state", component: "Spotify")
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
        isAppRemoteConnectionInProgress = false // Reset connection flag
        
        // Use new training-state-aware error handling for AppRemote connection failures
        let recoverableError = SpotifyRecoverableError.appRemoteConnectionFailed(underlying: error)
        let context = ErrorContext(
            operation: "AppRemote Connection",
            attemptNumber: 1,
            lastSuccessTime: nil,
            connectionState: connectionManager.connectionState,
            currentIntent: self.getCurrentIntent()
        )
        
        // This will respect training state and only retry if appropriate
        handleErrorWithDecision(recoverableError, context: context)
        
        let connectionError = error ?? SpotifyConnectionError.appRemoteConnectionTimeout
        connectionManager.appRemoteConnectionFailed(error: connectionError)
    }
    
    func appRemote(_ appRemote: SPTAppRemote, didDisconnectWithError error: Error?) {
        print("AppRemote: Disconnected with error: \(error?.localizedDescription ?? "No error")")
        isAppRemoteConnectionInProgress = false // Reset connection flag
        appRemoteSubscriptionID = nil // Clear subscription ID for next connection
        
        // Use enhanced error handling for AppRemote disconnection
        if let error = error {
            let recoverableError = SpotifyRecoverableError.appRemoteDisconnected(underlying: error)
            let context = ErrorContext(
                operation: "AppRemote Connection",
                attemptNumber: 1,
                lastSuccessTime: nil,
                connectionState: connectionManager.connectionState,
                currentIntent: self.getCurrentIntent()
            )
            
            // Use new training-state-aware error handling 
            handleErrorWithDecision(recoverableError, context: context)
        }
        
        // Clear AppRemote data from coordinator
        dataCoordinator.clearDataSource(.appRemote)
        
        // Reset legacy data source tracking when AppRemote disconnects
        print("🔄 [DATA SOURCE] AppRemote disconnected - allowing Web API fallback")
        currentDataSource = .none
        lastAppRemoteUpdate = Date.distantPast
        
        connectionManager.appRemoteDisconnected(error: error)
    }
    
    /// Handles recovery actions specific to AppRemote errors
    private func handleAppRemoteRecovery(_ action: ErrorRecoveryAction, error: Error?) {
        switch action {
        case .reconnectAppRemote:
            print("🔄 [Recovery] Attempting AppRemote reconnection...")
            errorHandler.executeRecovery(action, for: "AppRemote Connection") { [weak self] in
                self?.attemptAppRemoteReconnection()
            }
            
        case .degradeToWebAPIOnly:
            print("🔄 [Recovery] Switching to Web API only mode")
            // Could set a flag to prevent future AppRemote attempts during this session
            
        case .retryAfterDelay, .retryWithExponentialBackoff:
            errorHandler.executeRecovery(action, for: "AppRemote Connection") { [weak self] in
                print("🔄 [Recovery] Retrying AppRemote connection after delay")
                self?.attemptAppRemoteReconnection()
            }
            
        default:
            print("🔄 [Recovery] No automatic recovery for AppRemote error: \(action)")
        }
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
        
        // Log detailed track info only at verbose level
        AppLogger.verbose("AppRemote player state: \(trackName) - \(artistName) [\(isPlaying ? "▶️" : "⏸️")] URI: \(trackURI)", component: "Spotify")
        
        // Use specialized player state logging for track changes
        AppLogger.playerState("AppRemote update", trackName: trackName, artist: artistName, isPlaying: isPlaying, component: "Spotify")
        
        // AppRemote data is always prioritized as the authoritative source
        // Update data coordinator with AppRemote data
        dataCoordinator.updateFromAppRemote(
            name: trackName,
            artist: artistName,
            uri: trackURI,
            artworkURL: artworkURL,
            duration: Double(duration) / 1000.0, // Convert from ms to seconds
            position: Double(playbackPosition) / 1000.0, // Convert from ms to seconds
            isPlaying: isPlaying
        )
        
        // Update legacy data source tracking
        currentDataSource = .appRemote
        lastAppRemoteUpdate = Date()
        
        print("✅ [DATA SOURCE] AppRemote data received - updating data coordinator")
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpMethod = "GET"
        
        print("🎵 Fetching user playlists from Spotify Web API...")
        print("🔑 Using access token: \(accessToken.prefix(20))...")
        
        makeAuthenticatedAPICall(request: request) { [weak self] data, response, error in
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
                    print("❌ Unauthorized - access token expired or invalid, attempting refresh")
                    // Use error recovery system for token refresh
                    let recoverableError = SpotifyRecoverableError.tokenExpired
                    let context = ErrorContext(
                        operation: "Playlist Fetch",
                        attemptNumber: 1,
                        lastSuccessTime: nil,
                        connectionState: self?.connectionManager.connectionState ?? .disconnected,
                        currentIntent: self?.getCurrentIntent() ?? .idle
                    )
                    
                    // Use new training-state-aware error recovery system
                    self?.handleErrorWithDecision(recoverableError, context: context)
                    
                    // For token expiration, always attempt refresh regardless of training state
                    if true { // Token refresh is always needed
                        if let refreshToken = self?.retrieveStoredRefreshToken() {
                            self?.refreshAccessToken(refreshToken: refreshToken) { [weak self] success in
                                if success {
                                    // Token refreshed, retry playlist request
                                    self?.fetchUserPlaylists(completion: completion)
                                } else {
                                    // Refresh failed
                                    self?.handleTokenExpired()
                                    completion(.failure(SpotifyError.tokenExpired))
                                }
                            }
                        } else {
                            self?.handleTokenExpired()
                            completion(.failure(SpotifyError.tokenExpired))
                        }
                    } else {
                        self?.handleTokenExpired()
                        completion(.failure(SpotifyError.tokenExpired))
                    }
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
        }
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
