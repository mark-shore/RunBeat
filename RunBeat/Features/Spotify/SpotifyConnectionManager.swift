//
//  SpotifyConnectionManager.swift
//  RunBeat
//
//  Unified connection state management for Spotify integration
//  Replaces multiple boolean flags with a single source of truth
//

import Foundation
import Combine
import UIKit

/// Unified Spotify connection state representing both authentication and connection layers
enum SpotifyConnectionState: Equatable {
    // Disconnected states
    case disconnected                           // Not authenticated, not connected
    case authenticating                         // OAuth flow in progress
    case authenticationFailed(Error)           // OAuth failed
    
    // Authenticated states  
    case authenticated(token: String)          // Has valid token, AppRemote not connected
    case connecting(token: String)             // AppRemote connection attempt in progress
    case connected(token: String)              // Fully connected (auth + AppRemote)
    case connectionError(token: String, Error) // AppRemote failed but auth still valid
    
    // MARK: - State Properties
    
    /// Whether we have a valid authentication token
    var isAuthenticated: Bool {
        switch self {
        case .disconnected, .authenticating, .authenticationFailed:
            return false
        case .authenticated, .connecting, .connected, .connectionError:
            return true
        }
    }
    
    /// Whether AppRemote is connected for real-time control
    var isAppRemoteConnected: Bool {
        switch self {
        case .connected:
            return true
        default:
            return false
        }
    }
    
    /// Whether the connection is fully ready for use
    var isFullyConnected: Bool {
        return isAppRemoteConnected
    }
    
    /// Whether we can make Web API calls
    var canUseWebAPI: Bool {
        return isAuthenticated
    }
    
    /// The current access token, if available
    var accessToken: String? {
        switch self {
        case .authenticated(let token), .connecting(let token), .connected(let token), .connectionError(let token, _):
            return token
        default:
            return nil
        }
    }
    
    /// User-friendly status message
    var statusMessage: String {
        switch self {
        case .disconnected:
            return "Not connected"
        case .authenticating:
            return "Authenticating with Spotify..."
        case .authenticationFailed(let error):
            return "Authentication failed: \(error.localizedDescription)"
        case .authenticated:
            return "Authenticated - connecting..."
        case .connecting:
            return "Connecting to Spotify..."
        case .connected:
            return "Connected to Spotify"
        case .connectionError(_, let error):
            return "Connection issue: \(error.localizedDescription)"
        }
    }
    
    /// Whether the state represents an error condition
    var isError: Bool {
        switch self {
        case .authenticationFailed, .connectionError:
            return true
        default:
            return false
        }
    }
    
    /// Whether a connection attempt is in progress
    var isConnecting: Bool {
        switch self {
        case .authenticating, .connecting:
            return true
        default:
            return false
        }
    }
    
    // MARK: - Equatable
    
