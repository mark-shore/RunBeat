import Foundation
import Combine

@MainActor
final class VO2MaxTrainingViewModel: ObservableObject {
    // Exposed UI state
    @Published var isTraining: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentPhase: VO2MaxTrainingManager.TrainingPhase = .notStarted
    @Published var timeRemaining: TimeInterval = 0
    @Published var currentInterval: Int = 0
    @Published var totalIntervals: Int = 0
    @Published var isSpotifyConnected: Bool = false
    @Published var currentTrack: String = ""

    private let manager: VO2MaxTrainingManager
    private let spotify: SpotifyManager
    private var cancellables: Set<AnyCancellable> = []

    init(manager: VO2MaxTrainingManager = .shared, spotify: SpotifyManager = .shared) {
        self.manager = manager
        self.spotify = spotify
        bind()
    }

    private func bind() {
        manager.$isTraining.assign(to: &$isTraining)
        manager.$isPaused.assign(to: &$isPaused)
        manager.$currentPhase.assign(to: &$currentPhase)
        manager.$timeRemaining.assign(to: &$timeRemaining)
        manager.$currentInterval.assign(to: &$currentInterval)
        manager.$totalIntervals.assign(to: &$totalIntervals)

        spotify.$isConnected.assign(to: &$isSpotifyConnected)
        spotify.$currentTrack.assign(to: &$currentTrack)
    }

    // MARK: - Computed values passthrough
    func formattedTimeRemaining() -> String { manager.formattedTimeRemaining() }
    func getPhaseDescription() -> String { manager.getPhaseDescription() }
    func getProgressPercentage() -> Double { manager.getProgressPercentage() }

    // MARK: - Actions
    func startTraining() { manager.startTraining() }
    func pauseTraining() { manager.pauseTraining() }
    func resumeTraining() { manager.resumeTraining() }
    func stopTraining() { manager.stopTraining() }

    func connectSpotify() { spotify.connect() }
}


