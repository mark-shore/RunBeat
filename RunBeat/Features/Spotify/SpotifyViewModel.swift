//
//  SpotifyViewModel.swift
//  RunBeat
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
    
    // Playlist management state
    @Published var availablePlaylists: [SpotifyPlaylist] = []
    @Published var playlistSelection = PlaylistSelection()
    @Published var playlistFetchStatus: PlaylistFetchStatus = .notStarted
    
    enum ConnectionStatus: Equatable {
        case disconnected
        case connecting
        case connected
        case error(String)
    }
    
    enum PlaylistFetchStatus: Equatable {
        case notStarted
        case fetching
        case loaded
        case error(String)
    }
    
    enum PlaylistDisplayInfo {
        case notSelected
        case loading
        case loaded(SpotifyPlaylist)
        case error(String)
        
        var playlist: SpotifyPlaylist? {
            switch self {
            case .loaded(let playlist):
                return playlist
            default:
                return nil
            }
        }
        
        var displayText: String {
            switch self {
            case .notSelected:
                return "Tap to select playlist"
            case .loading:
                return "Loading playlist..."
            case .loaded(let playlist):
                return playlist.displayName
            case .error(let message):
                return message
            }
        }
        
        var isLoading: Bool {
            switch self {
            case .loading:
                return true
            default:
                return false
            }
        }
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
        loadPersistedPlaylistSelection()
        
        // Check if we're already connected and should fetch playlists
        checkForExistingConnection()
    }
    
    private func checkForExistingConnection() {
        // Give a moment for the service to initialize, then check connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.isConnected && 
               (self.playlistSelection.highIntensityPlaylistID != nil || 
                self.playlistSelection.restPlaylistID != nil) && 
               self.playlistFetchStatus == .notStarted {
                print("🎵 Auto-fetching playlists for existing connection")
                self.fetchPlaylists()
            }
        }
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
        let playlistID = playlistSelection.highIntensityPlaylistID ?? configurationManager.spotifyHighIntensityPlaylistID
        spotifyService.activateDeviceForTraining(playlistID: playlistID, completion: completion)
    }
    
    func playHighIntensityPlaylist() {
        let playlistID = playlistSelection.highIntensityPlaylistID ?? configurationManager.spotifyHighIntensityPlaylistID
        spotifyService.playHighIntensityPlaylist(playlistID: playlistID)
    }
    
    func playRestPlaylist() {
        let playlistID = playlistSelection.restPlaylistID ?? configurationManager.spotifyRestPlaylistID
        spotifyService.playRestPlaylist(playlistID: playlistID)
    }
    
    // MARK: - Playlist Management
    
    func fetchPlaylists() {
        guard isConnected else {
            print("❌ Cannot fetch playlists - not connected to Spotify")
            playlistFetchStatus = .error("Not connected to Spotify")
            return
        }
        
        print("🎵 Starting playlist fetch...")
        playlistFetchStatus = .fetching
        
        spotifyService.fetchUserPlaylists { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let playlists):
                    print("✅ Successfully fetched \(playlists.count) playlists in ViewModel")
                    self.availablePlaylists = playlists
                    self.playlistFetchStatus = .loaded
                    
                    // Auto-retry to load playlist names for existing selections
                    self.validateExistingSelections()
                    
                case .failure(let error):
                    print("❌ Failed to fetch playlists: \(error)")
                    
                    // Handle specific error types
                    if let spotifyError = error as? SpotifyError {
                        switch spotifyError {
                        case .tokenExpired:
                            self.isConnected = false
                            self.connectionStatus = .disconnected
                            self.playlistFetchStatus = .error("Session expired. Please reconnect to Spotify.")
                        case .networkError:
                            self.playlistFetchStatus = .error("Network error. Check your connection and try again.")
                        case .insufficientPermissions:
                            self.playlistFetchStatus = .error("Missing playlist permissions. Please reconnect to Spotify.")
                        default:
                            self.playlistFetchStatus = .error(spotifyError.localizedDescription)
                        }
                    } else {
                        self.playlistFetchStatus = .error(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    private func validateExistingSelections() {
        // Check if current selections are still valid
        if let highID = playlistSelection.highIntensityPlaylistID,
           !availablePlaylists.contains(where: { $0.id == highID }) {
            print("⚠️ High intensity playlist no longer available, clearing selection")
            playlistSelection.highIntensityPlaylistID = nil
            savePlaylistSelection()
        }
        
        if let restID = playlistSelection.restPlaylistID,
           !availablePlaylists.contains(where: { $0.id == restID }) {
            print("⚠️ Rest playlist no longer available, clearing selection")
            playlistSelection.restPlaylistID = nil
            savePlaylistSelection()
        }
    }
    
    func selectHighIntensityPlaylist(_ playlist: SpotifyPlaylist) {
        print("🎵 Selected high intensity playlist: \(playlist.name)")
        playlistSelection.highIntensityPlaylistID = playlist.id
        savePlaylistSelection()
    }
    
    func selectRestPlaylist(_ playlist: SpotifyPlaylist) {
        print("🎵 Selected rest playlist: \(playlist.name)")
        playlistSelection.restPlaylistID = playlist.id
        savePlaylistSelection()
    }
    
    func clearPlaylistSelection() {
        print("🗑️ Clearing playlist selections")
        playlistSelection = PlaylistSelection()
        savePlaylistSelection()
    }
    
    private func loadPersistedPlaylistSelection() {
        do {
            if let data = UserDefaults.standard.data(forKey: "SpotifyPlaylistSelection") {
                let selection = try JSONDecoder().decode(PlaylistSelection.self, from: data)
                playlistSelection = selection
                print("✅ Loaded persisted playlist selection: High=\(selection.highIntensityPlaylistID ?? "none"), Rest=\(selection.restPlaylistID ?? "none")")
                
                // Also load any cached playlist names if available
                loadCachedPlaylistNames()
            } else {
                print("ℹ️ No persisted playlist selection found")
            }
        } catch {
            print("❌ Failed to load playlist selection: \(error)")
            playlistSelection = PlaylistSelection()
        }
    }
    
    private func loadCachedPlaylistNames() {
        // Load cached playlist data for immediate display
        if let cachedData = UserDefaults.standard.data(forKey: "CachedSelectedPlaylists") {
            do {
                let cachedPlaylists = try JSONDecoder().decode([SpotifyPlaylist].self, from: cachedData)
                // Only use cached playlists that match our current selection
                let validCached = cachedPlaylists.filter { playlist in
                    playlist.id == playlistSelection.highIntensityPlaylistID || 
                    playlist.id == playlistSelection.restPlaylistID
                }
                
                if !validCached.isEmpty {
                    // Add cached playlists to available playlists for immediate display
                    let existingIDs = Set(availablePlaylists.map { $0.id })
                    let newPlaylists = validCached.filter { !existingIDs.contains($0.id) }
                    
                    // Add cached playlists to available playlists for immediate display
                    self.availablePlaylists.append(contentsOf: newPlaylists)
                    print("✅ Loaded \(newPlaylists.count) cached playlists for immediate display")
                }
            } catch {
                print("❌ Failed to load cached playlist names: \(error)")
            }
        }
    }
    
    func savePlaylistSelection() {
        do {
            let data = try JSONEncoder().encode(playlistSelection)
            UserDefaults.standard.set(data, forKey: "SpotifyPlaylistSelection")
            print("💾 Saved playlist selection to UserDefaults")
            
            // Also cache the actual playlist objects for immediate display
            cacheSelectedPlaylistData()
        } catch {
            print("❌ Failed to save playlist selection: \(error)")
        }
    }
    
    private func cacheSelectedPlaylistData() {
        var playlistsToCache: [SpotifyPlaylist] = []
        
        if let highPlaylist = selectedHighIntensityPlaylist {
            playlistsToCache.append(highPlaylist)
        }
        
        if let restPlaylist = selectedRestPlaylist {
            playlistsToCache.append(restPlaylist)
        }
        
        if !playlistsToCache.isEmpty {
            do {
                let data = try JSONEncoder().encode(playlistsToCache)
                UserDefaults.standard.set(data, forKey: "CachedSelectedPlaylists")
                print("💾 Cached \(playlistsToCache.count) selected playlists for immediate display")
            } catch {
                print("❌ Failed to cache selected playlists: \(error)")
            }
        }
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
    
    var hasPlaylistsConfigured: Bool {
        return hasValidPlaylistSelection || hasConfigFilePlaylists
    }
    
    var hasValidPlaylistSelection: Bool {
        return playlistSelection.isComplete
    }
    
    private var hasConfigFilePlaylists: Bool {
        return !configurationManager.spotifyHighIntensityPlaylistID.isEmpty && 
               !configurationManager.spotifyRestPlaylistID.isEmpty
    }
    
    var selectedHighIntensityPlaylist: SpotifyPlaylist? {
        guard let id = playlistSelection.highIntensityPlaylistID else { 
            return nil 
        }
        return availablePlaylists.first { $0.id == id }
    }
    
    var selectedRestPlaylist: SpotifyPlaylist? {
        guard let id = playlistSelection.restPlaylistID else { 
            return nil 
        }
        return availablePlaylists.first { $0.id == id }
    }
    
    // New computed properties to provide better loading state information
    var isHighIntensityPlaylistLoading: Bool {
        guard playlistSelection.highIntensityPlaylistID != nil else { return false }
        return selectedHighIntensityPlaylist == nil && playlistFetchStatus == .fetching
    }
    
    var isRestPlaylistLoading: Bool {
        guard playlistSelection.restPlaylistID != nil else { return false }
        return selectedRestPlaylist == nil && playlistFetchStatus == .fetching
    }
    
    var highIntensityDisplayInfo: PlaylistDisplayInfo {
        // If we have the actual playlist data, show it
        if let playlist = selectedHighIntensityPlaylist {
            return .loaded(playlist)
        }
        
        // If no playlist is selected, show selection prompt
        guard playlistSelection.highIntensityPlaylistID != nil else {
            return .notSelected
        }
        
        // We have a playlist ID but can't find it in available playlists
        // Auto-trigger fetch if needed but never show loading flash
        if isConnected && playlistFetchStatus == .notStarted {
            Task { @MainActor in
                if self.playlistFetchStatus == .notStarted {
                    self.fetchPlaylists()
                }
            }
        }
        
        // Always show selection prompt instead of loading for smooth UX
        return .notSelected
    }
    
    var restDisplayInfo: PlaylistDisplayInfo {
        // If we have the actual playlist data, show it
        if let playlist = selectedRestPlaylist {
            return .loaded(playlist)
        }
        
        // If no playlist is selected, show selection prompt
        guard playlistSelection.restPlaylistID != nil else {
            return .notSelected
        }
        
        // We have a playlist ID but can't find it in available playlists
        // Auto-trigger fetch if needed but never show loading flash
        if isConnected && playlistFetchStatus == .notStarted {
            Task { @MainActor in
                if self.playlistFetchStatus == .notStarted {
                    self.fetchPlaylists()
                }
            }
        }
        
        // Always show selection prompt instead of loading for smooth UX
        return .notSelected
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
            
            // Auto-fetch playlists if user has any saved selections
            if (self.playlistSelection.highIntensityPlaylistID != nil || 
                self.playlistSelection.restPlaylistID != nil) && 
               self.playlistFetchStatus == .notStarted {
                self.fetchPlaylists()
            }
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
