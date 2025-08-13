//
//  VO2MaxTrainingManager.swift
//  pulseprompt
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
    @Published var totalIntervals = 8 // 4 high-intensity + 4 rest intervals
    
    private var timer: Timer?
    private var spotifyManager = SpotifyManager.shared
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
    
    private let highIntensityDuration: TimeInterval = 4 * 60 // 4 minutes
    private let restDuration: TimeInterval = 3 * 60 // 3 minutes
    
    private init() {}
    
    func startTraining() {
        print("Starting VO2 Max training...")
        print("Spotify connected: \(spotifyManager.isConnected)")
        
        isTraining = true
        currentInterval = 1
        currentPhase = .highIntensity
        intervalState = IntervalState(phase: .highIntensity, start: timeProvider.now(), duration: highIntensityDuration)
        timeRemaining = highIntensityDuration

        // Reset switch guard and start timer immediately for responsive UI (foreground only)
        lastIssuedCommandInterval = nil
        startTimer()
        
        // Activate device and start music in parallel (non-blocking)
        // Always attempt activation; this will authorize if needed and start playback.
        let firstPlaylistID = ConfigurationManager.shared.spotifyHighIntensityPlaylistID
        spotifyManager.activateDeviceForTraining(playlistID: firstPlaylistID) { [weak self] success in
            if success {
                print("✅ Training music started during first interval")
            } else {
                print("ℹ️ Using fallback music control during first interval")
                DispatchQueue.main.async {
                    self?.spotifyManager.playHighIntensityPlaylist()
                }
            }
        }
    }
    
    func pauseTraining() {
        timer?.invalidate()
        timer = nil
        isPaused = true
        pausedAt = timeProvider.now()
        spotifyManager.pause()
    }
    
    func resumeTraining() {
        isPaused = false
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
            spotifyManager.playHighIntensityPlaylist()
        } else if currentPhase == .rest {
            spotifyManager.playRestPlaylist()
        } else {
            // Fallback to basic resume if phase is unexpected
            spotifyManager.resume()
        }
    }
    
    func stopTraining() {
        timer?.invalidate()
        timer = nil
        isTraining = false
        isPaused = false
        currentPhase = .notStarted
        timeRemaining = 0
        currentInterval = 0
        spotifyManager.pause()
        
        // Reset device activation state so next training session can start fresh
        spotifyManager.resetDeviceActivationState()
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
            currentPhase = .highIntensity
            intervalState = IntervalState(phase: .highIntensity, start: timeProvider.now(), duration: highIntensityDuration)
            timeRemaining = highIntensityDuration
            
            // Skip playing playlist for first interval since it should already be playing from device activation
            if currentInterval == 1 {
                print("First high intensity interval - playlist should already be playing from device activation")
            } else {
                print("High intensity interval - attempting to play playlist...")
                switchPlaylistIfNeeded(for: .highIntensity)
            }
        } else {
            currentPhase = .rest
            intervalState = IntervalState(phase: .rest, start: timeProvider.now(), duration: restDuration)
            timeRemaining = restDuration
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
        // Display rounds down, but phase change uses exact remaining to avoid extra 1s of delay
        timeRemaining = floor(remaining)
        print("⏱️ VO2 tick - phase: \(currentPhase) interval: \(currentInterval) elapsed: \(Int(elapsed))s remaining: \(Int(remaining))s")

        if remaining <= 0 {
            currentInterval += 1
            print("🚦 VO2 boundary reached → advancing to interval \(currentInterval)")
            startNextInterval()
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
            spotifyManager.playHighIntensityPlaylist()
        case .rest:
            spotifyManager.playRestPlaylist()
        default:
            break
        }
    }
    
    private func completeTraining() {
        timer?.invalidate()
        timer = nil
        isTraining = false
        currentPhase = .completed
        spotifyManager.pause()
        
        // Reset device activation state so next training session can start fresh
        spotifyManager.resetDeviceActivationState()
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
