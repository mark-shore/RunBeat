import Foundation
import AVFoundation

class AppState: ObservableObject {
    @Published var isSessionActive = false
    
    // Heart rate zone settings
    @Published var restingHR: Int = 60
    @Published var maxHR: Int = 190
    @Published var useAutoZones: Bool = true {
        didSet {
            // When switching to manual zones, populate with current auto values
            if !useAutoZones && oldValue == true {
                updateManualZonesFromAuto()
            }
        }
    }
    
    // Manual heart rate zones (used when useAutoZones is false)
    @Published var zone1Lower: Int = 60
    @Published var zone1Upper: Int = 70
    @Published var zone2Upper: Int = 80
    @Published var zone3Upper: Int = 90
    @Published var zone4Upper: Int = 100
    @Published var zone5Upper: Int = 110
    
    private let userDefaults = UserDefaults.standard
    
    func startSession() {
        isSessionActive = true
        startHeartRateMonitoring()
    }
    
    func stopSession() {
        isSessionActive = false
        stopHeartRateMonitoring()
    }

    private let hrManager = HeartRateManager()
    private let announcer = SpeechAnnouncer()

    private var currentZone: Int?
    private var lastAnnouncementTime: Date?
    private var lastAnnouncedZone: Int?
    private var pendingZoneAnnouncement: Int?
    private var cooldownTimer: Timer?
    private let announcementCooldown: TimeInterval = 5.0 // 5 seconds between announcements

    init() {
        loadZoneSettings()

        hrManager.onNewHeartRate = { [weak self] bpm in
            self?.handle(bpm: bpm)
        }
        
        announcer.onAnnouncementFinished = { [weak self] in
            self?.restoreMusicVolume()
        }

        print("🚀 AppState initialized – ready to start training session")
    }
    
    deinit {
        cooldownTimer?.invalidate()
        deactivateAudioSession()
    }
    
    private func startHeartRateMonitoring() {
        hrManager.startMonitoring()
        // Reset all announcement state for new workout session
        lastAnnouncementTime = nil
        lastAnnouncedZone = nil
        pendingZoneAnnouncement = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        print("💓 Training session started - heart rate monitoring active")
    }
    
    private func stopHeartRateMonitoring() {
        hrManager.stopMonitoring()
        deactivateAudioSession()
        // Clean up all state when stopping
        currentZone = nil
        lastAnnouncementTime = nil
        lastAnnouncedZone = nil
        pendingZoneAnnouncement = nil
        cooldownTimer?.invalidate()
        cooldownTimer = nil
        print("🔋 Training session ended - heart rate monitoring stopped")
    }

    private func handle(bpm: Int) {
        if let newZone = calculateZone(for: bpm), newZone != currentZone {
            currentZone = newZone
            
            if isSessionActive {
                if shouldAnnounce() {
                    // Announce immediately and start cooldown
                    announceZone(newZone)
                } else {
                    // Only set as pending if it's different from the last announced zone
                    if newZone != lastAnnouncedZone {
                        pendingZoneAnnouncement = newZone
                        print("🔇 Zone \(newZone) detected, will announce when cooldown expires if still in this zone")
                    } else {
                        print("🔇 Zone \(newZone) detected but was recently announced, skipping")
                    }
                }
            }
        }
    }
    
    private func shouldAnnounce() -> Bool {
        guard let lastTime = lastAnnouncementTime else {
            return true // First announcement, always allow
        }
        
        let timeSinceLastAnnouncement = Date().timeIntervalSince(lastTime)
        return timeSinceLastAnnouncement >= announcementCooldown
    }
    
    private func announceZone(_ zone: Int) {
        // Reactivate audio session before announcement
        setupAudioSession()
        
        announcer.announceZone(zone)
        lastAnnouncementTime = Date()
        lastAnnouncedZone = zone
        pendingZoneAnnouncement = nil // Clear any pending announcement
        
        // Cancel existing timer and start new cooldown timer
        cooldownTimer?.invalidate()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: announcementCooldown, repeats: false) { [weak self] _ in
            self?.handleCooldownExpired()
        }
        
