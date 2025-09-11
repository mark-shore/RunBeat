//
//  PlaylistSectionNavigator.swift
//  RunBeat
//
//  Created by Claude Code on 9/11/25.
//

import SwiftUI

struct PlaylistSectionNavigator: View {
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    @State private var selectedSection: PlaylistSection = .recent
    @State private var selectedPlaylistForAction: SpotifyPlaylist?
    @State private var showingActionSheet = false
    
    enum PlaylistSection: Int, CaseIterable {
        case recent = 0
        case library = 1
        
        var title: String {
            switch self {
            case .recent: return "Recently Played"
            case .library: return "Your Library"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Horizontal swipeable sections
            TabView(selection: $selectedSection) {
                // Recently Played Section
                PlaylistGridSection(
                    playlists: recentPlaylists,
                    onPlaylistTap: { playlist in
                        selectedPlaylistForAction = playlist
                        showingActionSheet = true
                    }
                )
                .tag(PlaylistSection.recent)
                
                // Your Library Section  
                PlaylistGridSection(
                    playlists: availablePlaylists,
                    onPlaylistTap: { playlist in
                        selectedPlaylistForAction = playlist
                        showingActionSheet = true
                    }
                )
                .tag(PlaylistSection.library)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: selectedSection)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            playlistActionSheet
        }
        .onAppear {
            // Fetch playlists and recently played when view appears
            if spotifyViewModel.isConnected {
                spotifyViewModel.fetchPlaylists()
                spotifyViewModel.fetchRecentlyPlayedPlaylists()
            }
        }
    }
    
    // MARK: - Data Sources
    
    private var recentPlaylists: [SpotifyPlaylist] {
        // Show recently played or first 8 playlists as fallback
        if !spotifyViewModel.recentlyPlayedPlaylists.isEmpty {
            return Array(spotifyViewModel.recentlyPlayedPlaylists.prefix(8))
        } else {
            return Array(spotifyViewModel.availablePlaylists.prefix(8))
        }
    }
    
    private var availablePlaylists: [SpotifyPlaylist] {
        // Filter out already selected playlists
        spotifyViewModel.availablePlaylists.filter { playlist in
            playlist.id != spotifyViewModel.playlistSelection.highIntensityPlaylistID &&
            playlist.id != spotifyViewModel.playlistSelection.restPlaylistID
        }
    }
    
    // MARK: - Action Sheet
    
    private var playlistActionSheet: ActionSheet {
        guard let playlist = selectedPlaylistForAction else {
            return ActionSheet(title: Text("Error"), buttons: [.cancel()])
        }
        
        let currentAssignment = getPlaylistAssignment(playlist)
        var buttons: [ActionSheet.Button] = []
        
        // Work option
        if currentAssignment != .highIntensity {
            buttons.append(.default(Text("Use for Work")) {
                spotifyViewModel.selectHighIntensityPlaylist(playlist)
                checkForAutoCollapse()
            })
        }
        
        // Recovery option  
        if currentAssignment != .rest {
            buttons.append(.default(Text("Use for Recovery")) {
                spotifyViewModel.selectRestPlaylist(playlist)
                checkForAutoCollapse()
            })
        }
        
        // Remove assignment option
        if currentAssignment != .none {
            buttons.append(.destructive(Text("Remove Assignment")) {
                if currentAssignment == .highIntensity {
                    spotifyViewModel.playlistSelection.highIntensityPlaylistID = nil
                } else if currentAssignment == .rest {
                    spotifyViewModel.playlistSelection.restPlaylistID = nil
                }
                spotifyViewModel.savePlaylistSelection()
            })
        }
        
        buttons.append(.cancel())
        
        return ActionSheet(
            title: Text(playlist.name),
            message: Text("How would you like to use this playlist?"),
            buttons: buttons
        )
    }
    
    // MARK: - Helper Methods
    
    private func getPlaylistAssignment(_ playlist: SpotifyPlaylist) -> PlaylistAssignment {
        if playlist.id == spotifyViewModel.playlistSelection.highIntensityPlaylistID {
            return .highIntensity
        } else if playlist.id == spotifyViewModel.playlistSelection.restPlaylistID {
            return .rest
        } else {
            return .none
        }
    }
    
    private func checkForAutoCollapse() {
        if spotifyViewModel.playlistSelection.isComplete {
            // Signal parent drawer to collapse
            NotificationCenter.default.post(name: .playlistSelectionComplete, object: nil)
        }
    }
}

// MARK: - Playlist Grid Section

struct PlaylistGridSection: View {
    let playlists: [SpotifyPlaylist]
    let onPlaylistTap: (SpotifyPlaylist) -> Void
    
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if playlists.isEmpty {
                // Empty state
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 32))
                        .foregroundColor(AppColors.secondary)
                    
                    Text("No playlists found")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppSpacing.xl)
            } else {
                // 2-column grid of playlist cards
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 8),
                    GridItem(.flexible(), spacing: 8)
                ], spacing: 8) {
                    ForEach(playlists) { playlist in
                        AvailablePlaylistCard(playlist: playlist) {
                            onPlaylistTap(playlist)
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.xs)
                .padding(.bottom, AppSpacing.lg)
            }
        }
    }
}

// MARK: - Notification Extension

extension Notification.Name {
    static let playlistSelectionComplete = Notification.Name("playlistSelectionComplete")
}

#Preview {
    PlaylistSectionNavigator()
        .background(AppColors.background)
}