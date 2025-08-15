//
//  SpotifyViewModel.swift
//  pulseprompt
//
//  ViewModel for Spotify UI state management - extracted from SpotifyManager.swift
//

import Foundation
import Combine

class SpotifyViewModel: ObservableObject {
    // MARK: - Singleton for shared state
    static let shared = SpotifyViewModel()
    
    // MARK: - Published UI State
    @Published var isConnected = false          // OAuth authentication status (for UI)
    @Published var currentTrack: String = ""    // Currently playing track name
    @Published var isPlaying = false           // Playback state
    @Published var connectionStatus: ConnectionStatus = .disconnected
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    // MARK: - Dependencies
    private let spotifyService: SpotifyService
    private let configurationManager: ConfigurationManager
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init(configurationManager: ConfigurationManager = ConfigurationManager.shared) {
        self.configurationManager = configurationManager
        
        // Initialize SpotifyService with configuration
        self.spotifyService = SpotifyService(
            clientID: configurationManager.spotifyClientID,
            clientSecret: configurationManager.spotifyClientSecret
        )
        
        setupSpotifyServiceDelegate()
    }
    
    // For dependency injection in tests
    init(spotifyService: SpotifyService, configurationManager: ConfigurationManager) {
        self.spotifyService = spotifyService
        self.configurationManager = configurationManager
        setupSpotifyServiceDelegate()
    }
    
    private func setupSpotifyServiceDelegate() {
        spotifyService.delegate = self
    }
    
    // MARK: - Public API for UI
    
    func connect() {
        connectionStatus = .connecting
        spotifyService.connect()
    }
    
    func disconnect() {
        spotifyService.disconnect()
        resetUIState()
    }
    
    func reconnect() {
        connectionStatus = .connecting
        spotifyService.reconnect()
    }
    
    func handleCallback(url: URL) {
        spotifyService.handleCallback(url: url)
    }
    
    func pause() {
        spotifyService.pause()
    }
    
    func resume() {
        spotifyService.resume()
    }
    
    // MARK: - Training-specific API
    
    func activateDeviceForTraining(completion: @escaping (Bool) -> Void) {
        let playlistID = configurationManager.spotifyHighIntensityPlaylistID
        spotifyService.activateDeviceForTraining(playlistID: playlistID, completion: completion)
    }
    
    func playHighIntensityPlaylist() {
        let playlistID = configurationManager.spotifyHighIntensityPlaylistID
        spotifyService.playHighIntensityPlaylist(playlistID: playlistID)
    }
    
    func playRestPlaylist() {
        let playlistID = configurationManager.spotifyRestPlaylistID
        spotifyService.playRestPlaylist(playlistID: playlistID)
    }
    
    func resetDeviceActivationState() {
        spotifyService.resetDeviceActivationState()
        currentTrack = ""
        isPlaying = false
    }
    
    // MARK: - Private Helpers
    
    private func resetUIState() {
        isConnected = false
        currentTrack = ""
        isPlaying = false
        connectionStatus = .disconnected
    }
    
    // MARK: - Computed Properties for UI
    
    var canConnect: Bool {
        !configurationManager.spotifyClientID.isEmpty && connectionStatus != .connecting
    }
    
    var statusMessage: String {
        switch connectionStatus {
        case .disconnected:
            return canConnect ? "Ready to connect" : "Client ID not configured"
        case .connecting:
            return "Connecting to Spotify..."
        case .connected:
            return "Connected to Spotify"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var playbackStatusText: String {
        if isPlaying && !currentTrack.isEmpty {
            return "♪ \(currentTrack)"
        } else if isPlaying {
            return "♪ Playing"
        } else {
            return "Paused"
        }
    }
}

// MARK: - SpotifyServiceDelegate
extension SpotifyViewModel: SpotifyServiceDelegate {
    func spotifyServiceDidConnect() {
        DispatchQueue.main.async {
            self.isConnected = true
            self.connectionStatus = .connected
        }
    }
    
    func spotifyServiceDidDisconnect(error: Error?) {
        DispatchQueue.main.async {
            self.isConnected = false
            if let error = error {
                self.connectionStatus = .error(error.localizedDescription)
            } else {
                self.connectionStatus = .disconnected
            }
        }
    }
    
    func spotifyServicePlayerStateDidChange(isPlaying: Bool, trackName: String) {
        DispatchQueue.main.async {
            self.isPlaying = isPlaying
            self.currentTrack = trackName
        }
    }
}
