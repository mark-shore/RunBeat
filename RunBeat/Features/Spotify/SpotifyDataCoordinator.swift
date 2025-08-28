//
//  SpotifyDataCoordinator.swift
//  RunBeat
//
//  Unified data source coordination for Spotify integration
//  Manages AppRemote and Web API data sources with intelligent prioritization
//

import Foundation
import Combine

/// Standardized track information across all data sources
struct SpotifyTrackInfo: Equatable {
    let name: String
    let artist: String
    let uri: String
    let artworkURL: String
    let duration: TimeInterval
    let position: TimeInterval
    let isPlaying: Bool
    let source: DataSource
    
    enum DataSource: String {
        case appRemote = "AppRemote"
        case webAPI = "WebAPI"
        case optimistic = "Optimistic"
        
        var priority: Int {
            switch self {
            case .appRemote: return 3     // Highest priority - real-time
            case .webAPI: return 2        // Medium priority - reliable
            case .optimistic: return 1    // Lowest priority - immediate feedback
            }
        }
    }
    
    /// Empty track info for initialization
    static let empty = SpotifyTrackInfo(
        name: "",
        artist: "",
        uri: "",
        artworkURL: "",
        duration: 0,
        position: 0,
        isPlaying: false,
        source: .optimistic
    )
    
    /// Whether this track has meaningful data
    var isEmpty: Bool {
        return name.isEmpty && artist.isEmpty && uri.isEmpty
    }
}

