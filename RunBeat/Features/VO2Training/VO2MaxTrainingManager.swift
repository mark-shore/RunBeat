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
    
    @Published var isTraining = false
    @Published var isPaused = false
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
    private var pausedAt: Date?
    private var lastIssuedCommandInterval: Int?
    private var timeProvider: TimeProvider = SystemTimeProvider()
    
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
    
    func startTraining() {
        print("Starting VO2 Max training...")
        print("Spotify connected: \(spotifyViewModel.isConnected)")
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isTraining = true
            self.currentInterval = 1
            self.currentPhase = .highIntensity
            self.timeRemaining = self.highIntensityDuration
        }
        
        intervalState = IntervalState(phase: .highIntensity, start: timeProvider.now(), duration: highIntensityDuration)

        // Reset switch guard and start timer immediately for responsive UI (foreground only)
        lastIssuedCommandInterval = nil
        startTimer()
        
        // Activate device and start music in parallel (non-blocking)
        // Always attempt activation; this will authorize if needed and start playback.
        spotifyViewModel.activateDeviceForTraining { [weak self] success in
            if success {
                print("✅ Training music started during first interval")
            } else {
                print("ℹ️ Using fallback music control during first interval")
                DispatchQueue.main.async {
                    self?.spotifyViewModel.playHighIntensityPlaylist()
                }
            }
        }
    }
    
    func pauseTraining() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = true
        }
        pausedAt = timeProvider.now()
        spotifyViewModel.pause()
    }
    
    func resumeTraining() {
        DispatchQueue.main.async { [weak self] in
            self?.isPaused = false
        }
        if let pausedAt = pausedAt, var state = intervalState {
            let delta = timeProvider.now().timeIntervalSince(pausedAt)
            state.start = state.start.addingTimeInterval(delta)
            intervalState = state
            self.pausedAt = nil
        }
        startTimer()
        // Robust resume: if AppRemote/Web API resume fails due to device not active,
        // explicitly start the expected playlist for the current phase.
        if currentPhase == .highIntensity {
            spotifyViewModel.playHighIntensityPlaylist()
        } else if currentPhase == .rest {
            spotifyViewModel.playRestPlaylist()
        } else {
            // Fallback to basic resume if phase is unexpected
            spotifyViewModel.resume()
        }
    }
    
    func stopTraining() {
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isTraining = false
            self?.isPaused = false
            self?.currentPhase = .notStarted
            self?.timeRemaining = 0
            self?.currentInterval = 0
        }
        spotifyViewModel.pause()
        
        // Reset device activation state so next training session can start fresh
        spotifyViewModel.resetDeviceActivationState()
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
        guard isTraining, !isPaused, let state = intervalState else { return }
        let elapsed = max(0, now.timeIntervalSince(state.start))
        let remaining = max(0, state.duration - elapsed)
        
        // Ensure UI updates happen on main thread
        DispatchQueue.main.async { [weak self] in
            // Display rounds down, but phase change uses exact remaining to avoid extra 1s of delay
            self?.timeRemaining = floor(remaining)
        }
        
        print("⏱️ VO2 tick - phase: \(currentPhase) interval: \(currentInterval) elapsed: \(Int(elapsed))s remaining: \(Int(remaining))s")

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
        timer?.invalidate()
        timer = nil
        DispatchQueue.main.async { [weak self] in
            self?.isTraining = false
            self?.currentPhase = .completed
        }
        spotifyViewModel.pause()
        
        // Reset device activation state so next training session can start fresh
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
