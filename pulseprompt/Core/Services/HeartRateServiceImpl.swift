import Foundation
import Combine

final class HeartRateServiceImpl: HeartRateService {
    private let manager: HeartRateManager
    private let subject = PassthroughSubject<Int, Never>()

    init(manager: HeartRateManager = HeartRateManager()) {
        self.manager = manager
        self.manager.onNewHeartRate = { [weak self] bpm in
            self?.subject.send(bpm)
        }
    }

    var bpmPublisher: AnyPublisher<Int, Never> {
        subject.eraseToAnyPublisher()
    }

    func start() {
        manager.startMonitoring()
    }

    func stop() {
        manager.stopMonitoring()
    }
}


