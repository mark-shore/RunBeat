//
//  SpotifyPlaylist.swift
//  RunBeat
//
//  Data models for Spotify playlist information
//

import Foundation

struct SpotifyPlaylist: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let description: String?
    let trackCount: Int
    let imageURL: String?
    let isPublic: Bool
    let owner: String
    
    // For display in UI
    var displayName: String {
        return name.isEmpty ? "Untitled Playlist" : name
    }
    
    var displayDescription: String {
        let trackText = trackCount == 1 ? "track" : "tracks"
        let baseInfo = "\(trackCount) \(trackText)"
        
        if let description = description, !description.isEmpty {
            return "\(baseInfo) • \(description)"
        } else {
            return "\(baseInfo) • by \(owner)"
        }
    }
}

// MARK: - JSON Response Models
extension SpotifyPlaylist {
    // Response model from Spotify Web API - User's playlists endpoint
    struct APIResponse: Codable {
        let items: [PlaylistItem]
        let total: Int?
        let limit: Int?
        let offset: Int?
        
        struct PlaylistItem: Codable {
            let id: String
            let name: String
            let description: String?
            let tracks: TracksInfo
            let images: [ImageInfo]
            let `public`: Bool?
            let owner: OwnerInfo
            let collaborative: Bool?
            
            struct TracksInfo: Codable {
                let total: Int
            }
            
            struct ImageInfo: Codable {
                let url: String
                let height: Int?
                let width: Int?
            }
            
            struct OwnerInfo: Codable {
                let display_name: String?
                let id: String
            }
        }
    }
}

// MARK: - Conversion from API Response
extension SpotifyPlaylist {
    static func from(_ apiItem: APIResponse.PlaylistItem) -> SpotifyPlaylist {
        let ownerName = apiItem.owner.display_name ?? apiItem.owner.id
        let isPublic = apiItem.public ?? false
        let imageURL = apiItem.images.first?.url
        
        return SpotifyPlaylist(
            id: apiItem.id,
            name: apiItem.name.isEmpty ? "Untitled Playlist" : apiItem.name,
            description: apiItem.description,
            trackCount: max(0, apiItem.tracks.total), // Ensure non-negative
            imageURL: imageURL,
            isPublic: isPublic,
            owner: ownerName
        )
    }
}

// MARK: - Playlist Selection Storage
struct PlaylistSelection: Codable {
    var highIntensityPlaylistID: String?
    var restPlaylistID: String?
    
    var isComplete: Bool {
        return highIntensityPlaylistID != nil && restPlaylistID != nil
    }
    
    var missingSelections: [String] {
        var missing: [String] = []
        if highIntensityPlaylistID == nil {
            missing.append("High Intensity")
        }
        if restPlaylistID == nil {
            missing.append("Rest")
        }
        return missing
    }
}