        print("🔊 Zone \(zone) announced (cooldown active for \(Int(announcementCooldown))s)")
    }
    
    private func handleCooldownExpired() {
        print("⏰ Announcement cooldown expired")
        
        // If there's a pending announcement and user is still in that zone, announce it
        if let pendingZone = pendingZoneAnnouncement,
           pendingZone == currentZone,
           isSessionActive {
            announceZone(pendingZone)
            print("🔊 Announcing pending zone \(pendingZone) after cooldown")
        } else {
            pendingZoneAnnouncement = nil
            print("🔇 No pending announcement or user moved to different zone")
        }
    }
    
    // MARK: - Zone Settings Persistence
    
    private func loadZoneSettings() {
        // Load heart rate settings
        restingHR = userDefaults.object(forKey: "restingHR") as? Int ?? 60
        maxHR = userDefaults.object(forKey: "maxHR") as? Int ?? 190
        useAutoZones = userDefaults.object(forKey: "useAutoZones") as? Bool ?? true
        
        // Load manual zone settings
        zone1Lower = userDefaults.object(forKey: "zone1Lower") as? Int ?? 60
        zone1Upper = userDefaults.object(forKey: "zone1Upper") as? Int ?? 70
        zone2Upper = userDefaults.object(forKey: "zone2Upper") as? Int ?? 80
        zone3Upper = userDefaults.object(forKey: "zone3Upper") as? Int ?? 90
        zone4Upper = userDefaults.object(forKey: "zone4Upper") as? Int ?? 100
        zone5Upper = userDefaults.object(forKey: "zone5Upper") as? Int ?? 110
        
        if useAutoZones {
            let autoZones = calculateAutoZones()
            print("📊 Auto heart rate zones loaded: RHR=\(restingHR), MaxHR=\(maxHR), Zones: Z1(\(autoZones.0)-\(autoZones.1)), Z2(\(autoZones.1+1)-\(autoZones.2)), Z3(\(autoZones.2+1)-\(autoZones.3)), Z4(\(autoZones.3+1)-\(autoZones.4)), Z5(\(autoZones.4+1)-\(autoZones.5))")
        } else {
            print("📊 Manual heart rate zones loaded: Z1(\(zone1Lower)-\(zone1Upper)), Z2(\(zone1Upper+1)-\(zone2Upper)), Z3(\(zone2Upper+1)-\(zone3Upper)), Z4(\(zone3Upper+1)-\(zone4Upper)), Z5(\(zone4Upper+1)-\(zone5Upper))")
        }
    }
    
    func saveZoneSettings() {
        // Save heart rate settings
        userDefaults.set(restingHR, forKey: "restingHR")
        userDefaults.set(maxHR, forKey: "maxHR")
        userDefaults.set(useAutoZones, forKey: "useAutoZones")
        
        // Save manual zone settings
        userDefaults.set(zone1Lower, forKey: "zone1Lower")
        userDefaults.set(zone1Upper, forKey: "zone1Upper")
        userDefaults.set(zone2Upper, forKey: "zone2Upper")
        userDefaults.set(zone3Upper, forKey: "zone3Upper")
        userDefaults.set(zone4Upper, forKey: "zone4Upper")
        userDefaults.set(zone5Upper, forKey: "zone5Upper")
        
        if useAutoZones {
            let autoZones = calculateAutoZones()
            print("💾 Auto heart rate zones saved: RHR=\(restingHR), MaxHR=\(maxHR), Zones: Z1(\(autoZones.0)-\(autoZones.1)), Z2(\(autoZones.1+1)-\(autoZones.2)), Z3(\(autoZones.2+1)-\(autoZones.3)), Z4(\(autoZones.3+1)-\(autoZones.4)), Z5(\(autoZones.4+1)-\(autoZones.5))")
        } else {
            print("💾 Manual heart rate zones saved: Z1(\(zone1Lower)-\(zone1Upper)), Z2(\(zone1Upper+1)-\(zone2Upper)), Z3(\(zone2Upper+1)-\(zone3Upper)), Z4(\(zone3Upper+1)-\(zone4Upper)), Z5(\(zone4Upper+1)-\(zone5Upper))")
        }
    }
    
    // MARK: - Heart Rate Zone Calculations
    
    /// Calculate auto zones using heart rate reserve formula
    /// Returns tuple of (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
    private func calculateAutoZones() -> (Int, Int, Int, Int, Int, Int) {
        let hrReserve = maxHR - restingHR
        
        // Heart rate zone percentages based on HRR (Karvonen formula) - Whoop methodology
        let zone1Lower = restingHR + Int(floor(Double(hrReserve) * 0.40)) // 40% HRR (floor for minimums)
        let zone1Upper = restingHR + Int(round(Double(hrReserve) * 0.60)) // 60% HRR (round for maximums)
        let zone2Upper = restingHR + Int(round(Double(hrReserve) * 0.70)) // 70% HRR  
        let zone3Upper = restingHR + Int(round(Double(hrReserve) * 0.80)) // 80% HRR
        let zone4Upper = restingHR + Int(round(Double(hrReserve) * 0.90)) // 90% HRR
        let zone5Upper = restingHR + Int(round(Double(hrReserve) * 1.00)) // 100% HRR
        
        return (zone1Lower, zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
    }
    
    /// Get the current zone upper limits (either auto-calculated or manual)
    private func getCurrentZoneUpperLimits() -> (Int, Int, Int, Int, Int) {
        if useAutoZones {
            let autoZones = calculateAutoZones()
            return (autoZones.1, autoZones.2, autoZones.3, autoZones.4, autoZones.5) // Skip zone1Lower, return the upper limits
        } else {
            return (zone1Upper, zone2Upper, zone3Upper, zone4Upper, zone5Upper)
        }
    }
    
    /// Get the zone 1 lower limit for auto zones
    private func getZone1Lower() -> Int {
        if useAutoZones {
            return calculateAutoZones().0
        } else {
            return zone1Lower // For manual zones, use the custom zone 1 lower
        }
    }
    
    /// Update manual zone values from current auto calculations
    private func updateManualZonesFromAuto() {
        let autoZones = calculateAutoZones()
        zone1Lower = autoZones.0 // zone1Lower
        zone1Upper = autoZones.1 // zone1Upper
        zone2Upper = autoZones.2 // zone2Upper
        zone3Upper = autoZones.3 // zone3Upper
        zone4Upper = autoZones.4 // zone4Upper
        zone5Upper = autoZones.5 // zone5Upper
        print("📊 Manual zones updated from auto calculation: Z1(\(zone1Lower)-\(zone1Upper)), Z2(\(zone1Upper+1)-\(zone2Upper)), Z3(\(zone2Upper+1)-\(zone3Upper)), Z4(\(zone3Upper+1)-\(zone4Upper)), Z5(\(zone4Upper+1)-\(zone5Upper))")
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            print("🔊 Audio session activated with mixing and ducking")
        } catch {
            print("❌ Failed to set audio session: \(error)")
        }
        #else
        print("🔊 Audio session setup (iOS only)")
        #endif
    }
    
    private func deactivateAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🔇 Audio session deactivated - music restored to normal volume")
        } catch {
            print("❌ Failed to deactivate audio session: \(error)")
        }
        #else
        print("🔇 Audio session deactivated (iOS only)")
        #endif
    }
    
    private func restoreMusicVolume() {
        // Only restore music volume if we're still in an active training session
        guard isSessionActive else { return }
        
        #if os(iOS)
        do {
            // Deactivate to restore music volume - don't reactivate until next announcement
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            print("🎵 Music volume restored - session inactive until next announcement")
        } catch {
            print("❌ Failed to restore music volume: \(error)")
        }
        #else
        print("🎵 Music volume restored (iOS only)")
        #endif
    }

    private func calculateZone(for bpm: Int) -> Int? {
        let zones = getCurrentZoneUpperLimits()
        let (z1Upper, z2Upper, z3Upper, z4Upper, z5Upper) = zones
        let z1Lower = getZone1Lower()
        
        switch bpm {
        case ..<z1Lower: return nil  // Below zone 1 minimum
        case z1Lower...z1Upper: return 1
        case (z1Upper + 1)...z2Upper: return 2
        case (z2Upper + 1)...z3Upper: return 3
        case (z3Upper + 1)...z4Upper: return 4
        case (z4Upper + 1)...z5Upper: return 5
        case (z5Upper + 1)...: return 5  // Max zone for very high heart rates
        default: return nil
        }
    }
}

