import Foundation
import NotificationCenter
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
    private let audioService = AudioService()
    private let trainingManager = HeartRateTrainingManager()

    init() {
        loadZoneSettings()

        hrManager.onNewHeartRate = { [weak self] bpm in
            self?.trainingManager.processHeartRate(bpm)
            VO2MaxTrainingManager.shared.tick(now: Date())
        }
        
        announcer.onAnnouncementFinished = { [weak self] in
            guard let self = self else { return }
            self.audioService.restoreMusicVolume(isTrainingSessionActive: self.isSessionActive)
        }
        
        audioService.delegate = self
        trainingManager.delegate = self

        print("🚀 AppState initialized – ready to start training session")
    }
    
    deinit {
        audioService.deactivateAudioSession()
    }
    
    private func startHeartRateMonitoring() {
        hrManager.startMonitoring()
        trainingManager.resetSessionState()
        print("💓 Training session started - heart rate monitoring active")
    }
    
    private func stopHeartRateMonitoring() {
        hrManager.stopMonitoring()
        audioService.deactivateAudioSession()
        trainingManager.resetSessionState()
        print("🔋 Training session ended - heart rate monitoring stopped")
    }

    private func announceZone(_ zone: Int) {
        // Reactivate audio session before announcement
        audioService.setupAudioSessionForAnnouncement()
        announcer.announceZone(zone)
        print("🔊 Zone \(zone) announced")
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
        
        // Update the training manager with the loaded settings
        trainingManager.updateZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            zone1Lower: zone1Lower,
            zone1Upper: zone1Upper,
            zone2Upper: zone2Upper,
            zone3Upper: zone3Upper,
            zone4Upper: zone4Upper,
            zone5Upper: zone5Upper
        )
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
        
        // Update the training manager with the new settings
        trainingManager.updateZoneSettings(
            restingHR: restingHR,
            maxHR: maxHR,
            useAutoZones: useAutoZones,
            zone1Lower: zone1Lower,
            zone1Upper: zone1Upper,
            zone2Upper: zone2Upper,
            zone3Upper: zone3Upper,
            zone4Upper: zone4Upper,
            zone5Upper: zone5Upper
        )
    }
    

    
    /// Update manual zone values from current auto calculations
    private func updateManualZonesFromAuto() {
        let autoZones = HeartRateZoneCalculator.calculateAutoZones(restingHR: restingHR, maxHR: maxHR)
        zone1Lower = autoZones.0 // zone1Lower
        zone1Upper = autoZones.1 // zone1Upper
        zone2Upper = autoZones.2 // zone2Upper
        zone3Upper = autoZones.3 // zone3Upper
        zone4Upper = autoZones.4 // zone4Upper
        zone5Upper = autoZones.5 // zone5Upper
        print("📊 Manual zones updated from auto calculation: Z1(\(zone1Lower)-\(zone1Upper)), Z2(\(zone1Upper+1)-\(zone2Upper)), Z3(\(zone2Upper+1)-\(zone3Upper)), Z4(\(zone3Upper+1)-\(zone4Upper)), Z5(\(zone4Upper+1)-\(zone5Upper))")
    }


}

// MARK: - HeartRateTrainingDelegate
extension AppState: HeartRateTrainingDelegate {
    func heartRateTraining(_ manager: HeartRateTrainingManager, didDetectZoneChange newZone: Int, fromZone oldZone: Int?) {
        // Zone change detected - no additional action needed here
    }
    
    func heartRateTraining(_ manager: HeartRateTrainingManager, shouldAnnounceZone zone: Int) -> Bool {
        // Only announce if we're in an active session
        return isSessionActive
    }
    
    func heartRateTraining(_ manager: HeartRateTrainingManager, didRequestZoneAnnouncement zone: Int) {
        // Perform the actual announcement
        announceZone(zone)
    }
}

// MARK: - AudioServiceDelegate
extension AppState: AudioServiceDelegate {
    func audioServiceDidRestoreMusicVolume() {
        // Hook for future audio-related state updates if needed
        print("🎵 Audio service restored music volume")
    }
}

