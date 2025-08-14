import Foundation
import Combine

protocol HeartRateService {
    var bpmPublisher: AnyPublisher<Int, Never> { get }
    func start()
    func stop()
}


