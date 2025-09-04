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
enum ErrorRecoveryAction: Equatable {
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
    let currentIntent: SpotifyService.SpotifyIntent  // Current Spotify usage intent
    
    var timeSinceLastSuccess: TimeInterval? {
        guard let lastSuccess = lastSuccessTime else { return nil }
        return Date().timeIntervalSince(lastSuccess)
    }
}

/// Enhanced recovery decision with error priority classification
struct ErrorRecoveryDecision {
    let shouldRetry: Bool
    let suggestedDelay: TimeInterval
    let priority: ErrorPriority
    let fallbackStrategy: FallbackStrategy
    let reasoning: String
}

/// Error priority levels for resource management
enum ErrorPriority {
    case trainingCritical    // Must fix for training to work (device activation, playlist start)
    case trainingEnhancing   // Nice to have during training (track polling, artwork)  
    case background          // Non-training maintenance (token refresh when idle)
}

/// Fallback strategies when recovery fails or is not possible
enum FallbackStrategy {
    case degradeToWebAPI     // Switch to Web API if AppRemote fails
    case continueWithoutData // Proceed without track info
    case notifyUser          // Show error message
    case silentFailure       // Log and continue
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
    
    /// NEW: Pure decision engine - analyzes error and returns structured decision
    func shouldRecover(from error: SpotifyRecoverableError, context: ErrorContext) -> ErrorRecoveryDecision {
        print("🔍 [ErrorHandler] Analyzing \(error.errorDescription ?? "Unknown") for \(context.operation) with intent: \(context.currentIntent)")
        
        // Respect explicit disconnection intent - never recover
        if context.currentIntent == .disconnected {
            return ErrorRecoveryDecision(
                shouldRetry: false,
                suggestedDelay: 0,
                priority: .background,
                fallbackStrategy: .silentFailure,
                reasoning: "Explicit disconnection intent - no recovery needed"
            )
        }
        
        switch error {
        case .appRemoteConnectionFailed, .appRemoteDisconnected:
            let shouldRetry: Bool
            let priority: ErrorPriority
            let reasoning: String
            
            switch context.currentIntent {
            case .training:
                shouldRetry = context.attemptNumber < maxRetryAttempts
                priority = .trainingCritical
                reasoning = "AppRemote critical for training playlist control"
                
            case .idle:
                shouldRetry = false  // Don't aggressively reconnect when idle
                priority = .background
                reasoning = "AppRemote disconnection during idle - expected behavior"
                
            case .disconnected:
                shouldRetry = false  // Already handled above
                priority = .background
                reasoning = "Explicit disconnection"
            }
            
            return ErrorRecoveryDecision(
                shouldRetry: shouldRetry,
                suggestedDelay: exponentialBackoff(attempt: context.attemptNumber),
                priority: priority,
                fallbackStrategy: .degradeToWebAPI,
                reasoning: reasoning
            )
            
        case .tokenExpired, .authenticationRevoked:
            return ErrorRecoveryDecision(
                shouldRetry: true, // Always attempt token refresh
                suggestedDelay: 0.1,
                priority: .trainingCritical, // Tokens needed for all operations
                fallbackStrategy: .notifyUser,
                reasoning: "Token required for all Spotify operations"
            )
            
        case .networkTimeout, .networkUnavailable:
            return ErrorRecoveryDecision(
                shouldRetry: context.attemptNumber < 2,
                suggestedDelay: min(2.0 * Double(context.attemptNumber), 8.0),
                priority: context.currentIntent == .training ? .trainingEnhancing : .background,
                fallbackStrategy: .continueWithoutData,
                reasoning: "Network issue - \(context.currentIntent == .training ? "training can continue with cached data" : "background operation")"
            )
            
        case .playlistNotFound:
            return ErrorRecoveryDecision(
                shouldRetry: false, // Content errors don't benefit from retry
                suggestedDelay: 0,
                priority: .trainingEnhancing,
                fallbackStrategy: .continueWithoutData,
                reasoning: "Content not found - user notification or fallback needed"
            )
            
        case .deviceNotFound:
            return ErrorRecoveryDecision(
                shouldRetry: false, // User action required
                suggestedDelay: 0,
                priority: .trainingCritical,
                fallbackStrategy: .notifyUser,
                reasoning: "User action required to resolve issue"
            )
            
        case .rateLimited(let retryAfter):
            let delay = retryAfter ?? 5.0
            return ErrorRecoveryDecision(
                shouldRetry: context.attemptNumber < 2,
                suggestedDelay: delay, // Wait for rate limit to reset
                priority: context.currentIntent == .training ? .trainingEnhancing : .background,
                fallbackStrategy: .degradeToWebAPI,
                reasoning: "Rate limited - wait and potentially switch to Web API"
            )
            
        case .insufficientPermissions:
            return ErrorRecoveryDecision(
                shouldRetry: false, // User action required
                suggestedDelay: 0,
                priority: .trainingCritical,
                fallbackStrategy: .notifyUser,
                reasoning: "User action required - insufficient permissions"
            )
            
        case .apiError(_, _):
            return ErrorRecoveryDecision(
                shouldRetry: context.attemptNumber < 2,
                suggestedDelay: exponentialBackoff(attempt: context.attemptNumber),
                priority: context.currentIntent == .training ? .trainingEnhancing : .background,
                fallbackStrategy: .degradeToWebAPI,
                reasoning: "API error - retry with backoff and fallback to Web API"
            )
            
        case .serviceUnavailable:
            return ErrorRecoveryDecision(
                shouldRetry: context.attemptNumber < 2,
                suggestedDelay: exponentialBackoff(attempt: context.attemptNumber),
                priority: context.currentIntent == .training ? .trainingEnhancing : .background,
                fallbackStrategy: .degradeToWebAPI,
                reasoning: "Service unavailable - retry with backoff and fallback to Web API"
            )
            
        case .noData(let operation), .invalidResponse(let operation), .decodingFailed(let operation, _):
            return ErrorRecoveryDecision(
                shouldRetry: context.attemptNumber < 1, // Single retry for data issues
                suggestedDelay: 1.0,
                priority: context.currentIntent == .training ? .trainingEnhancing : .background,
                fallbackStrategy: .continueWithoutData,
                reasoning: "Data issue with \(operation) - single retry attempt"
            )
            
        case .spotifyNotInstalled:
            return ErrorRecoveryDecision(
                shouldRetry: false, // User action required
                suggestedDelay: 0,
                priority: .trainingCritical,
                fallbackStrategy: .degradeToWebAPI,
                reasoning: "Spotify app not installed - fallback to Web API"
            )
        }
    }
    
    /// Helper: Calculate exponential backoff delay
    private func exponentialBackoff(attempt: Int) -> TimeInterval {
        return min(exponentialBackoffBase * pow(2.0, Double(attempt - 1)), maxBackoffDelay)
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
            if context.currentIntent == .training {
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