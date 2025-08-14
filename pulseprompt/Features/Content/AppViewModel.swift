import Foundation
import Combine

@MainActor
final class AppViewModel: ObservableObject {
    // Mirrored state from AppState (temporary bridging while migrating)
    @Published var isSessionActive: Bool = false
    @Published var restingHR: Int = 60
    @Published var maxHR: Int = 190
    @Published var useAutoZones: Bool = true
    @Published var zone1Lower: Int = 60
    @Published var zone1Upper: Int = 70
    @Published var zone2Upper: Int = 80
    @Published var zone3Upper: Int = 90
    @Published var zone4Upper: Int = 100
    @Published var zone5Upper: Int = 110

    let appState: AppState
    private var cancellables: Set<AnyCancellable> = []

    init(appState: AppState = AppState()) {
        self.appState = appState
        bindToAppState()
    }

    private func bindToAppState() {
        appState.$isSessionActive.assign(to: &$isSessionActive)
        appState.$restingHR.assign(to: &$restingHR)
        appState.$maxHR.assign(to: &$maxHR)
        appState.$useAutoZones.assign(to: &$useAutoZones)
        appState.$zone1Lower.assign(to: &$zone1Lower)
        appState.$zone1Upper.assign(to: &$zone1Upper)
        appState.$zone2Upper.assign(to: &$zone2Upper)
        appState.$zone3Upper.assign(to: &$zone3Upper)
        appState.$zone4Upper.assign(to: &$zone4Upper)
        appState.$zone5Upper.assign(to: &$zone5Upper)
    }

    // MARK: - Actions (forward to AppState for now)
    func startSession() {
        appState.startSession()
    }

    func stopSession() {
        appState.stopSession()
    }

    func saveZoneSettings() {
        appState.saveZoneSettings()
    }
}


