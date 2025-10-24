//
//  MusicKitService.swift
//  RunBeat
//
//  Complete Apple Music integration service
//  Handles authorization, playlist fetching, playback control, and track info
//

import Foundation
import MusicKit
import MediaPlayer
import AVFoundation
import Combine

class MusicKitService: ObservableObject {
    static let shared = MusicKitService()

    // MARK: - Published State
    @Published private(set) var isAuthorized = false
    @Published private(set) var currentTrack: MusicTrackInfo?
    @Published private(set) var isPlaying = false

    // MARK: - Private Properties
    private let player = ApplicationMusicPlayer.shared
    private var stateObserver: AnyCancellable?
    private var queueObserver: AnyCancellable?

    private init() {
        setupAudioSession()
        setupObservers()
        checkAuthorizationStatus()
    }

    // MARK: - Audio Session Management

    /**
     * Configure audio session for background playback
     */
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            // Include .mixWithOthers and .duckOthers so zone announcements can play over music
            try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try audioSession.setActive(true)

            AppLogger.info("Audio session configured for background playback with mixing/ducking", component: "MusicKit")
        } catch {
            AppLogger.error("Failed to setup audio session: \(error)", component: "MusicKit")
        }
    }

    // MARK: - Authorization

    /**
     * Check current Apple Music authorization status
     */
    func checkAuthorizationStatus() {
        Task { @MainActor in
            let status = MusicAuthorization.currentStatus
            self.isAuthorized = (status == .authorized)

            AppLogger.info("Apple Music auth status: \(status)", component: "MusicKit")
        }
    }

    /**
     * Request Apple Music authorization from user
     */
    func requestAuthorization() async -> Bool {
        AppLogger.info("Requesting Apple Music authorization", component: "MusicKit")

        let status = await MusicAuthorization.request()

        await MainActor.run {
            self.isAuthorized = (status == .authorized)
        }

        if status == .authorized {
            AppLogger.info("Apple Music authorization granted", component: "MusicKit")
        } else {
            AppLogger.warn("Apple Music authorization denied: \(status)", component: "MusicKit")
        }

        return status == .authorized
    }

    // MARK: - Playlist Fetching

    /**
     * Fetch user's library playlists
     */
    func fetchUserPlaylists() async throws -> [MusicPlaylist] {
        guard isAuthorized else {
            AppLogger.error("Cannot fetch playlists - not authorized", component: "MusicKit")
            throw MusicKitError.notAuthorized
        }

        AppLogger.info("Fetching user playlists from Apple Music library", component: "MusicKit")

        var request = MusicLibraryRequest<Playlist>()
        request.limit = 100 // Get more playlists for full selection

        do {
            let response = try await request.response()
            let playlists = response.items.map { MusicPlaylist.from($0) }

            AppLogger.info("Fetched \(playlists.count) playlists from Apple Music", component: "MusicKit")

            return playlists
        } catch {
            AppLogger.error("Failed to fetch playlists: \(error)", component: "MusicKit")
            throw MusicKitError.fetchFailed(error)
        }
    }

    // MARK: - Playback Control

    /**
     * Play a playlist by ID
     */
    func playPlaylist(_ playlistID: String) {
        Task {
            guard isAuthorized else {
                AppLogger.error("Cannot play playlist - not authorized", component: "MusicKit")
                return
            }

            AppLogger.info("Playing playlist: \(playlistID)", component: "MusicKit")

            do {
                // Fetch the playlist from library
                var request = MusicLibraryRequest<Playlist>()
                request.limit = 100
                let response = try await request.response()

                guard let playlist = response.items.first(where: { $0.id.rawValue == playlistID }) else {
                    AppLogger.error("Playlist not found: \(playlistID)", component: "MusicKit")
                    return
                }

                // Set queue using MusicKit ApplicationMusicPlayer (supports library items)
                player.queue = [playlist]

                // Configure playback for training
                player.state.shuffleMode = .off
                player.state.repeatMode = .all // Loop playlist for training sessions

                // Start playback
                try await player.play()

                AppLogger.info("Started playing playlist: \(playlist.name)", component: "MusicKit")
            } catch {
                AppLogger.error("Failed to play playlist: \(error)", component: "MusicKit")
            }
        }
    }

    /**
     * Pause playback
     */
    func pause() {
        Task {
            player.pause()
            AppLogger.debug("Playback paused", component: "MusicKit")
        }
    }

    /**
     * Resume playback
     */
    func resume() {
        Task {
            do {
                try await player.play()
                AppLogger.debug("Playback resumed", component: "MusicKit")
            } catch {
                AppLogger.error("Failed to resume: \(error)", component: "MusicKit")
            }
        }
    }

    /**
     * Toggle play/pause
     */
    func togglePlayPause() {
        if player.state.playbackStatus == .playing {
            pause()
        } else {
            resume()
        }
    }

    /**
     * Stop playback and clear queue
     */
    func stop() {
        Task {
            player.stop()
            AppLogger.debug("Playback stopped", component: "MusicKit")
        }
    }

    // MARK: - Track Info Observers

    /**
     * Setup observers for track changes and playback state using Combine
     */
    private func setupObservers() {
        // Observe queue changes (current track)
        queueObserver = player.queue.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateNowPlayingInfo()
            }

        // Observe playback state changes
        stateObserver = player.state.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updatePlaybackState()
            }

        // Initial update
        Task { @MainActor in
            updateNowPlayingInfo()
            updatePlaybackState()
        }
    }

    /**
     * Update current track info from now playing item
     * Note: Simplified to basic info - detailed track info requires more complex async loading
     */
    private func updateNowPlayingInfo() {
        // For now, just set a placeholder when something is playing
        // Detailed track info would require async loading which complicates the observer pattern
        if player.queue.currentEntry != nil {
            DispatchQueue.main.async {
                if self.currentTrack == nil {
                    self.currentTrack = MusicTrackInfo(
                        name: "Playing from playlist",
                        artist: "Apple Music",
                        artworkImage: nil
                    )
                }
            }
        } else {
            DispatchQueue.main.async {
                self.currentTrack = nil
            }
        }
    }

    /**
     * Update playback state
     */
    private func updatePlaybackState() {
        isPlaying = (player.state.playbackStatus == .playing)
        AppLogger.rateLimited(.debug, message: "Playback state: \(isPlaying ? "playing" : "paused")", key: "playback_state", component: "MusicKit")
    }

    // MARK: - Cleanup

    deinit {
        stateObserver?.cancel()
        queueObserver?.cancel()
    }
}

// MARK: - Track Info Model

struct MusicTrackInfo {
    let name: String
    let artist: String
    let artworkImage: UIImage?
}

// MARK: - Error Types

enum MusicKitError: LocalizedError {
    case notAuthorized
    case fetchFailed(Error)
    case playbackFailed(Error)
    case playlistNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Apple Music authorization required"
        case .fetchFailed(let error):
            return "Failed to fetch playlists: \(error.localizedDescription)"
        case .playbackFailed(let error):
            return "Playback failed: \(error.localizedDescription)"
        case .playlistNotFound:
            return "Playlist not found in library"
        }
    }
}
