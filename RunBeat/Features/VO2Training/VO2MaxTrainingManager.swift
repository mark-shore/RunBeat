//
//  VO2MaxTrainingManager.swift
//  RunBeat
//
//  Created by Mark Shore on 7/25/25.
//

import Foundation
import Combine

class VO2MaxTrainingManager: ObservableObject {
    static let shared = VO2MaxTrainingManager()
    
    // Simplified 3-state model: Setup → Active → Complete
    @Published var trainingState: TrainingState = .setup
    @Published var currentPhase: TrainingPhase = .notStarted
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentInterval = 0
    @Published var totalIntervals = VO2Config.totalIntervals
    
    private var timer: Timer?
    private var spotifyViewModel: SpotifyViewModel
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
        // Initialize with shared SpotifyViewModel for consistent state
        self.spotifyViewModel = SpotifyViewModel.shared
    }
    
    // Dependency injection for testing
    init(spotifyViewModel: SpotifyViewModel, timeProvider: TimeProvider = SystemTimeProvider()) {
        self.spotifyViewModel = spotifyViewModel
        self.timeProvider = timeProvider
    }
    
    // MARK: - Computed Properties
    
    /// Legacy compatibility - maps to trainingState
    var isTraining: Bool {
        return trainingState == .active
    }
    
    func startTraining() {
        print("🏃 Starting VO2 Max training...")
        print("🎵 Spotify connected: \(spotifyViewModel.isConnected)")
        
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
        
        // Check Spotify connection before starting music
        if spotifyViewModel.isConnected {
            print("🎵 Spotify connected - starting music for training")
            
            // Get current track info immediately for responsive UI
            spotifyViewModel.refreshCurrentTrack()
            
            // Start track polling for real-time updates during training
            spotifyViewModel.startTrackPolling()
            
            // Activate device and start music
            spotifyViewModel.activateDeviceForTraining { [weak self] success in
                if success {
                    print("✅ Training music started during first interval")
                } else {
                    print("ℹ️ Using fallback music control during first interval")
                    DispatchQueue.main.async {
                        self?.spotifyViewModel.playHighIntensityPlaylist()
                    }
                }
                
                // Refresh track info again after music starts to capture any changes
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.spotifyViewModel.refreshCurrentTrack()
                }
            }
        } else {
            print("⚠️ Spotify not connected - training will start without music")
            print("⚠️ Music will start automatically once Spotify connects")
        }
    }
    
    /// Stops the training session and returns to setup state
    func stopTraining() {
        print("⏹️ Stopping VO2 Max training...")
        
        timer?.invalidate()
        timer = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trainingState = .setup
            self.currentPhase = .notStarted
            self.timeRemaining = 0
            self.currentInterval = 0
        }
        
        // Stop music and track polling
        spotifyViewModel.pause()
        
        // Get final track state before stopping polling (for display consistency)
        spotifyViewModel.refreshCurrentTrack()
        
        spotifyViewModel.stopTrackPolling()
        
        // Reset device activation state for next training session
        spotifyViewModel.resetDeviceActivationState()
    }
    
    /// Resets the training session to setup state (for completed training)
    func resetToSetup() {
        print("🔄 Resetting training to setup state...")
        
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
    }
    
    private func startNextInterval() {
        print("Starting next interval: \(currentInterval)")
        
        if currentInterval > totalIntervals {
            completeTraining()
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
                print("First high intensity interval - playlist should already be playing from device activation")
            } else {
                print("High intensity interval - attempting to play playlist...")
                switchPlaylistIfNeeded(for: .highIntensity)
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.currentPhase = .rest
                self?.timeRemaining = self?.restDuration ?? 0
            }
            intervalState = IntervalState(phase: .rest, start: timeProvider.now(), duration: restDuration)
            print("Rest interval - attempting to play playlist...")
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
        
        if currentInterval <= totalIntervals {
            print("⏱️ VO2 tick - phase: \(currentPhase) interval: \(currentInterval) elapsed: \(Int(elapsed))s remaining: \(Int(remaining))s")
        }

        if remaining <= 0 {
            DispatchQueue.main.async { [weak self] in
                self?.currentInterval += 1
                print("🚦 VO2 boundary reached → advancing to interval \(self?.currentInterval ?? 0)")
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
            spotifyViewModel.playHighIntensityPlaylist()
        case .rest:
            spotifyViewModel.playRestPlaylist()
        default:
            break
        }
    }
    
    private func completeTraining() {
        print("🎉 VO2 Max training completed!")
        
        timer?.invalidate()
        timer = nil
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.trainingState = .complete
            self.currentPhase = .completed
            self.timeRemaining = 0
        }
        
        // Stop music and track polling
        spotifyViewModel.pause()
        spotifyViewModel.stopTrackPolling()
        
        // Reset device activation state for next training session
        spotifyViewModel.resetDeviceActivationState()
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
}
