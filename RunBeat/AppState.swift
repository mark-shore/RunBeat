import Foundation
import NotificationCenter
import AVFoundation
import Combine

class AppState: ObservableObject {
    @Published var currentBPM: Int = 0
    @Published var activeTrainingMode: TrainingMode = .none
    
    // Legacy compatibility for existing UI
    var isSessionActive: Bool {
        return activeTrainingMode == .free
    }

    private let hrManager = HeartRateManager()
    private let announcer = SpeechAnnouncer()
    private let audioService = AudioService()
    
    // NEW: Replace HeartRateTrainingManager with FreeTrainingManager
    private let freeTrainingManager = FreeTrainingManager()
    private let vo2TrainingManager = VO2MaxTrainingManager.shared
    
    // Heart rate zone settings ViewModel
    let heartRateViewModel = HeartRateViewModel()

    init() {
        setupHeartRateMonitoring()
        setupAudioManagement()
        setupAnnouncementHandling() // NEW: NotificationCenter observer
        observeHeartRateSettings()

        print("🚀 AppState initialized – ready for dual training mode architecture")
    }
    
    private func setupHeartRateMonitoring() {
        hrManager.onNewHeartRate = { [weak self] bpm in
            DispatchQueue.main.async {
                self?.currentBPM = bpm
            }
            self?.routeHeartRateData(bpm)
        }
    }
    
    private func routeHeartRateData(_ bpm: Int) {
        switch activeTrainingMode {
        case .free:
            freeTrainingManager.processHeartRate(bpm)
        case .vo2Max:
            vo2TrainingManager.processHeartRate(bpm)
            vo2TrainingManager.tick(now: Date())
        case .none:
            break // No training active
        }
    }
    
    private func setupAudioManagement() {
        announcer.onAnnouncementFinished = { [weak self] in
            guard let self = self else { return }
            self.audioService.restoreMusicVolume(isTrainingSessionActive: self.activeTrainingMode != .none)
        }
        audioService.delegate = self
    }
    
    private func setupAnnouncementHandling() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleZoneAnnouncement(_:)),
            name: .announceZone,
            object: nil
        )
    }
    
    @objc private func handleZoneAnnouncement(_ notification: Notification) {
        guard let zone = notification.object as? Int else { return }
        announceZone(zone)
    }
    
    // MARK: - Training Mode Management
    
    func startFreeTraining() {
        guard activeTrainingMode == .none else {
            print("⚠️ Cannot start free training - another mode is active: \(activeTrainingMode)")
            return
        }
        
        activeTrainingMode = .free
        freeTrainingManager.start()
        hrManager.startMonitoring()
        updateZoneSettings()
        print("🏃 Free training mode started")
    }
    
    func stopFreeTraining() {
        guard activeTrainingMode == .free else { return }
        
        freeTrainingManager.stop()
        hrManager.stopMonitoring()
        audioService.deactivateAudioSession()
        activeTrainingMode = .none
        print("⏹️ Free training mode stopped")
    }
    
    func startVO2Training() {
        guard activeTrainingMode == .none else {
            print("⚠️ Cannot start VO2 training - another mode is active: \(activeTrainingMode)")
            return
        }
        
        activeTrainingMode = .vo2Max
        hrManager.startMonitoring()
        updateZoneSettings()
        vo2TrainingManager.startTraining()
        print("🏃 VO2 Max training mode started")
    }
    
    func stopVO2Training() {
        guard activeTrainingMode == .vo2Max else { return }
        
        vo2TrainingManager.stopTraining()
        hrManager.stopMonitoring()
        audioService.deactivateAudioSession()
        activeTrainingMode = .none
        print("⏹️ VO2 Max training mode stopped")
    }
    
    // LEGACY: Keep for backward compatibility during migration
    func startSession() {
        startFreeTraining()
    }
    
    func stopSession() {
        stopFreeTraining()
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
            self?.updateZoneSettings()
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
            self?.updateZoneSettings()
        }
        .store(in: &cancellables)
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        audioService.deactivateAudioSession()
    }
    
    private func announceZone(_ zone: Int) {
        audioService.setupAudioSessionForAnnouncement()
        announcer.announceZone(zone)
        print("🔊 Zone \(zone) announced")
    }
    
    private func updateZoneSettings() {
        let settings = heartRateViewModel.getCurrentZoneSettings()
        
        freeTrainingManager.updateZoneSettings(
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
        
        vo2TrainingManager.updateZoneSettings(
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

// MARK: - AudioServiceDelegate
extension AppState: AudioServiceDelegate {
    func audioServiceDidRestoreMusicVolume() {
        print("🎵 Audio service restored music volume")
    }
}