    static func == (lhs: SpotifyConnectionState, rhs: SpotifyConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected):
            return true
        case (.authenticating, .authenticating):
            return true
        case (.authenticationFailed(let lhsError), .authenticationFailed(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.authenticated(let lhsToken), .authenticated(let rhsToken)):
            return lhsToken == rhsToken
        case (.connecting(let lhsToken), .connecting(let rhsToken)):
            return lhsToken == rhsToken
        case (.connected(let lhsToken), .connected(let rhsToken)):
            return lhsToken == rhsToken
        case (.connectionError(let lhsToken, let lhsError), .connectionError(let rhsToken, let rhsError)):
            return lhsToken == rhsToken && lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

/// Manages unified Spotify connection state with proper state transitions
class SpotifyConnectionManager: ObservableObject {
    
    @Published private(set) var connectionState: SpotifyConnectionState = .disconnected
    
    // MARK: - State Transitions
    
    func startAuthentication() {
        print("🔄 [ConnectionManager] Starting authentication...")
        connectionState = .authenticating
    }
    
    func authenticationSucceeded(token: String) {
        print("✅ [ConnectionManager] Authentication succeeded")
        connectionState = .authenticated(token: token)
    }
    
    func authenticationFailed(error: Error) {
        print("❌ [ConnectionManager] Authentication failed: \(error.localizedDescription)")
        connectionState = .authenticationFailed(error)
    }
    
    func startAppRemoteConnection() {
        // Handle starting AppRemote connection based on current state
        switch connectionState {
        case .authenticated(let token):
            // Normal case - authenticated and ready to connect
            print("🔄 [ConnectionManager] Starting AppRemote connection...")
            connectionState = .connecting(token: token)
            
        case .connectionError(let token, _):
            // Retry from error state
            print("🔄 [ConnectionManager] Retrying AppRemote connection from error state...")
            connectionState = .connecting(token: token)
            
        case .connecting:
            // Already in connecting state - this might be a duplicate call
            print("ℹ️ [ConnectionManager] AppRemote connection already in progress")
            
        case .connected:
            // Already connected - no need to start again
            print("ℹ️ [ConnectionManager] AppRemote already connected")
            
        default:
            print("⚠️ [ConnectionManager] Cannot start AppRemote connection - not authenticated (current state: \(connectionState))")
        }
    }
    
    /// Starts AppRemote connection with explicit token, bypassing state checks
    func startAppRemoteConnectionWithToken(_ token: String) {
        print("🔄 [ConnectionManager] Starting AppRemote connection with explicit token")
        connectionState = .connecting(token: token)
    }
    
    func appRemoteConnectionSucceeded() {
        // Handle AppRemote connection success based on current state
        switch connectionState {
        case .connecting(let token):
            // Normal case - we were in connecting state
            print("✅ [ConnectionManager] AppRemote connection succeeded")
            connectionState = .connected(token: token)
            
        case .authenticated(let token):
            // AppRemote connected while we were still in authenticated state
            // This can happen if connection is very fast
            print("✅ [ConnectionManager] AppRemote connection succeeded (fast connection)")
            connectionState = .connected(token: token)
            
        case .connectionError(let token, _):
            // Recovered from a previous connection error
            print("✅ [ConnectionManager] AppRemote connection succeeded (recovered from error)")
            connectionState = .connected(token: token)
            
        case .connected:
            // Already connected - this might be a duplicate event
            print("ℹ️ [ConnectionManager] AppRemote connection event received but already connected")
            
        default:
            // Unexpected state - log warning but try to handle gracefully
            print("⚠️ [ConnectionManager] AppRemote success but in unexpected state: \(connectionState)")
            if let token = connectionState.accessToken {
                print("ℹ️ [ConnectionManager] Updating to connected state with available token")
                connectionState = .connected(token: token)
            }
        }
    }
    
    func appRemoteConnectionFailed(error: Error) {
        guard let token = connectionState.accessToken else {
            print("⚠️ [ConnectionManager] AppRemote failed but no token available")
            connectionState = .disconnected
            return
        }
        print("❌ [ConnectionManager] AppRemote connection failed: \(error.localizedDescription)")
        connectionState = .connectionError(token: token, error)
    }
    
    func appRemoteDisconnected(error: Error?) {
        guard let token = connectionState.accessToken else {
            print("ℹ️ [ConnectionManager] AppRemote disconnected, no token to preserve")
            connectionState = .disconnected
            return
        }
        
        if let error = error {
            // Check if this is a background-related error that shouldn't clear auth
            let isBackgroundError = isBackgroundRelatedError(error)
            let appState = UIApplication.shared.applicationState
            
            if isBackgroundError || appState == .background {
                print("📱 [ConnectionManager] Background AppRemote disconnection - preserving auth state")
                print("  - App state: \(appState), Background error: \(isBackgroundError)")
                print("  - Keeping token: \(token.prefix(10))...")
                connectionState = .authenticated(token: token)
            } else {
                print("⚠️ [ConnectionManager] AppRemote disconnected with error: \(error.localizedDescription)")
                connectionState = .connectionError(token: token, error)
            }
        } else {
            print("ℹ️ [ConnectionManager] AppRemote disconnected, reverting to authenticated")
            connectionState = .authenticated(token: token)
        }
    }
    
    /// Determines if an error is related to background execution limitations
    private func isBackgroundRelatedError(_ error: Error) -> Bool {
        let nsError = error as NSError
        
        // Check for background-specific error patterns
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost:
                return true
            default:
                break
            }
        }
        
        // Check error description for background-related keywords
        let errorDescription = error.localizedDescription.lowercased()
        let backgroundKeywords = ["background", "suspended", "timeout", "connection lost"]
        
        return backgroundKeywords.contains { errorDescription.contains($0) }
    }
    
