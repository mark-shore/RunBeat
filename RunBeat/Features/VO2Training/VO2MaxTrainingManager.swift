//
//  VO2MaxTrainingManager.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import Foundation

class VO2MaxTrainingManager: ObservableObject {
    static let shared = VO2MaxTrainingManager()
    
    // Simplified 3-state model: Setup → Active → Complete
    @Published var trainingState: TrainingState = .setup
    @Published var currentPhase: TrainingPhase = .notStarted
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentInterval = 0
    @Published var totalIntervals = VO2Config.totalIntervals
    @Published var showingCompletionScreen: Bool = false
    
    private var timer: Timer?
    private var musicViewModel: MusicViewModel
    
    // NEW: Shared services for HR processing and announcements
    private let announcements = ZoneAnnouncementCoordinator()
    private struct IntervalState {
        var phase: TrainingPhase
        var start: Date
        var duration: TimeInterval
    }

    private var intervalState: IntervalState?
    private var lastIssuedCommandInterval: Int?
    private var timeProvider: TimeProvider = SystemTimeProvider()
    
    enum TrainingState {
        case setup      // Ready to start - show playlists and start button
        case active     // Training in progress - show timer and stop button only
        case complete   // Finished - show summary and restart button
    }
    
    enum TrainingPhase {
        case notStarted
        case highIntensity
        case rest
        case completed
    }
    
    private let highIntensityDuration: TimeInterval = VO2Config.highIntensityDuration
    private let restDuration: TimeInterval = VO2Config.restDuration
    
    private init() {
        self.musicViewModel = MusicViewModel.shared
        self.announcements.delegate = self
    }
    
    // MARK: - Computed Properties
    
    /// Legacy compatibility - maps to trainingState
    var isTraining: Bool {
        return trainingState == .active
    }
    
    
    @MainActor
    func startTraining() {
        AppLogger.info("Starting VO2 Max training", component: "VO2Training")

        // Reset HR services
        HeartRateService.shared.resetState()
        announcements.resetState()

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trainingState = .active
            self.currentInterval = 1
            self.currentPhase = .highIntensity
            self.timeRemaining = self.highIntensityDuration
        }

        intervalState = IntervalState(phase: .highIntensity, start: timeProvider.now(), duration: highIntensityDuration)

        // Reset switch guard and start timer immediately for responsive UI (foreground only)
        lastIssuedCommandInterval = nil
        startTimer()

