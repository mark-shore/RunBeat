import AVFoundation

class SpeechAnnouncer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var onAnnouncementFinished: (() -> Void)?

    override init() {
        super.init()
        print("🔧 SpeechAnnouncer initialized")
    }

    func announceZone(_ zone: Int?) {
        guard let zone = zone else { return }

        guard let url = Bundle.main.url(forResource: "zone\(zone)", withExtension: "mp3") else {
            print("Audio file for zone\(zone) not found")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = 1.0 // Full volume for announcements
            player?.prepareToPlay()
            player?.play()
            print("🔊 Playing zone \(zone) announcement (music will duck)")
        } catch {
            print("Failed to play audio for zone\(zone): \(error)")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 Zone announcement finished")
        onAnnouncementFinished?()
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            print("❌ Audio player decode error: \(error.localizedDescription)")
        }
    }
}
