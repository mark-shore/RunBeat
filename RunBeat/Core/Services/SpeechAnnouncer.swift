import AVFoundation

class SpeechAnnouncer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    var onAnnouncementFinished: (() -> Void)?

    override init() {
        super.init()
        AppLogger.debug("SpeechAnnouncer initialized", component: "Announcer")

        // Pre-warm AVAudioPlayer by loading a zone file
        // This eliminates 4-5 second delay on first announcement
        prewarmAudioPlayer()
    }

    private func prewarmAudioPlayer() {
        let startTime = CFAbsoluteTimeGetCurrent()
        AppLogger.debug("Pre-warming AVAudioPlayer...", component: "Announcer")

        // Load zone1 file to initialize the audio subsystem
        guard let url = Bundle.main.url(forResource: "zone1", withExtension: "mp3") else {
            AppLogger.warn("Could not find zone1.mp3 for pre-warming", component: "Announcer")
            return
        }

        do {
            let warmupPlayer = try AVAudioPlayer(contentsOf: url)
            warmupPlayer.prepareToPlay()
            let duration = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
            AppLogger.info("AVAudioPlayer pre-warmed in \(String(format: "%.1f", duration))ms", component: "Announcer")
        } catch {
            AppLogger.error("Failed to pre-warm AVAudioPlayer: \(error)", component: "Announcer")
        }
    }

    func announceZone(_ zone: Int?) {
        let announceStartTime = CFAbsoluteTimeGetCurrent()
        AppLogger.verbose("announceZone(\(zone ?? -1)) called", component: "Announcer")

        guard let zone = zone else { return }

        guard let url = Bundle.main.url(forResource: "zone\(zone)", withExtension: "mp3") else {
            AppLogger.error("Audio file for zone\(zone) not found", component: "Announcer")
            return
        }

        do {
            let loadStartTime = CFAbsoluteTimeGetCurrent()

            // Audio session should already be configured with .mixWithOthers and .duckOthers
            // by MusicKitService or AudioService - just play the announcement
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.volume = 1.0 // Full volume for announcements

            let loadDuration = (CFAbsoluteTimeGetCurrent() - loadStartTime) * 1000
            AppLogger.verbose("AVAudioPlayer loaded in \(String(format: "%.1f", loadDuration))ms", component: "Announcer")

            let prepareStartTime = CFAbsoluteTimeGetCurrent()
            player?.prepareToPlay()
            let prepareDuration = (CFAbsoluteTimeGetCurrent() - prepareStartTime) * 1000
            AppLogger.verbose("prepareToPlay() took \(String(format: "%.1f", prepareDuration))ms", component: "Announcer")

            let playStartTime = CFAbsoluteTimeGetCurrent()
            player?.play()
            let playDuration = (CFAbsoluteTimeGetCurrent() - playStartTime) * 1000
            AppLogger.verbose("play() took \(String(format: "%.1f", playDuration))ms", component: "Announcer")

            let totalDuration = (CFAbsoluteTimeGetCurrent() - announceStartTime) * 1000
            AppLogger.info("Zone \(zone) announcement started (total: \(String(format: "%.1f", totalDuration))ms)", component: "Announcer")
        } catch {
            AppLogger.error("Failed to play audio for zone\(zone): \(error)", component: "Announcer")
        }
    }
    
    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        AppLogger.debug("Zone announcement finished", component: "Announcer")
        onAnnouncementFinished?()
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            AppLogger.error("Audio player decode error: \(error.localizedDescription)", component: "Announcer")
        }
    }
}
