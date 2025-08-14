import Foundation

final class SpeechServiceImpl: SpeechService {
    private let announcer = SpeechAnnouncer()
    var onAnnouncementFinished: (() -> Void)? {
        get { announcer.onAnnouncementFinished }
        set { announcer.onAnnouncementFinished = newValue }
    }

    func announceZone(_ zone: Int?) {
        announcer.announceZone(zone)
    }
}


