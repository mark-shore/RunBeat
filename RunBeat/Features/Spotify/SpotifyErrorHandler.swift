//
//  SpotifyErrorHandler.swift
//  RunBeat
//
//  Structured error recovery system for Spotify integration
//  Provides intelligent error handling with user-friendly recovery strategies
//

import Foundation
import Combine
import UIKit

/// Recovery actions that can be taken for different error types
enum ErrorRecoveryAction {
    case reconnectAppRemote          // Try to reconnect AppRemote
    case refreshToken               // Refresh authentication token
    case retryAfterDelay(TimeInterval)  // Retry after specified delay
    case retryWithExponentialBackoff // Retry with increasing delays
    case showUserAuthPrompt         // Ask user to re-authenticate
    case degradeToWebAPIOnly        // Fall back to Web API only
    case showUserErrorMessage(String) // Show specific error to user
    case noAction                   // No automatic recovery possible
}

/// Context information for error recovery decisions
struct ErrorContext {
    let operation: String           // What was being attempted
    let attemptNumber: Int         // How many times we've tried
    let lastSuccessTime: Date?     // When this operation last succeeded
    let connectionState: SpotifyConnectionState
    let isTrainingActive: Bool     // Whether user is in active training
    
    var timeSinceLastSuccess: TimeInterval? {
        guard let lastSuccess = lastSuccessTime else { return nil }
        return Date().timeIntervalSince(lastSuccess)
    }
}

/// Enhanced error types with recovery context
enum SpotifyRecoverableError: LocalizedError {
    // Connection errors
    case appRemoteDisconnected(underlying: Error?)
    case appRemoteConnectionFailed(underlying: Error?)
    case networkTimeout
    case networkUnavailable
    
    // Authentication errors  
    case tokenExpired
    case authenticationRevoked
    case insufficientPermissions
    
    // API errors
    case rateLimited(retryAfter: TimeInterval?)
    case apiError(code: Int, message: String?)
    case serviceUnavailable
    
    // Data errors
    case noData(operation: String)
    case invalidResponse(operation: String)
    case decodingFailed(operation: String, underlying: Error)
    
    // User errors
    case spotifyNotInstalled
    case playlistNotFound
    case deviceNotFound
    
    var errorDescription: String? {
        switch self {
        case .appRemoteDisconnected:
            return "Lost connection to Spotify app"
        case .appRemoteConnectionFailed:
            return "Cannot connect to Spotify app"
        case .networkTimeout:
            return "Network request timed out"
        case .networkUnavailable:
            return "No internet connection available"
        case .tokenExpired:
            return "Spotify session expired"
        case .authenticationRevoked:
            return "Spotify access was revoked"
        case .insufficientPermissions:
            return "Missing required Spotify permissions"
        case .rateLimited:
            return "Too many requests - please wait"
        case .apiError(let code, let message):
            return "Spotify API error \(code): \(message ?? "Unknown error")"
        case .serviceUnavailable:
            return "Spotify service is temporarily unavailable"
        case .noData(let operation):
            return "No data received for \(operation)"
        case .invalidResponse(let operation):
            return "Invalid response from Spotify for \(operation)"
        case .decodingFailed(let operation, _):
            return "Failed to process \(operation) data"
        case .spotifyNotInstalled:
            return "Spotify app is not installed"
        case .playlistNotFound:
            return "Selected playlist not found"
        case .deviceNotFound:
            return "Spotify playback device not available"
        }
    }
    
    /// User-friendly recovery message
    var recoveryMessage: String {
        switch self {
        case .appRemoteDisconnected, .appRemoteConnectionFailed:
            return "Trying to reconnect to Spotify app..."
        case .networkTimeout, .networkUnavailable:
            return "Check your internet connection and try again"
        case .tokenExpired, .authenticationRevoked:
            return "Please reconnect your Spotify account"
        case .insufficientPermissions:
            return "Please grant required permissions in Spotify"
        case .rateLimited:
            return "Taking a short break to avoid rate limits"
        case .apiError, .serviceUnavailable:
            return "Spotify is experiencing issues - retrying automatically"
        case .noData, .invalidResponse, .decodingFailed:
            return "Data issue - retrying request"
        case .spotifyNotInstalled:
            return "Please install the Spotify app to continue"
        case .playlistNotFound:
            return "Please select a different playlist"
        case .deviceNotFound:
            return "Make sure Spotify is active on this device"
        }
    }
}

/// Intelligent error handler with recovery strategies
class SpotifyErrorHandler: ObservableObject {
    
    // MARK: - Published State
    
