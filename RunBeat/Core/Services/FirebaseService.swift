//
//  FirebaseService.swift
//  RunBeat
//
//  Firebase integration service for RunBeat
//  Handles anonymous authentication for user-scoped backend endpoints
//

import Foundation
import Firebase
import FirebaseAuth
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupAuthStateListener()
    }
    
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
    
    // MARK: - Authentication
    
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] auth, user in
            DispatchQueue.main.async {
                self?.isAuthenticated = user != nil
                self?.currentUserId = user?.uid
                
                if let userId = user?.uid {
                    AppLogger.info("Firebase user authenticated: \(userId)", component: "Firebase")
                    
                    // Notify BackendService of user ID for user-scoped endpoints
                    BackendService.shared.setUserID(userId)
                    AppLogger.info("Backend service notified of user ID", component: "Firebase")
                } else {
                    AppLogger.warn("Firebase user not authenticated - attempting anonymous sign-in", component: "Firebase")
                    
                    // Clear user ID from BackendService (fallback to device mode)
                    BackendService.shared.setUserID(nil)
                    
                    // Attempt anonymous sign-in
                    self?.signInAnonymously()
                }
            }
        }
    }
    
    private func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            DispatchQueue.main.async {
                if let error = error {
                    AppLogger.error("Firebase anonymous auth failed: \(error.localizedDescription)", component: "Firebase")
                    
                    // Ensure BackendService falls back to device mode
                    BackendService.shared.setUserID(nil)
                    AppLogger.info("Backend service remains in device-scoped mode due to auth failure", component: "Firebase")
                } else if let user = result?.user {
                    AppLogger.info("Firebase anonymous auth success: \(user.uid)", component: "Firebase")
                    
                    // Update published properties
                    self?.isAuthenticated = true
                    self?.currentUserId = user.uid
                    
                    // Notify BackendService of user ID
                    BackendService.shared.setUserID(user.uid)
                    AppLogger.info("Backend service switched to user-scoped mode", component: "Firebase")
                }
            }
        }
    }
    
    // MARK: - Manual Authentication Control
    
    /**
     * Force attempt anonymous sign-in (for testing/debugging)
     */
    func forceSignInAnonymously() {
        AppLogger.debug("Forcing anonymous sign-in attempt", component: "Firebase")
        signInAnonymously()
    }
    
    /**
     * Sign out current user
     */
    func signOut() {
        do {
            try Auth.auth().signOut()
            AppLogger.info("Firebase user signed out", component: "Firebase")
        } catch {
            AppLogger.error("Firebase sign out failed: \(error.localizedDescription)", component: "Firebase")
        }
    }
    
    // MARK: - Status Information
    
    /**
     * Get authentication status for debugging
     */
    var authStatus: [String: Any] {
        return [
            "is_authenticated": isAuthenticated,
            "current_user_id": currentUserId ?? "none",
            "auth_provider": Auth.auth().currentUser?.providerData.first?.providerID ?? "none",
            "is_anonymous": Auth.auth().currentUser?.isAnonymous ?? false
        ]
    }
}

// MARK: - Legacy Compatibility

/**
 * Data models maintained for compatibility with existing code
 * All data operations are now handled by BackendService + FastAPI backend
 */
struct UserSettings {
    let restingHR: Int
    let maxHR: Int
    let useAutoZones: Bool
    let zone1Lower: Int
    let zone1Upper: Int
    let zone2Upper: Int
    let zone3Upper: Int
    let zone4Upper: Int
    let zone5Upper: Int
}

enum WorkoutType: String {
    case free = "free"
    case vo2max = "vo2max"
}

struct WorkoutConfig {
    let highIntensityDuration: TimeInterval
    let restDuration: TimeInterval
    let totalIntervals: Int
}