    func tokenExpired() {
        print("🔄 [ConnectionManager] Token expired - disconnecting")
        connectionState = .disconnected
    }
    
    func disconnect() {
        print("🔌 [ConnectionManager] Manual disconnect")
        connectionState = .disconnected
    }
    
    func retryConnection() {
        switch connectionState {
        case .authenticationFailed:
            print("🔄 [ConnectionManager] Retrying authentication...")
            connectionState = .authenticating
            
        case .connectionError(let token, _):
            print("🔄 [ConnectionManager] Retrying AppRemote connection...")
            connectionState = .authenticated(token: token)
            
        case .authenticated:
            print("🔄 [ConnectionManager] Starting AppRemote connection...")
            startAppRemoteConnection()
            
        default:
            print("ℹ️ [ConnectionManager] No retry action for current state: \(connectionState)")
        }
    }
    
    // MARK: - Computed Properties for UI Binding
    
    /// Legacy compatibility - maps to isAuthenticated
    var isConnected: Bool {
        return connectionState.isAuthenticated
    }
    
    /// Legacy compatibility - maps to unified status
    var connectionStatus: SpotifyViewModel.ConnectionStatus {
        switch connectionState {
        case .disconnected:
            return .disconnected
        case .authenticating, .connecting:
            return .connecting
        case .authenticated, .connected:
            return .connected
        case .authenticationFailed(let error), .connectionError(_, let error):
            return .error(error.localizedDescription)
        }
    }
    
    // MARK: - State Machine Validation
    
    /// Validates that state transitions are legal
    private func canTransition(from: SpotifyConnectionState, to: SpotifyConnectionState) -> Bool {
        switch (from, to) {
        // From disconnected
        case (.disconnected, .authenticating):
            return true
            
        // From authenticating
        case (.authenticating, .authenticated):
            return true
        case (.authenticating, .authenticationFailed):
            return true
            
        // From authenticated
        case (.authenticated, .connecting):
            return true
        case (.authenticated, .disconnected):
            return true
            
        // From connecting
        case (.connecting, .connected):
            return true
        case (.connecting, .connectionError):
            return true
            
        // From connected
        case (.connected, .authenticated):
            return true
        case (.connected, .connectionError):
            return true
        case (.connected, .disconnected):
            return true
            
        // From error states
        case (.authenticationFailed, .authenticating):
            return true
        case (.authenticationFailed, .disconnected):
            return true
        case (.connectionError, .authenticated):
            return true
        case (.connectionError, .connecting):
            return true
        case (.connectionError, .disconnected):
            return true
            
        // Any state can go to disconnected (reset)
        case (_, .disconnected):
            return true
            
        default:
            return false
        }
    }
}

// MARK: - Error Types for Connection States

enum SpotifyConnectionError: LocalizedError {
    case appRemoteNotInstalled
    case appRemoteConnectionTimeout
    case authenticationCancelled
    case tokenValidationFailed
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .appRemoteNotInstalled:
            return "Spotify app is not installed"
        case .appRemoteConnectionTimeout:
            return "Connection to Spotify app timed out"
        case .authenticationCancelled:
            return "Authentication was cancelled"
        case .tokenValidationFailed:
            return "Token validation failed"
        case .networkError(let message):
            return "Network error: \(message)"
        }
    }
}