    @Published var currentError: SpotifyRecoverableError?
    @Published var isRecovering = false
    @Published var recoveryMessage = ""
    
    // MARK: - Private Properties
    
    private var retryAttempts: [String: Int] = [:]
    private var lastSuccessTimes: [String: Date] = [:]
    private var recoveryTimers: [String: Timer] = [:]
    
    private let maxRetryAttempts = 3
    private let exponentialBackoffBase: TimeInterval = 2.0
    private let maxBackoffDelay: TimeInterval = 30.0
    
    // MARK: - Public API
    
    /// Analyzes an error and returns appropriate recovery action
    func handleError(_ error: SpotifyRecoverableError, context: ErrorContext) -> ErrorRecoveryAction {
        print("🚨 [ErrorHandler] Handling error: \(error.errorDescription ?? "Unknown")")
        print("🚨 [ErrorHandler] Context: \(context.operation), attempt \(context.attemptNumber)")
        
        // Update UI state
        DispatchQueue.main.async { [weak self] in
            self?.currentError = error
            self?.recoveryMessage = error.recoveryMessage
        }
        
        // Determine recovery strategy based on error type and context
        let action = determineRecoveryAction(for: error, context: context)
        
        // Track retry attempts
        updateRetryTracking(for: context.operation, action: action)
        
        print("🔧 [ErrorHandler] Recovery action: \(action)")
        return action
    }
    
    /// Records a successful operation to reset retry tracking
    func recordSuccess(for operation: String) {
        lastSuccessTimes[operation] = Date()
        retryAttempts[operation] = 0
        
        // Clear any existing error state if this was the failing operation
        DispatchQueue.main.async { [weak self] in
            if self?.recoveryMessage.contains(operation) == true {
                self?.currentError = nil
                self?.isRecovering = false
                self?.recoveryMessage = ""
            }
        }
        
        print("✅ [ErrorHandler] Success recorded for: \(operation)")
    }
    
    /// Executes a recovery action with appropriate timing and feedback
    func executeRecovery(_ action: ErrorRecoveryAction, for operation: String, completion: @escaping () -> Void) {
        print("🔧 [ErrorHandler] Executing recovery: \(action)")
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecovering = true
        }
        
