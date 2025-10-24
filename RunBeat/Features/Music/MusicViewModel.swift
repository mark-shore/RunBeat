//
//  MusicViewModel.swift
//  RunBeat
//
//  Complete ViewModel for Apple Music integration
//  Handles authorization, playlist selection, playback control, and track info
//

import Foundation
import UIKit
import Combine

class MusicViewModel: ObservableObject {
    static let shared = MusicViewModel()

    // MARK: - Published UI State

    // Authorization
    @Published var isAuthorized = false

    // Playlists
    @Published var availablePlaylists: [MusicPlaylist] = []
    @Published var playlistFetchStatus: PlaylistFetchStatus = .notStarted
    @Published var playlistSelection = MusicPlaylistSelection()

    // Current track info
    @Published var currentTrack: String = ""
    @Published var currentArtist: String = ""
    @Published var currentAlbumArtwork: UIImage?
    @Published var isPlaying = false

    enum PlaylistFetchStatus: Equatable {
        case notStarted
        case fetching
        case loaded
        case error(String)
    }

    // MARK: - Dependencies
    private let musicService: MusicKitService
    private var cancellables = Set<AnyCancellable>()

    private init(musicService: MusicKitService = MusicKitService.shared) {
        self.musicService = musicService
        setupObservers()
        loadPersistedPlaylistSelection()
    }

    private func setupObservers() {
        // Observe authorization state
        musicService.$isAuthorized
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAuthorized)

        // Observe current track
        musicService.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] trackInfo in
                self?.currentTrack = trackInfo?.name ?? ""
                self?.currentArtist = trackInfo?.artist ?? ""
                self?.currentAlbumArtwork = trackInfo?.artworkImage
            }
            .store(in: &cancellables)

        // Observe playback state
        musicService.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: &$isPlaying)
    }

    // MARK: - Authorization

    /**
     * Request Apple Music authorization
     */
    func authorize() async {
        AppLogger.info("MusicViewModel: Requesting authorization", component: "MusicKit")
        _ = await musicService.requestAuthorization()
    }

    // MARK: - Playlist Management

    /**
     * Fetch user's playlists from Apple Music library
     */
    func fetchPlaylists() async {
        await MainActor.run { playlistFetchStatus = .fetching }

        do {
            let playlists = try await musicService.fetchUserPlaylists()

            await MainActor.run {
                self.availablePlaylists = playlists
                self.playlistFetchStatus = .loaded
                AppLogger.info("MusicViewModel: Loaded \(playlists.count) playlists", component: "MusicKit")
            }
        } catch {
            await MainActor.run {
                self.playlistFetchStatus = .error(error.localizedDescription)
                AppLogger.error("MusicViewModel: Failed to fetch playlists - \(error)", component: "MusicKit")
            }
        }
    }

    /**
     * Select high intensity playlist
     */
    func selectHighIntensityPlaylist(_ playlist: MusicPlaylist) {
        playlistSelection.highIntensity = playlist
        persistPlaylistSelection()
        AppLogger.info("Selected high intensity playlist: \(playlist.name)", component: "MusicKit")
    }

    /**
     * Select rest playlist
     */
    func selectRestPlaylist(_ playlist: MusicPlaylist) {
        playlistSelection.rest = playlist
        persistPlaylistSelection()
        AppLogger.info("Selected rest playlist: \(playlist.name)", component: "MusicKit")
    }

    // MARK: - Playback Control

    /**
     * Play high intensity playlist
     */
    func playHighIntensityMusic() {
        guard let playlistID = playlistSelection.highIntensity?.id else {
            AppLogger.warn("Cannot play high intensity music - no playlist selected", component: "MusicKit")
            return
        }

        AppLogger.info("Playing high intensity music", component: "MusicKit")
        musicService.playPlaylist(playlistID)
    }

    /**
     * Play rest playlist
     */
    func playRestMusic() {
        guard let playlistID = playlistSelection.rest?.id else {
            AppLogger.warn("Cannot play rest music - no playlist selected", component: "MusicKit")
            return
        }

        AppLogger.info("Playing rest music", component: "MusicKit")
        musicService.playPlaylist(playlistID)
    }

    /**
     * Toggle play/pause
     */
    func togglePlayPause() {
        musicService.togglePlayPause()
    }

    /**
     * Pause playback
     */
    func pause() {
        musicService.pause()
    }

    /**
     * Resume playback
     */
    func resume() {
        musicService.resume()
    }

    /**
     * Stop playback
     */
    func stop() {
        musicService.stop()
    }

    // MARK: - Computed Properties

    /**
     * Check if both playlists are selected
     */
    var hasPlaylistsConfigured: Bool {
        return playlistSelection.highIntensity != nil && playlistSelection.rest != nil
    }

    /**
     * Get selected high intensity playlist
     */
    var selectedHighIntensityPlaylist: MusicPlaylist? {
        return playlistSelection.highIntensity
    }

    /**
     * Get selected rest playlist
     */
    var selectedRestPlaylist: MusicPlaylist? {
        return playlistSelection.rest
    }

    // MARK: - Persistence

    /**
     * Load persisted playlist selection from UserDefaults
     */
    private func loadPersistedPlaylistSelection() {
        if let data = UserDefaults.standard.data(forKey: "musicPlaylistSelection"),
           let selection = try? JSONDecoder().decode(MusicPlaylistSelection.self, from: data) {
            playlistSelection = selection
            AppLogger.debug("Loaded persisted playlist selection", component: "MusicKit")
        }
    }

    /**
     * Save playlist selection to UserDefaults
     */
    private func persistPlaylistSelection() {
        if let data = try? JSONEncoder().encode(playlistSelection) {
            UserDefaults.standard.set(data, forKey: "musicPlaylistSelection")
            AppLogger.debug("Persisted playlist selection", component: "MusicKit")
        }
    }

    /**
     * Save playlist selection (public method for manual saves)
     */
    func savePlaylistSelection() {
        persistPlaylistSelection()
    }
}

// MARK: - Models

/**
 * Playlist selection for training modes (Apple Music)
 */
struct MusicPlaylistSelection: Codable {
    var highIntensity: MusicPlaylist?
    var rest: MusicPlaylist?

    var highIntensityPlaylistID: String? {
        get { highIntensity?.id }
        set {
            if let id = newValue, let playlist = highIntensity, playlist.id == id {
                // Keep existing
            } else {
                highIntensity = nil
            }
        }
    }

    var restPlaylistID: String? {
        get { rest?.id }
        set {
            if let id = newValue, let playlist = rest, playlist.id == id {
                // Keep existing
            } else {
                rest = nil
            }
        }
    }

    var isComplete: Bool {
        return highIntensity != nil && rest != nil
    }
}
