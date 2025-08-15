import Foundation
import NotificationCenter
import AVFoundation
import Combine

class AppState: ObservableObject {
    @Published var isSessionActive = false
    
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
    
    // Heart rate zone settings ViewModel
    let heartRateViewModel = HeartRateViewModel()

    init() {
        setupHeartRateMonitoring()
        setupAudioManagement()
        setupTrainingManager()
        observeHeartRateSettings()

        print("🚀 AppState initialized – ready to start training session")
    }
    
    private func setupHeartRateMonitoring() {
        hrManager.onNewHeartRate = { [weak self] bpm in
            self?.trainingManager.processHeartRate(bpm)
            VO2MaxTrainingManager.shared.tick(now: Date())
        }
    }
    
    private func setupAudioManagement() {
        announcer.onAnnouncementFinished = { [weak self] in
            guard let self = self else { return }
            self.audioService.restoreMusicVolume(isTrainingSessionActive: self.isSessionActive)
        }
        audioService.delegate = self
    }
    
    private func setupTrainingManager() {
        trainingManager.delegate = self
        updateTrainingManagerSettings()
    }
    
    private func observeHeartRateSettings() {
        // Observe key heart rate settings changes and update training manager
        Publishers.CombineLatest3(
            heartRateViewModel.$restingHR,
            heartRateViewModel.$maxHR, 
            heartRateViewModel.$useAutoZones
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.updateTrainingManagerSettings()
        }
        .store(in: &cancellables)
        
        // Also observe manual zone changes
        Publishers.CombineLatest3(
            heartRateViewModel.$zone1Lower,
            heartRateViewModel.$zone2Upper,
            heartRateViewModel.$zone4Upper
        )
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.updateTrainingManagerSettings()
        }
        .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        audioService.deactivateAudioSession()
    }
    
    private func startHeartRateMonitoring() {
        hrManager.startMonitoring()
        trainingManager.resetSessionState()
        updateTrainingManagerSettings() // Ensure latest settings are applied
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
    
    private func updateTrainingManagerSettings() {
        let settings = heartRateViewModel.getCurrentZoneSettings()
        trainingManager.updateZoneSettings(
            restingHR: settings.restingHR,
            maxHR: settings.maxHR,
            useAutoZones: settings.useAutoZones,
            zone1Lower: settings.manualZones.zone1Lower,
            zone1Upper: settings.manualZones.zone1Upper,
            zone2Upper: settings.manualZones.zone2Upper,
            zone3Upper: settings.manualZones.zone3Upper,
            zone4Upper: settings.manualZones.zone4Upper,
            zone5Upper: settings.manualZones.zone5Upper
        )
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

