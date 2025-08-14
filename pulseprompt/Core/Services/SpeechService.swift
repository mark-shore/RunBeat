import Foundation

protocol SpeechService {
    func announceZone(_ zone: Int?)
    var onAnnouncementFinished: (() -> Void)? { get set }
}


