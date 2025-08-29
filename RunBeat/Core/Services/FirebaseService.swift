//
//  FirebaseService.swift
//  RunBeat
//
//  Firebase integration service for RunBeat
//  Handles Spotify token management, user settings sync, and real-time workout data
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import Combine

class FirebaseService: ObservableObject {
    static let shared = FirebaseService()
    
    private let db = Firestore.firestore()
    
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
                    print("✅ [Firebase] User authenticated: \(userId)")
                    self?.setupUserDocument(userId: userId)
                } else {
                    print("❌ [Firebase] User not authenticated")
                    // Attempt anonymous sign-in
                    self?.signInAnonymously()
                }
            }
        }
    }
    
    private func signInAnonymously() {
        Auth.auth().signInAnonymously { [weak self] result, error in
            if let error = error {
                print("❌ [Firebase] Anonymous auth failed: \(error.localizedDescription)")
            } else if let user = result?.user {
                print("✅ [Firebase] Anonymous auth success: \(user.uid)")
                self?.setupUserDocument(userId: user.uid)
            }
        }
    }
    
    private func setupUserDocument(userId: String) {
        // Create user document if it doesn't exist
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { document, error in
            if let error = error {
                print("❌ [Firebase] Error checking user document: \(error)")
                return
            }
            
            if let document = document, !document.exists {
                // Create new user document with default settings
                let defaultData: [String: Any] = [
                    "createdAt": FieldValue.serverTimestamp(),
                    "lastActiveAt": FieldValue.serverTimestamp(),
                    "settings": [
                        "restingHR": 60,
                        "maxHR": 190,
                        "useAutoZones": true
                    ]
                ]
                
                userRef.setData(defaultData) { error in
                    if let error = error {
                        print("❌ [Firebase] Error creating user document: \(error)")
                    } else {
                        print("✅ [Firebase] User document created")
                    }
                }
            } else {
                // Update last active time
                userRef.updateData(["lastActiveAt": FieldValue.serverTimestamp()])
            }
        }
    }
    
    
    // MARK: - Spotify Token Management
    // Note: Token refresh now handled by custom FastAPI backend
    
    func storeSpotifyTokens(accessToken: String, refreshToken: String) async {
        guard let userId = currentUserId else {
            print("❌ [Firebase] No authenticated user for storing tokens")
            return
        }
        
        let userRef = db.collection("users").document(userId)
        
        do {
            try await userRef.updateData([
                "spotifyAccessToken": accessToken,
                "spotifyRefreshToken": refreshToken,
                "tokenUpdatedAt": FieldValue.serverTimestamp()
            ])
            print("✅ [Firebase] Spotify tokens stored successfully")
        } catch {
            print("❌ [Firebase] Failed to store Spotify tokens: \(error.localizedDescription)")
        }
    }
    
    // MARK: - User Settings Sync
    
    func syncUserSettings(_ settings: UserSettings) async {
        guard let userId = currentUserId else {
            print("❌ [Firebase] No authenticated user for settings sync")
            return
        }
        
        let userRef = db.collection("users").document(userId)
        
        let settingsData: [String: Any] = [
            "restingHR": settings.restingHR,
            "maxHR": settings.maxHR,
            "useAutoZones": settings.useAutoZones,
            "zone1Lower": settings.zone1Lower,
            "zone1Upper": settings.zone1Upper,
            "zone2Upper": settings.zone2Upper,
            "zone3Upper": settings.zone3Upper,
            "zone4Upper": settings.zone4Upper,
            "zone5Upper": settings.zone5Upper,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        
        do {
            try await userRef.updateData(["settings": settingsData])
            print("✅ [Firebase] User settings synced successfully")
        } catch {
            print("❌ [Firebase] Failed to sync user settings: \(error.localizedDescription)")
        }
    }
    
    func getUserSettings() async -> UserSettings? {
        guard let userId = currentUserId else {
            print("❌ [Firebase] No authenticated user for getting settings")
            return nil
        }
        
        let userRef = db.collection("users").document(userId)
        
        do {
            let document = try await userRef.getDocument()
            
            if let data = document.data(),
               let settings = data["settings"] as? [String: Any] {
                
                return UserSettings(
                    restingHR: settings["restingHR"] as? Int ?? 60,
                    maxHR: settings["maxHR"] as? Int ?? 190,
                    useAutoZones: settings["useAutoZones"] as? Bool ?? true,
                    zone1Lower: settings["zone1Lower"] as? Int ?? 60,
                    zone1Upper: settings["zone1Upper"] as? Int ?? 70,
                    zone2Upper: settings["zone2Upper"] as? Int ?? 80,
                    zone3Upper: settings["zone3Upper"] as? Int ?? 90,
                    zone4Upper: settings["zone4Upper"] as? Int ?? 100,
                    zone5Upper: settings["zone5Upper"] as? Int ?? 110
                )
            } else {
                print("ℹ️ [Firebase] No user settings found, using defaults")
                return nil
            }
        } catch {
            print("❌ [Firebase] Failed to get user settings: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Real-time Workout Management
    
    func startWorkoutSession(type: WorkoutType, config: WorkoutConfig) async {
        guard let userId = currentUserId else {
            print("❌ [Firebase] No authenticated user for workout session")
            return
        }
        
        let sessionData: [String: Any] = [
            "sessionType": type.rawValue,
            "startedAt": FieldValue.serverTimestamp(),
            "currentInterval": 1,
            "currentPhase": "high",
            "timeRemaining": config.highIntensityDuration,
            "totalIntervals": config.totalIntervals,
            "config": [
                "highIntensityDuration": config.highIntensityDuration,
                "restDuration": config.restDuration,
                "totalIntervals": config.totalIntervals
            ]
        ]
        
        let workoutRef = db.collection("users").document(userId).collection("activeWorkout").document("session")
        
        do {
            try await workoutRef.setData(sessionData)
            print("✅ [Firebase] Workout session started")
        } catch {
            print("❌ [Firebase] Failed to start workout session: \(error.localizedDescription)")
        }
    }
    
    func updateHeartRate(bpm: Int, zone: Int) async {
        guard let userId = currentUserId else { return }
        
        let workoutRef = db.collection("users").document(userId).collection("activeWorkout").document("session")
        
        do {
            try await workoutRef.updateData([
                "heartRate": [
                    "current": bpm,
                    "zone": zone,
                    "lastUpdate": FieldValue.serverTimestamp()
                ]
            ])
        } catch {
            print("❌ [Firebase] Failed to update heart rate: \(error.localizedDescription)")
        }
    }
    
    func stopWorkoutSession() async {
        guard let userId = currentUserId else { return }
        
        let workoutRef = db.collection("users").document(userId).collection("activeWorkout").document("session")
        
        do {
            try await workoutRef.delete()
            print("✅ [Firebase] Workout session stopped")
        } catch {
            print("❌ [Firebase] Failed to stop workout session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Push Notifications
    // Note: Push notifications removed for now
}

// MARK: - Data Models

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