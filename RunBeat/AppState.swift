import Foundation
import NotificationCenter
import AVFoundation
import Combine

class AppState: ObservableObject {
    @Published var currentBPM: Int = 0
    
    // VO2 Training UI State - Bridged from VO2MaxTrainingManager
    @Published var vo2TimeRemaining: TimeInterval = 0
    @Published var vo2CurrentPhase: VO2MaxTrainingManager.TrainingPhase = .notStarted
    @Published var vo2CurrentInterval: Int = 0
    @Published var vo2TotalIntervals: Int = 4
    @Published var vo2TrainingState: VO2MaxTrainingManager.TrainingState = .setup
    
    // VO2 Training Computed Properties - Clean interface for UI
    var vo2FormattedTimeRemaining: String {
        let minutes = Int(vo2TimeRemaining) / 60
        let seconds = Int(vo2TimeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var vo2PhaseDescription: String {
        switch vo2CurrentPhase {
        case .notStarted:
            return "Ready to Start"
        case .highIntensity:
            return "High Intensity"
        case .rest:
            return "Rest"
        case .completed:
            return "Training Complete!"
        }
    }
    
    var vo2ProgressPercentage: Double {
        guard vo2TotalIntervals > 0 else { return 0.0 }
        return Double(vo2CurrentInterval - 1) / Double(vo2TotalIntervals)
    }
    
    // Legacy compatibility for existing UI
    var isSessionActive: Bool {
        return intentCoordinator.isTrainingSession
    }

    // Intent-based coordination - single source of truth for app state
    private let intentCoordinator = IntentCoordinator.shared

    let hrManager = HeartRateManager()
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
        observeVO2TrainingUpdates() // NEW: Bridge VO2 training UI state

        AppLogger.info("AppState initialized with intent-based architecture", component: "AppState")
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
        Task { @MainActor in
            let currentIntent = intentCoordinator.currentIntent
            switch currentIntent {
            case .freeActive, .freeSetup, .freeComplete:
                freeTrainingManager.processHeartRate(bpm)
            case .vo2Active, .vo2Setup, .vo2Complete:
                vo2TrainingManager.processHeartRate(bpm)
                vo2TrainingManager.tick(now: Date())
            case .idle:
                break // No training active
            }
        }
    }
    
    private func setupAudioManagement() {
        announcer.onAnnouncementFinished = { [weak self] in
            guard let self = self else { return }
            self.audioService.restoreMusicVolume(isTrainingSessionActive: self.intentCoordinator.isTrainingSession)
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
        // First set intent to Free setup mode
        intentCoordinator.startFreeSetup()

        // Start heart rate monitoring and configure settings
        hrManager.startMonitoring()
        Task { @MainActor in
            updateZoneSettings()

            // Now transition to active Free training
            intentCoordinator.startFreeTraining()
            freeTrainingManager.start()
        }
    }
    
    func stopFreeTraining() {
        guard intentCoordinator.isFreeTraining else { return }

        Task { @MainActor in
            freeTrainingManager.stop()
        }
        hrManager.stopMonitoring()
        audioService.deactivateAudioSession()
        intentCoordinator.endTraining()
    }
    
    func startVO2Training() {
        // Handle restart from complete state
        if intentCoordinator.isVO2Training && vo2TrainingState == .complete {
            Task { @MainActor in
                vo2TrainingManager.resetToSetup()
                intentCoordinator.startVO2Training()
                vo2TrainingManager.startTraining()
            }
            return
        }

        // First set intent to VO2 setup mode
        intentCoordinator.startVO2Setup()

        // Start heart rate monitoring and configure settings
        hrManager.startMonitoring()
        Task { @MainActor in
            updateZoneSettings()

            // Now transition to active VO2 training
            intentCoordinator.startVO2Training()
            vo2TrainingManager.startTraining()
        }
    }
    
    func stopVO2Training() {
        guard intentCoordinator.isVO2Training else { return }

        Task { @MainActor in
            vo2TrainingManager.endTraining()
        }
        hrManager.stopMonitoring()
        audioService.deactivateAudioSession()
        intentCoordinator.endTraining()
    }
    
    /// Simplified cleanup method for consistent termination
    func cleanupVO2Training() {
        if intentCoordinator.isVO2Training {
            intentCoordinator.endTraining()
        }
    }
    
    /// Dismisses VO2 completion screen and returns to setup
    func dismissVO2CompletionScreen() {
        Task { @MainActor in
            vo2TrainingManager.dismissCompletionScreen()
        }
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
            Task { @MainActor [weak self] in
                self?.updateZoneSettings()
            }
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
            Task { @MainActor [weak self] in
                self?.updateZoneSettings()
            }
        }
        .store(in: &cancellables)
    }
    
    private func observeVO2TrainingUpdates() {
        // Bridge all VO2 training UI state from manager to AppState
        vo2TrainingManager.$timeRemaining
            .receive(on: DispatchQueue.main)
            .assign(to: \.vo2TimeRemaining, on: self)
            .store(in: &cancellables)
            
        vo2TrainingManager.$currentPhase
            .receive(on: DispatchQueue.main)
            .assign(to: \.vo2CurrentPhase, on: self)
            .store(in: &cancellables)
            
        vo2TrainingManager.$currentInterval
            .receive(on: DispatchQueue.main)
            .assign(to: \.vo2CurrentInterval, on: self)
            .store(in: &cancellables)
            
        vo2TrainingManager.$totalIntervals
            .receive(on: DispatchQueue.main)
            .assign(to: \.vo2TotalIntervals, on: self)
            .store(in: &cancellables)
            
        vo2TrainingManager.$trainingState
            .receive(on: DispatchQueue.main)
            .assign(to: \.vo2TrainingState, on: self)
            .store(in: &cancellables)
            
        AppLogger.debug("VO2 training state bridging established", component: "AppState")
    }
    
    private var cancellables = Set<AnyCancellable>()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        audioService.deactivateAudioSession()
    }
    
    private func announceZone(_ zone: Int) {
        audioService.setupAudioSessionForAnnouncement()
        announcer.announceZone(zone)
        AppLogger.debug("Zone \(zone) announced", component: "AppState")
    }
    
    @MainActor
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
        AppLogger.debug("Audio service restored music volume", component: "AppState")
    }
}

