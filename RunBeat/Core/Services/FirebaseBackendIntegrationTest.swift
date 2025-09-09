//
//  FirebaseBackendIntegrationTest.swift
//  RunBeat
//
//  Test integration between Firebase anonymous auth and BackendService
//

import Foundation

/**
 * Simple integration test to verify Firebase-Backend user ID flow
 * Run this from anywhere in the app to verify the integration works
 */
class FirebaseBackendIntegrationTest {
    
    static func runTest() {
        AppLogger.info("🧪 Starting Firebase-Backend integration test", component: "IntegrationTest")
        
        // Test 1: Check initial state
        testInitialState()
        
        // Test 2: Check FirebaseService state
        testFirebaseState()
        
        // Test 3: Check BackendService state
        testBackendState()
        
        // Test 4: Force authentication flow
        testAuthenticationFlow()
        
        AppLogger.info("🧪 Integration test completed", component: "IntegrationTest")
    }
    
    private static func testInitialState() {
        AppLogger.info("📋 Test 1: Initial state", component: "IntegrationTest")
        
        let backendStatus = BackendService.shared.cacheStatus
        AppLogger.info("Backend operation mode: \(backendStatus["operation_mode"] ?? "unknown")", component: "IntegrationTest")
        AppLogger.info("Backend current user ID: \(backendStatus["current_user_id"] ?? "unknown")", component: "IntegrationTest")
        AppLogger.info("Backend device ID: \(backendStatus["device_id"] ?? "unknown")", component: "IntegrationTest")
    }
    
    private static func testFirebaseState() {
        AppLogger.info("📋 Test 2: Firebase state", component: "IntegrationTest")
        
        let firebaseService = FirebaseService.shared
        let authStatus = firebaseService.authStatus
        
        AppLogger.info("Firebase authenticated: \(authStatus["is_authenticated"] ?? false)", component: "IntegrationTest")
        AppLogger.info("Firebase user ID: \(authStatus["current_user_id"] ?? "none")", component: "IntegrationTest")
        AppLogger.info("Firebase is anonymous: \(authStatus["is_anonymous"] ?? false)", component: "IntegrationTest")
    }
    
    private static func testBackendState() {
        AppLogger.info("📋 Test 3: Backend state", component: "IntegrationTest")
        
        let backendService = BackendService.shared
        let cacheStatus = backendService.cacheStatus
        
        AppLogger.info("Backend operation mode: \(cacheStatus["operation_mode"] ?? "unknown")", component: "IntegrationTest")
        AppLogger.info("Backend user ID: \(cacheStatus["current_user_id"] ?? "none")", component: "IntegrationTest")
        
        // Test endpoint construction
        Task {
            do {
                // This will trigger endpoint construction and show which endpoints are being used
                AppLogger.info("Testing endpoint construction...", component: "IntegrationTest")
                
                // This should fail gracefully but show us which endpoint is being used
                let _ = try await backendService.getFreshSpotifyToken()
            } catch {
                // Expected to fail - we just want to see the endpoint being used in logs
                AppLogger.info("Token request failed as expected (no stored tokens): \(error.localizedDescription)", component: "IntegrationTest")
            }
        }
    }
    
    private static func testAuthenticationFlow() {
        AppLogger.info("📋 Test 4: Authentication flow", component: "IntegrationTest")
        
        // Force a sign-in attempt to test the integration
        let firebaseService = FirebaseService.shared
        
        if !firebaseService.isAuthenticated {
            AppLogger.info("Forcing anonymous sign-in to test integration...", component: "IntegrationTest")
            firebaseService.forceSignInAnonymously()
            
            // Check state after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                let updatedBackendStatus = BackendService.shared.cacheStatus
                let updatedFirebaseStatus = firebaseService.authStatus
                
                AppLogger.info("🔄 Post-auth Firebase state:", component: "IntegrationTest")
                AppLogger.info("  - Authenticated: \(updatedFirebaseStatus["is_authenticated"] ?? false)", component: "IntegrationTest")
                AppLogger.info("  - User ID: \(updatedFirebaseStatus["current_user_id"] ?? "none")", component: "IntegrationTest")
                
                AppLogger.info("🔄 Post-auth Backend state:", component: "IntegrationTest")
                AppLogger.info("  - Operation mode: \(updatedBackendStatus["operation_mode"] ?? "unknown")", component: "IntegrationTest")
                AppLogger.info("  - User ID: \(updatedBackendStatus["current_user_id"] ?? "none")", component: "IntegrationTest")
                
                // Verify integration worked
                let firebaseUserId = updatedFirebaseStatus["current_user_id"] as? String
                let backendUserId = updatedBackendStatus["current_user_id"] as? String
                
                if firebaseUserId != nil && firebaseUserId == backendUserId {
                    AppLogger.info("✅ Integration SUCCESS: User IDs match between Firebase and Backend", component: "IntegrationTest")
                } else {
                    AppLogger.warn("⚠️ Integration ISSUE: User IDs don't match", component: "IntegrationTest")
                    AppLogger.warn("  Firebase: \(firebaseUserId ?? "nil")", component: "IntegrationTest")
                    AppLogger.warn("  Backend: \(backendUserId ?? "nil")", component: "IntegrationTest")
                }
            }
        } else {
            AppLogger.info("User already authenticated, checking integration...", component: "IntegrationTest")
            
            let firebaseUserId = firebaseService.currentUserId
            let backendUserId = BackendService.shared.cacheStatus["current_user_id"] as? String
            
            if firebaseUserId != nil && firebaseUserId == backendUserId {
                AppLogger.info("✅ Integration SUCCESS: User IDs match between Firebase and Backend", component: "IntegrationTest")
            } else {
                AppLogger.warn("⚠️ Integration ISSUE: User IDs don't match", component: "IntegrationTest")
                AppLogger.warn("  Firebase: \(firebaseUserId ?? "nil")", component: "IntegrationTest")
                AppLogger.warn("  Backend: \(backendUserId ?? "nil")", component: "IntegrationTest")
            }
        }
    }
}

// MARK: - Quick Test Extension for ViewModels/Views
extension FirebaseBackendIntegrationTest {
    
    /**
     * Quick status check that can be called from UI
     */
    static func quickStatusCheck() -> [String: Any] {
        let firebaseStatus = FirebaseService.shared.authStatus
        let backendStatus = BackendService.shared.cacheStatus
        
        return [
            "firebase_authenticated": firebaseStatus["is_authenticated"] ?? false,
            "firebase_user_id": firebaseStatus["current_user_id"] ?? "none",
            "backend_mode": backendStatus["operation_mode"] ?? "unknown",
            "backend_user_id": backendStatus["current_user_id"] ?? "none",
            "integration_working": {
                let fbUserId = firebaseStatus["current_user_id"] as? String
                let beUserId = backendStatus["current_user_id"] as? String
                return fbUserId != nil && fbUserId == beUserId
            }()
        ]
    }
}