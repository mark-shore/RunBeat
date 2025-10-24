//
//  MusicPlaylist.swift
//  RunBeat
//
//  Apple Music playlist model - mirrors SpotifyPlaylist structure
//

import Foundation
import MusicKit

struct MusicPlaylist: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let trackCount: Int
    let description: String?
    let imageURL: String?

    var displayName: String {
        return name
    }

    // Convert from MusicKit's Playlist type
    static func from(_ playlist: Playlist) -> MusicPlaylist {
        return MusicPlaylist(
            id: playlist.id.rawValue,
            name: playlist.name,
            trackCount: playlist.tracks?.count ?? 0,
            description: playlist.standardDescription,
            imageURL: playlist.artwork?.url(width: 300, height: 300)?.absoluteString
        )
    }
}