        // Start high intensity music if playlists are configured
        if musicViewModel.hasPlaylistsConfigured {
            AppLogger.info("Starting high intensity playlist", component: "VO2Training")
            musicViewModel.playHighIntensityMusic()
        } else {
            AppLogger.warn("No playlists configured - training will run without music", component: "VO2Training")
        }
    }
    
    /// Ends the training session and shows completion screen
    @MainActor
    func endTraining() {
        AppLogger.info("Ending VO2 Max training", component: "VO2Training")

        timer?.invalidate()
        timer = nil

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trainingState = .complete
            self.showingCompletionScreen = true
            self.currentPhase = .completed
            self.timeRemaining = 0
        }

        // Reset services
        HeartRateService.shared.resetState()
        announcements.resetState()
    }
    
    /// Legacy compatibility - calls endTraining()
    @MainActor
    func stopTraining() {
        endTraining()
    }
    
    /// Dismisses completion screen and returns to setup state
    @MainActor
    func dismissCompletionScreen() {
        AppLogger.info("Dismissing completion screen, returning to setup", component: "VO2Training")

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.showingCompletionScreen = false
            self.trainingState = .setup
            self.currentPhase = .notStarted
            self.currentInterval = 0
        }
    }
    
    /// Resets the training session to setup state (for completed training)
    @MainActor
    func resetToSetup() {
        AppLogger.info("Resetting training to setup state", component: "VO2Training")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trainingState = .setup
            self.currentPhase = .notStarted
            self.timeRemaining = 0
            self.currentInterval = 0
        }
        
        // Clean up any remaining state
        lastIssuedCommandInterval = nil
        intervalState = nil
        
        // NEW: Reset services  
        HeartRateService.shared.resetState()
        announcements.resetState()
    }
    
    @MainActor
    private func startNextInterval() {
        AppLogger.debug("Starting next interval: \(currentInterval)", component: "VO2Training")

        if currentInterval > totalIntervals {
            AppLogger.info("VO2 Max training completed!", component: "VO2Training")
            endTraining()
            return
        }

        // Determine if this is a high-intensity or rest interval
        let isHighIntensity = currentInterval % 2 == 1 // Odd intervals are high-intensity

        if isHighIntensity {
            DispatchQueue.main.async { [weak self] in
                self?.currentPhase = .highIntensity
                self?.timeRemaining = self?.highIntensityDuration ?? 0
            }
            intervalState = IntervalState(phase: .highIntensity, start: timeProvider.now(), duration: highIntensityDuration)

            // Skip playing playlist for first interval since it should already be playing from device activation
            if currentInterval == 1 {
                AppLogger.debug("First high intensity interval - playlist already playing", component: "VO2Training")
            } else {
                AppLogger.debug("High intensity interval - switching playlist", component: "VO2Training")
                switchPlaylistIfNeeded(for: .highIntensity)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentPhase = .rest
                self?.timeRemaining = self?.restDuration ?? 0
            }
            intervalState = IntervalState(phase: .rest, start: timeProvider.now(), duration: restDuration)
            AppLogger.debug("Rest interval - switching playlist", component: "VO2Training")
            switchPlaylistIfNeeded(for: .rest)
        }
        
        startTimer()
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateTimer()
        }
    }
    
    private func updateTimer() {
        updateTimerUsingWallClock(now: timeProvider.now())
    }

    private func updateTimerUsingWallClock(now: Date) {
        guard trainingState == .active, let state = intervalState else { return }
        let elapsed = max(0, now.timeIntervalSince(state.start))
        let remaining = max(0, state.duration - elapsed)
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            // Display rounds down, but phase change uses exact remaining to avoid extra 1s of delay
            self?.timeRemaining = floor(remaining)
        }

        if remaining <= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.currentInterval += 1
                AppLogger.debug("VO2 boundary reached → advancing to interval \(self?.currentInterval ?? 0)", component: "VO2Training")
                self?.startNextInterval()
            }
        }
    }

    // Public tick for background event drivers (e.g., HR updates)
    func tick(now: Date = Date()) {
        updateTimerUsingWallClock(now: now)
    }

    private func switchPlaylistIfNeeded(for phase: TrainingPhase) {
        guard lastIssuedCommandInterval != currentInterval else { return }
        lastIssuedCommandInterval = currentInterval
        switch phase {
        case .highIntensity:
            AppLogger.info("Switching to high intensity playlist", component: "VO2Training")
            musicViewModel.playHighIntensityMusic()
        case .rest:
            AppLogger.info("Switching to rest playlist", component: "VO2Training")
            musicViewModel.playRestMusic()
        default:
            break
        }
    }
    
    
    // MARK: - Helper Methods
    
    func formattedTimeRemaining() -> String {
        let minutes = Int(timeRemaining) / 60
        let seconds = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    func getPhaseDescription() -> String {
        switch currentPhase {
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
    
    func getProgressPercentage() -> Double {
        return Double(currentInterval - 1) / Double(totalIntervals)
    }
    
    // MARK: - Heart Rate Processing
    
    /// NEW: Heart rate processing using shared service
    @MainActor
    func processHeartRate(_ bpm: Int) {
        let result = HeartRateService.shared.processHeartRate(bpm)
        
        if let newZone = result.currentZone, result.didChangeZone {
            announcements.handleZoneChange(newZone, from: result.oldZone, for: .vo2Max)
        }
    }
    
    /// NEW: Announcement controls
    func setAnnouncementsEnabled(_ enabled: Bool) {
        announcements.setAnnouncementsEnabled(enabled, for: .vo2Max)
    }
    
    /// NEW: Zone settings management
    @MainActor
    func updateZoneSettings(restingHR: Int, maxHR: Int, useAutoZones: Bool, 
                          zone1Lower: Int = 60, zone1Upper: Int = 70, 
                          zone2Upper: Int = 80, zone3Upper: Int = 90, 
                          zone4Upper: Int = 100, zone5Upper: Int = 110) {
        HeartRateService.shared.updateZoneSettings(
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
    
    /// NEW: Get current HR zone
    @MainActor
    func getCurrentZone() -> Int? {
        return HeartRateService.shared.getCurrentZone()
    }
    
}

// MARK: - ZoneAnnouncementDelegate
extension VO2MaxTrainingManager: ZoneAnnouncementDelegate {
    func announceZone(_ zone: Int) {
        NotificationCenter.default.post(name: .announceZone, object: zone)
        AppLogger.debug("VO2 Max training requesting zone \(zone) announcement", component: "VO2Training")
    }
}
