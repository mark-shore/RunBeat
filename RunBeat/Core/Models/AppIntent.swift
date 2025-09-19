//
//  AppIntent.swift
//  RunBeat
//
//  Created by Claude on 9/19/25.
//
//  Unified intent-based architecture for coordinating all app services
//

import Foundation

/// Central intent enum that coordinates behavior across all app services
/// Replaces distributed Boolean state management with unified intent declarations
enum AppIntent: Equatable {
    // MARK: - Intent Cases

    /// App is idle - no training active, minimal background activity
    case idle(inForeground: Bool)

    /// VO2 Max training in setup phase - selecting playlists, configuring settings
    case vo2Setup(inForeground: Bool)

    /// VO2 Max training actively running - intervals, HR monitoring, music control
    case vo2Active(inForeground: Bool)

    /// VO2 Max training completed - showing results, music continues
    case vo2Complete(inForeground: Bool)

    /// Free training in setup phase - ready to start monitoring
    case freeSetup(inForeground: Bool)

    /// Free training actively running - continuous HR monitoring with announcements
    case freeActive(inForeground: Bool)

    /// Free training completed - session ended, cleanup in progress
    case freeComplete(inForeground: Bool)

    // MARK: - Training Phase Enum

    enum TrainingPhase {
        case setup
        case active
        case complete
    }

    // MARK: - Computed Properties

    /// Returns true if any training mode is currently active (not setup/complete)
    var isTraining: Bool {
        switch self {
        case .vo2Active, .freeActive:
            return true
        case .idle, .vo2Setup, .vo2Complete, .freeSetup, .freeComplete:
            return false
        }
    }

    /// Returns true if in any VO2 Max training state
    var isVO2Training: Bool {
        switch self {
        case .vo2Setup, .vo2Active, .vo2Complete:
            return true
        case .idle, .freeSetup, .freeActive, .freeComplete:
            return false
        }
    }

    /// Returns true if in any Free training state
    var isFreeTraining: Bool {
        switch self {
        case .freeSetup, .freeActive, .freeComplete:
            return true
        case .idle, .vo2Setup, .vo2Active, .vo2Complete:
            return false
        }
    }

    /// Extracts the foreground state from the associated value
    var inForeground: Bool {
        switch self {
        case .idle(let foreground),
             .vo2Setup(let foreground),
             .vo2Active(let foreground),
             .vo2Complete(let foreground),
             .freeSetup(let foreground),
             .freeActive(let foreground),
             .freeComplete(let foreground):
            return foreground
        }
    }

    /// Returns the current training phase if in a training state, nil if idle
    var trainingPhase: TrainingPhase? {
        switch self {
        case .vo2Setup, .freeSetup:
            return .setup
        case .vo2Active, .freeActive:
            return .active
        case .vo2Complete, .freeComplete:
            return .complete
        case .idle:
            return nil
        }
    }

    /// Returns true if the intent represents any kind of setup state
    var isSetup: Bool {
        switch self {
        case .vo2Setup, .freeSetup:
            return true
        case .idle, .vo2Active, .vo2Complete, .freeActive, .freeComplete:
            return false
        }
    }

    /// Returns true if the intent represents any kind of completion state
    var isComplete: Bool {
        switch self {
        case .vo2Complete, .freeComplete:
            return true
        case .idle, .vo2Setup, .vo2Active, .freeSetup, .freeActive:
            return false
        }
    }

    /// Returns true if any training session is in progress (setup, active, or complete)
    var isTrainingSession: Bool {
        switch self {
        case .vo2Setup, .vo2Active, .vo2Complete, .freeSetup, .freeActive, .freeComplete:
            return true
        case .idle:
            return false
        }
    }

    // MARK: - Convenience Methods

    /// Returns a new intent with updated foreground state
    /// Useful for app lifecycle transitions without changing training state
    func withForegroundState(_ foreground: Bool) -> AppIntent {
        switch self {
        case .idle:
            return .idle(inForeground: foreground)
        case .vo2Setup:
            return .vo2Setup(inForeground: foreground)
        case .vo2Active:
            return .vo2Active(inForeground: foreground)
        case .vo2Complete:
            return .vo2Complete(inForeground: foreground)
        case .freeSetup:
            return .freeSetup(inForeground: foreground)
        case .freeActive:
            return .freeActive(inForeground: foreground)
        case .freeComplete:
            return .freeComplete(inForeground: foreground)
        }
    }


    // MARK: - Description

    /// Human-readable description for debugging and logging
    var description: String {
        let foregroundState = inForeground ? "foreground" : "background"
        switch self {
        case .idle:
            return "idle(\(foregroundState))"
        case .vo2Setup:
            return "vo2Setup(\(foregroundState))"
        case .vo2Active:
            return "vo2Active(\(foregroundState))"
        case .vo2Complete:
            return "vo2Complete(\(foregroundState))"
        case .freeSetup:
            return "freeSetup(\(foregroundState))"
        case .freeActive:
            return "freeActive(\(foregroundState))"
        case .freeComplete:
            return "freeComplete(\(foregroundState))"
        }
    }
}

