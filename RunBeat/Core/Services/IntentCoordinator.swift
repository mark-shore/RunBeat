//
//  IntentCoordinator.swift
//  RunBeat
//
//  Created by Claude on 9/19/25.
//
//  Central coordinator for app-wide intent state management
//  Replaces distributed Boolean state checks with unified intent coordination
//

import Foundation
import UIKit
import Combine

/// Central coordinator that manages app-wide intent state
/// Services observe this coordinator for intent changes instead of checking multiple Boolean flags
class IntentCoordinator: ObservableObject {

    // MARK: - Singleton

    static let shared = IntentCoordinator()

    // MARK: - Published State

    /// Current app intent - the single source of truth for app behavior coordination
    @Published var currentIntent: AppIntent = .idle(inForeground: true)

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let intentQueue = DispatchQueue(label: "intent.coordinator", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        setupAppLifecycleObservation()
        AppLogger.info("IntentCoordinator initialized with intent: \(currentIntent.description)", component: "Intent")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Intent Management

    /// Sets a new app intent and notifies all observers
    /// Thread-safe and logs all intent transitions for debugging
    func setIntent(_ newIntent: AppIntent) {
        intentQueue.async { [weak self] in
            guard let self = self else { return }

            let oldIntent = self.currentIntent

            // Validate intent transition if needed
            guard self.isValidTransition(from: oldIntent, to: newIntent) else {
                AppLogger.warn("Invalid intent transition from \(oldIntent.description) to \(newIntent.description)", component: "Intent")
                return
            }

            DispatchQueue.main.async {
                self.currentIntent = newIntent
                AppLogger.info("Intent transition: \(oldIntent.description) → \(newIntent.description)", component: "Intent")

                // Log important intent changes for debugging
                if oldIntent.isTraining != newIntent.isTraining {
                    AppLogger.info("Training state changed: \(oldIntent.isTraining) → \(newIntent.isTraining)", component: "Intent")
                }

                if oldIntent.isVO2Training != newIntent.isVO2Training || oldIntent.isFreeTraining != newIntent.isFreeTraining {
                    let oldMode = oldIntent.isVO2Training ? "VO2" : (oldIntent.isFreeTraining ? "Free" : "None")
                    let newMode = newIntent.isVO2Training ? "VO2" : (newIntent.isFreeTraining ? "Free" : "None")
                    AppLogger.info("Training mode changed: \(oldMode) → \(newMode)", component: "Intent")
                }
            }
        }
    }

    /// Updates only the foreground state while preserving training state
    /// Useful for app lifecycle transitions
    func updateForegroundState(_ inForeground: Bool) {
        let newIntent = currentIntent.withForegroundState(inForeground)

        // Only update if foreground state actually changed
        guard newIntent != currentIntent else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentIntent = newIntent
            AppLogger.debug("Foreground state updated: \(inForeground ? "foreground" : "background")", component: "Intent")
        }
    }

    // MARK: - Training Transition Helpers

    /// Starts VO2 Max training setup phase
    func startVO2Setup() {
        guard !currentIntent.isTrainingSession else {
            AppLogger.warn("Cannot start VO2 setup - training already active: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.vo2Setup(inForeground: currentIntent.inForeground))
    }

    /// Transitions from VO2 setup to active training
    func startVO2Training() {
        guard currentIntent.isVO2Training else {
            AppLogger.warn("Cannot start VO2 training - not in VO2 mode: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.vo2Active(inForeground: currentIntent.inForeground))
    }

    /// Completes VO2 training and shows results
    func completeVO2Training() {
        guard case .vo2Active = currentIntent else {
            AppLogger.warn("Cannot complete VO2 training - not actively training: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.vo2Complete(inForeground: currentIntent.inForeground))
    }

    /// Starts Free training setup phase
    func startFreeSetup() {
        guard !currentIntent.isTrainingSession else {
            AppLogger.warn("Cannot start Free setup - training already active: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.freeSetup(inForeground: currentIntent.inForeground))
    }

    /// Transitions from Free setup to active training
    func startFreeTraining() {
        guard currentIntent.isFreeTraining else {
            AppLogger.warn("Cannot start Free training - not in Free mode: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.freeActive(inForeground: currentIntent.inForeground))
    }

    /// Completes Free training
    func completeFreeTraining() {
        guard case .freeActive = currentIntent else {
            AppLogger.warn("Cannot complete Free training - not actively training: \(currentIntent.description)", component: "Intent")
            return
        }
        setIntent(.freeComplete(inForeground: currentIntent.inForeground))
    }

    /// Ends any training session and returns to idle
    func endTraining() {
        guard currentIntent.isTrainingSession else {
            AppLogger.debug("No training session to end - already idle", component: "Intent")
            return
        }
        setIntent(.idle(inForeground: currentIntent.inForeground))
    }

    /// Force returns to idle state (for error recovery)
    func resetToIdle() {
        setIntent(.idle(inForeground: currentIntent.inForeground))
        AppLogger.info("Intent reset to idle", component: "Intent")
    }

    // MARK: - Convenience Getters

    /// Returns true if any training mode is currently active
    var isTraining: Bool {
        currentIntent.isTraining
    }

    /// Returns true if in any training session (including setup/complete)
    var isTrainingSession: Bool {
        currentIntent.isTrainingSession
    }

    /// Returns true if in VO2 Max training mode
    var isVO2Training: Bool {
        currentIntent.isVO2Training
    }

    /// Returns true if in Free training mode
    var isFreeTraining: Bool {
        currentIntent.isFreeTraining
    }

    /// Returns current training phase if in training, nil if idle
    var trainingPhase: AppIntent.TrainingPhase? {
        currentIntent.trainingPhase
    }


    /// Returns true if app is currently in foreground
    var inForeground: Bool {
        currentIntent.inForeground
    }

    // MARK: - App Lifecycle Management

    private func setupAppLifecycleObservation() {
        // Observe app entering foreground
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateForegroundState(true)
            }
            .store(in: &cancellables)

        // Observe app entering background
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateForegroundState(false)
            }
            .store(in: &cancellables)

        AppLogger.debug("App lifecycle observation setup complete", component: "Intent")
    }

    // MARK: - Intent Validation

    /// Validates intent transitions to prevent invalid state changes
    private func isValidTransition(from oldIntent: AppIntent, to newIntent: AppIntent) -> Bool {
        // Prevent switching training modes without going through idle
        if oldIntent.isVO2Training && newIntent.isFreeTraining {
            return false
        }

        if oldIntent.isFreeTraining && newIntent.isVO2Training {
            return false
        }

        return true
    }

    // MARK: - Debug Helpers

    /// Returns detailed debug information about current intent state
    var debugDescription: String {
        let trainingMode = currentIntent.isVO2Training ? "VO2" : (currentIntent.isFreeTraining ? "Free" : "None")
        let phaseString: String
        if let phase = trainingPhase {
            switch phase {
            case .setup: phaseString = "setup"
            case .active: phaseString = "active"
            case .complete: phaseString = "complete"
            }
        } else {
            phaseString = "none"
        }

        return """
        IntentCoordinator State:
        - Current Intent: \(currentIntent.description)
        - Is Training: \(isTraining)
        - Training Mode: \(trainingMode)
        - Training Phase: \(phaseString)
        - In Foreground: \(inForeground)
        """
    }
}