        switch action {
        case .retryAfterDelay(let delay):
            scheduleRetry(after: delay, operation: operation, completion: completion)
            
        case .retryWithExponentialBackoff:
            let attempts = retryAttempts[operation] ?? 0
            let delay = min(exponentialBackoffBase * pow(2.0, Double(attempts)), maxBackoffDelay)
            scheduleRetry(after: delay, operation: operation, completion: completion)
            
        case .showUserErrorMessage(let message):
            DispatchQueue.main.async { [weak self] in
                self?.recoveryMessage = message
                self?.isRecovering = false
            }
            completion()
            
        case .noAction:
            DispatchQueue.main.async { [weak self] in
                self?.isRecovering = false
            }
            completion()
            
        default:
            // Other actions are handled by the calling service
            DispatchQueue.main.async { [weak self] in
                self?.isRecovering = false
            }
            completion()
        }
    }
    
    /// Clears all error state
    func clearErrorState() {
        DispatchQueue.main.async { [weak self] in
            self?.currentError = nil
            self?.isRecovering = false
            self?.recoveryMessage = ""
        }
        
        // Cancel any pending recovery timers
        recoveryTimers.values.forEach { $0.invalidate() }
        recoveryTimers.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func determineRecoveryAction(for error: SpotifyRecoverableError, context: ErrorContext) -> ErrorRecoveryAction {
        let attempts = retryAttempts[context.operation] ?? 0
        
        switch error {
        case .appRemoteDisconnected, .appRemoteConnectionFailed:
            return handleAppRemoteError(attempts: attempts, context: context)
            
        case .tokenExpired, .authenticationRevoked:
            return .refreshToken
            
        case .networkTimeout, .networkUnavailable:
            return handleNetworkError(attempts: attempts, context: context)
            
        case .rateLimited(let retryAfter):
            let delay = retryAfter ?? 60.0
            return .retryAfterDelay(delay)
            
        case .apiError(let code, _):
            return handleAPIError(code: code, attempts: attempts, context: context)
            
        case .serviceUnavailable:
            return attempts < maxRetryAttempts ? .retryWithExponentialBackoff : .degradeToWebAPIOnly
            
        case .noData, .invalidResponse, .decodingFailed:
            return attempts < maxRetryAttempts ? .retryWithExponentialBackoff : .noAction
            
        case .insufficientPermissions:
            return .showUserAuthPrompt
            
        case .spotifyNotInstalled:
            return .degradeToWebAPIOnly
            
        case .playlistNotFound, .deviceNotFound:
            return .showUserErrorMessage(error.recoveryMessage)
        }
    }
    
    private func handleAppRemoteError(attempts: Int, context: ErrorContext) -> ErrorRecoveryAction {
        let appState = UIApplication.shared.applicationState
        let isBackground = appState == .background
        
        if attempts < maxRetryAttempts {
            // During training, be more aggressive with reconnection but gentle in background
            if context.isTrainingActive {
                if isBackground {
                    // In background during training, use Web API fallback instead of aggressive reconnection
                    return .degradeToWebAPIOnly
                } else {
                    return .reconnectAppRemote
                }
            } else {
                return .retryWithExponentialBackoff
            }
        } else {
            // After max retries, degrade gracefully without clearing auth
            return .degradeToWebAPIOnly
        }
    }
    
    private func handleNetworkError(attempts: Int, context: ErrorContext) -> ErrorRecoveryAction {
        let appState = UIApplication.shared.applicationState
        let isBackground = appState == .background
        
        if attempts < maxRetryAttempts {
            if isBackground {
                // In background, be more conservative with retries to preserve battery/resources
                return .degradeToWebAPIOnly
            } else {
                return .retryWithExponentialBackoff
            }
        } else {
            // Don't show user messages during background operations
            if isBackground {
                return .degradeToWebAPIOnly
            } else {
                return .showUserErrorMessage("Check your internet connection")
            }
        }
    }
    
    private func handleAPIError(code: Int, attempts: Int, context: ErrorContext) -> ErrorRecoveryAction {
        switch code {
        case 401: // Unauthorized
            return .refreshToken
        case 429: // Rate limited
            return .retryAfterDelay(60.0)
        case 500...599: // Server errors
            return attempts < maxRetryAttempts ? .retryWithExponentialBackoff : .noAction
        default:
            return .showUserErrorMessage("Spotify API error \(code)")
        }
    }
    
    private func updateRetryTracking(for operation: String, action: ErrorRecoveryAction) {
        switch action {
        case .retryAfterDelay, .retryWithExponentialBackoff, .reconnectAppRemote:
            retryAttempts[operation] = (retryAttempts[operation] ?? 0) + 1
        case .refreshToken, .showUserAuthPrompt:
            // Reset retry count for authentication actions
            retryAttempts[operation] = 0
        default:
            break
        }
    }
    
    private func scheduleRetry(after delay: TimeInterval, operation: String, completion: @escaping () -> Void) {
        // Cancel any existing timer for this operation
        recoveryTimers[operation]?.invalidate()
        
        print("⏱️ [ErrorHandler] Scheduling retry for \(operation) in \(delay)s")
        
        let timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            print("🔄 [ErrorHandler] Executing scheduled retry for \(operation)")
            
            DispatchQueue.main.async {
                self?.isRecovering = false
            }
            
            self?.recoveryTimers[operation] = nil
            completion()
        }
        
        recoveryTimers[operation] = timer
    }
    
    // MARK: - Computed Properties
    
    /// Whether there are any active recovery operations
    var hasActiveRecovery: Bool {
        return !recoveryTimers.isEmpty || isRecovering
    }
    
    /// Debug information about current error state
    var debugInfo: String {
        return """
        Current Error: \(currentError?.errorDescription ?? "None")
        Is Recovering: \(isRecovering)
        Recovery Message: "\(recoveryMessage)"
        Active Retries: \(retryAttempts)
        Active Timers: \(recoveryTimers.count)
        """
    }
}

// MARK: - Error Conversion Utilities

extension SpotifyErrorHandler {
    
    /// Converts legacy SpotifyError to SpotifyRecoverableError
    static func convertLegacyError(_ error: Error, operation: String = "unknown") -> SpotifyRecoverableError {
        // Handle SpotifyConnectionError
        if let connectionError = error as? SpotifyConnectionError {
            switch connectionError {
            case .appRemoteNotInstalled:
                return .spotifyNotInstalled
            case .appRemoteConnectionTimeout:
                return .appRemoteConnectionFailed(underlying: error)
            case .authenticationCancelled:
                return .authenticationRevoked
            case .tokenValidationFailed:
                return .tokenExpired
            case .networkError:
                return .networkUnavailable
            }
        }
        
        // Handle general errors
        let nsError = error as NSError
        
        // Network-related errors
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .networkTimeout
            case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
                return .networkUnavailable
            default:
                return .networkUnavailable
            }
        }
        
        // Default fallback
        return .invalidResponse(operation: operation)
    }
}