/// Coordinates data flow between AppRemote and Web API sources
class SpotifyDataCoordinator: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published private(set) var currentTrack: SpotifyTrackInfo = .empty
    @Published private(set) var lastUpdated: Date = Date()
    @Published private(set) var dataSourceInUse: SpotifyTrackInfo.DataSource = .optimistic
    
    // MARK: - Private Properties
    
    private var appRemoteData: SpotifyTrackInfo = .empty
    private var webAPIData: SpotifyTrackInfo = .empty
    private var optimisticData: SpotifyTrackInfo = .empty
    
    private let consolidationQueue = DispatchQueue(label: "spotify.data.coordinator", qos: .userInitiated)
    
    // MARK: - Data Source Management
    
    /// Updates track information from AppRemote source
    func updateFromAppRemote(
        name: String,
        artist: String,
        uri: String,
        artworkURL: String,
        duration: TimeInterval,
        position: TimeInterval,
        isPlaying: Bool
    ) {
        consolidationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newData = SpotifyTrackInfo(
                name: name,
                artist: artist,
                uri: uri,
                artworkURL: artworkURL,
                duration: duration,
                position: position,
                isPlaying: isPlaying,
                source: .appRemote
            )
            
            // Check if data has meaningfully changed before processing
            if self.hasDataChanged(current: self.appRemoteData, new: newData) {
                self.appRemoteData = newData
                self.consolidateData()
                print("📊 [DataCoordinator] AppRemote update - Track: '\(name)' by '\(artist)' Playing: \(isPlaying)")
            } else {
                print("📊 [DataCoordinator] AppRemote data unchanged, skipping duplicate update")
            }
        }
    }
    
    /// Updates track information from Web API source
    func updateFromWebAPI(
        name: String,
        artist: String,
        uri: String,
        artworkURL: String,
        duration: TimeInterval,
        position: TimeInterval,
        isPlaying: Bool
    ) {
        consolidationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newData = SpotifyTrackInfo(
                name: name,
                artist: artist,
                uri: uri,
                artworkURL: artworkURL,
                duration: duration,
                position: position,
                isPlaying: isPlaying,
                source: .webAPI
            )
            
            // Check if data has meaningfully changed before processing
            if self.hasDataChanged(current: self.webAPIData, new: newData) {
                self.webAPIData = newData
                self.consolidateData()
                print("📊 [DataCoordinator] WebAPI update - Track: '\(name)' by '\(artist)' Playing: \(isPlaying)")
            } else {
                print("📊 [DataCoordinator] WebAPI data unchanged, skipping duplicate update")
            }
        }
    }
    
    /// Updates optimistic track information (for immediate UI feedback)
    func updateOptimistic(
        name: String,
        artist: String,
        uri: String,
        artworkURL: String,
        duration: TimeInterval,
        position: TimeInterval,
        isPlaying: Bool
    ) {
        consolidationQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newData = SpotifyTrackInfo(
                name: name,
                artist: artist,
                uri: uri,
                artworkURL: artworkURL,
                duration: duration,
                position: position,
                isPlaying: isPlaying,
                source: .optimistic
            )
            
            // Check if data has meaningfully changed before processing
            if self.hasDataChanged(current: self.optimisticData, new: newData) {
                self.optimisticData = newData
                self.consolidateData()
                print("📊 [DataCoordinator] Optimistic update - Track: '\(name)' by '\(artist)' Playing: \(isPlaying)")
            } else {
                print("📊 [DataCoordinator] Optimistic data unchanged, skipping duplicate update")
            }
        }
    }
    
    /// Clears data from a specific source
    func clearDataSource(_ source: SpotifyTrackInfo.DataSource) {
        consolidationQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch source {
            case .appRemote:
                self.appRemoteData = .empty
            case .webAPI:
                self.webAPIData = .empty
            case .optimistic:
                self.optimisticData = .empty
            }
            
            self.consolidateData()
            print("📊 [DataCoordinator] Cleared \(source.rawValue) data source")
        }
    }
    
    /// Clears all data sources (for disconnection/reset)
    func clearAllDataSources() {
        consolidationQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.appRemoteData = .empty
            self.webAPIData = .empty
            self.optimisticData = .empty
            self.consolidateData()
            
            print("📊 [DataCoordinator] Cleared all data sources")
        }
    }
    
    // MARK: - Data Deduplication Logic
    
    /// Determines if new data is meaningfully different from current data
    private func hasDataChanged(current: SpotifyTrackInfo, new: SpotifyTrackInfo) -> Bool {
        // For empty data, always consider it changed (first update)
        if current.isEmpty {
            return true
        }
        
        // Check if core track properties have changed
        let trackChanged = current.name != new.name || 
                          current.artist != new.artist || 
                          current.uri != new.uri
        
        // Check if playback state changed
        let playbackChanged = current.isPlaying != new.isPlaying
        
        // Check if artwork changed (only if not empty)
        let artworkChanged = !new.artworkURL.isEmpty && current.artworkURL != new.artworkURL
        
        // Position changes are frequent and not critical for deduplication
        // Duration changes are rare and should be considered
        let durationChanged = abs(current.duration - new.duration) > 1.0 // 1 second tolerance
        
        let hasChanged = trackChanged || playbackChanged || artworkChanged || durationChanged
        
        if !hasChanged {
            let timeSinceLastUpdate = Date().timeIntervalSince(lastUpdated)
            // Allow periodic updates every 30 seconds even if data is identical
            // This ensures we don't suppress legitimate updates indefinitely
            if timeSinceLastUpdate > 30.0 {
                print("📊 [DataCoordinator] Allowing periodic update after 30s of identical data")
                return true
            }
        }
        
        return hasChanged
    }
    
    // MARK: - Data Consolidation Logic
    
    private func consolidateData() {
        // Determine best available data source by priority
        let availableData = [appRemoteData, webAPIData, optimisticData]
            .filter { !$0.isEmpty }
            .sorted { $0.source.priority > $1.source.priority }
        
        let bestData = availableData.first ?? .empty
        
        // Only update if data actually changed
        if bestData != currentTrack {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                
                self.currentTrack = bestData
                self.dataSourceInUse = bestData.source
                self.lastUpdated = Date()
                
                print("📊 [DataCoordinator] Consolidated -> Using \(bestData.source.rawValue) data")
                if !bestData.isEmpty {
                    print("📊 [DataCoordinator] Final: '\(bestData.name)' by '\(bestData.artist)' Playing: \(bestData.isPlaying)")
                }
            }
        }
    }
    
    // MARK: - Data Validation
    
    /// Validates consistency between data sources and logs discrepancies
    func validateDataConsistency() -> Bool {
        let sources = [
            ("AppRemote", appRemoteData),
            ("WebAPI", webAPIData),
            ("Optimistic", optimisticData)
        ].filter { !$0.1.isEmpty }
        
        guard sources.count > 1 else { return true } // No conflict with single source
        
        let trackNames = Set(sources.map { $0.1.name })
        let playingStates = Set(sources.map { $0.1.isPlaying })
        
        let isConsistent = trackNames.count <= 1 && playingStates.count <= 1
        
        if !isConsistent {
            print("⚠️ [DataCoordinator] Data inconsistency detected:")
            for (sourceName, data) in sources {
                print("  - \(sourceName): '\(data.name)' Playing: \(data.isPlaying)")
            }
        }
        
        return isConsistent
    }
    
    // MARK: - Computed Properties
    
    /// Whether we have any valid track data
    var hasValidData: Bool {
        return !currentTrack.isEmpty
    }
    
    /// Whether AppRemote is providing current data
    var isUsingAppRemote: Bool {
        return dataSourceInUse == .appRemote
    }
    
    /// Whether Web API is providing current data  
    var isUsingWebAPI: Bool {
        return dataSourceInUse == .webAPI
    }
    
    /// Age of current data in seconds
    var dataAge: TimeInterval {
        return Date().timeIntervalSince(lastUpdated)
    }
    
    // MARK: - Debug Information
    
    func getDebugInfo() -> String {
        return """
        Current Track: \(currentTrack.isEmpty ? "None" : "\(currentTrack.name) by \(currentTrack.artist)")
        Data Source: \(dataSourceInUse.rawValue)
        Last Updated: \(Int(dataAge))s ago
        Data Sources Available:
          - AppRemote: \(appRemoteData.isEmpty ? "None" : appRemoteData.name)
          - WebAPI: \(webAPIData.isEmpty ? "None" : webAPIData.name)  
          - Optimistic: \(optimisticData.isEmpty ? "None" : optimisticData.name)
        """
    }
}

// MARK: - Legacy Compatibility Extensions

extension SpotifyDataCoordinator {
    
    /// Legacy compatibility - individual track properties
    var trackName: String { currentTrack.name }
    var artistName: String { currentTrack.artist }
    var trackURI: String { currentTrack.uri }
    var artworkURL: String { currentTrack.artworkURL }
    var isPlaying: Bool { currentTrack.isPlaying }
    var duration: TimeInterval { currentTrack.duration }
    var position: TimeInterval { currentTrack.position }
}