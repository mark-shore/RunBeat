//
//  PlaylistSelectionView.swift
//  RunBeat
//
//  Simplified playlist selection UI - browsing first, selection second
//

import SwiftUI

struct PlaylistSelectionView: View {
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showingActionSheet = false
    @State private var selectedPlaylistForAction: SpotifyPlaylist?
    @State private var showingFullLibrary = false
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                ModalContainer {
                    if showingFullLibrary {
                        // Full library view (all playlists)
                        fullLibraryView
                    } else {
                        // Main Spotify-style view (recently played)
                        VStack(spacing: 0) {
                            // Compact Header
                            compactHeaderSection
                            
                            // Compact Selection Status (15% of screen)
                            if spotifyViewModel.isConnected {
                                compactSelectionStatus
                                    .padding(.bottom, 12)
                            }
                            
                            // Main Content (80% of screen)
                            if !spotifyViewModel.isConnected {
                                connectionSection
                            } else {
                                playlistBrowsingSection
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if showingFullLibrary {
                        Button("← Back") {
                            showingFullLibrary = false
                        }
                        .foregroundColor(AppColors.onBackground)
                    } else {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppColors.onBackground)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(spotifyViewModel.playlistSelection.isComplete ? AppColors.primary : AppColors.secondary)
                    .disabled(!spotifyViewModel.playlistSelection.isComplete)
                }
            }
        }
        .actionSheet(isPresented: $showingActionSheet) {
            ActionSheet(
                title: Text(selectedPlaylistForAction?.name ?? "Select Usage"),
                message: Text("How would you like to use this playlist?"),
                buttons: actionSheetButtons
            )
        }
        .onAppear {
            print("🎵 PlaylistSelectionView appeared")
            print("   - Connected: \(spotifyViewModel.isConnected)")
            print("   - Fetch status: \(spotifyViewModel.playlistFetchStatus)")
            print("   - Available playlists: \(spotifyViewModel.availablePlaylists.count)")
            
            if spotifyViewModel.isConnected && spotifyViewModel.playlistFetchStatus == .notStarted {
                print("🎵 Auto-fetching playlists on view appear")
                spotifyViewModel.fetchPlaylists()
            }
        }
        .onChange(of: spotifyViewModel.isConnected) { _, isConnected in
            if isConnected && spotifyViewModel.playlistFetchStatus == .notStarted {
                print("🎵 Auto-fetching playlists after connection")
                spotifyViewModel.fetchPlaylists()
            }
        }
    }
    
    // MARK: - Compact Header Section
    
    private var compactHeaderSection: some View {
        VStack(spacing: AppSpacing.xs) {
            Text("Training Playlists")
                .font(AppTypography.largeTitle)
                .foregroundColor(AppColors.onBackground)
            
            Text("Choose your workout music")
                .font(AppTypography.callout)
                .foregroundColor(AppColors.secondary)
        }
        .padding(.bottom, AppSpacing.md)
    }
    
    // MARK: - Compact Selection Status
    
    private var compactSelectionStatus: some View {
        VStack(spacing: AppSpacing.xs) {
            // High Intensity Status
            HStack {
                Text("High Intensity:")
                    .font(AppTypography.callout)
                    .foregroundColor(AppColors.primary)
                    .fontWeight(.medium)
                
                if let playlist = spotifyViewModel.selectedHighIntensityPlaylist {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 14))
                        Text(playlist.name)
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.onBackground)
                    }
                } else {
                    Text("Not selected")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                        .italic()
                }
                
                Spacer()
            }
            
            // Rest Status
            HStack {
                Text("Rest:")
                    .font(AppTypography.callout)
                    .foregroundColor(AppColors.zone1)
                    .fontWeight(.medium)
                
                if let playlist = spotifyViewModel.selectedRestPlaylist {
                    HStack(spacing: AppSpacing.xs) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.zone1)
                            .font(.system(size: 14))
                        Text(playlist.name)
                            .font(AppTypography.callout)
                            .foregroundColor(AppColors.onBackground)
                    }
                } else {
                    Text("Not selected")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                        .italic()
                }
                
                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.surface)
        .cornerRadius(12)
    }
    
    // MARK: - Connection Section
    
    private var connectionSection: some View {
        VStack(spacing: AppSpacing.lg) {
            AppCard {
                VStack(spacing: AppSpacing.md) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 48))
                        .foregroundColor(AppColors.secondary)
                    
                    Text("Connect to Spotify")
                        .font(AppTypography.title2)
                        .foregroundColor(AppColors.onBackground)
                    
                    Text("Access your playlists to set up VO₂ Max training")
                        .font(AppTypography.callout)
                        .foregroundColor(AppColors.secondary)
                        .multilineTextAlignment(.center)
                    
                    AppButton("Connect Spotify", style: .spotify) {
                        spotifyViewModel.connect()
                    }
                    .disabled(!spotifyViewModel.canConnect)
                }
                .padding(AppSpacing.lg)
            }
        }
    }
    
    // MARK: - Spotify-Style Browsing Section (80% of screen)
    
    private var playlistBrowsingSection: some View {
        VStack(spacing: 0) {
            // Recently Played Section (First 8 playlists, Spotify-style)
            recentlyPlayedSection
            
            // Browse Library Button
            browseLibraryButton
                .padding(.top, 12)
        }
    }
    
    // MARK: - Recently Played Section (Spotify Layout)
    
    private var recentlyPlayedSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Section header
            HStack {
                Text("Recently Played [DEBUG]")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.onBackground)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            // Spotify-style 2-column grid (first 8 playlists)
            recentlyPlayedGrid
        }
    }
    
    private var recentlyPlayedGrid: some View {
        Group {
            switch spotifyViewModel.playlistFetchStatus {
            case .notStarted, .fetching:
                loadingView
            case .loaded:
                if spotifyViewModel.availablePlaylists.isEmpty {
                    emptyPlaylistsView
                } else {
                    spotifyStyleGrid
                }
            case .error(let message):
                errorView(message: message)
            }
        }
    }
    
    private var spotifyStyleGrid: some View {
        let recentPlaylists = Array(spotifyViewModel.availablePlaylists.prefix(8)) // First 8 like Spotify
        
        return ScrollView {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 2), // DEBUG: Very tight spacing
                GridItem(.flexible())
            ], spacing: 6) { // DEBUG: Very tight rows
                ForEach(recentPlaylists) { playlist in
                    PlaylistCard(
                        playlist: playlist,
                        selectionBadge: getBadgeForAssignment(getPlaylistAssignment(playlist))
                    ) {
                        selectedPlaylistForAction = playlist
                        showingActionSheet = true
                    }
                }
            }
        }
    }
    
    private var browseLibraryButton: some View {
        Button(action: {
            showingFullLibrary = true
        }) {
            HStack {
                Text("See All Your Playlists")
                    .font(AppTypography.callout)
                    .foregroundColor(AppColors.onBackground)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.secondary)
            }
            .padding(AppSpacing.md)
            .background(AppColors.surface)
            .cornerRadius(12)
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: AppSpacing.md) {
            ProgressView()
                .tint(AppColors.primary)
            Text("Loading playlists...")
                .font(AppTypography.callout)
                .foregroundColor(AppColors.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
    }
    
    private var emptyPlaylistsView: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "music.note.list")
                .font(.system(size: 32))
                .foregroundColor(AppColors.secondary)
            
            Text("No playlists found")
                .font(AppTypography.callout)
                .foregroundColor(AppColors.secondary)
            
            Text("Create some playlists in Spotify first")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 32))
                .foregroundColor(AppColors.error)
            
            Text("Error loading playlists")
                .font(AppTypography.callout)
                .foregroundColor(AppColors.error)
            
            Text(message)
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.lg)
            
            VStack(spacing: AppSpacing.sm) {
                AppButton("Retry", style: .secondary) {
                    spotifyViewModel.fetchPlaylists()
                }
                
                if message.contains("Session expired") || message.contains("reconnect") {
                    AppButton("Reconnect to Spotify", style: .spotify) {
                        spotifyViewModel.connect()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
    }
    

    
    // MARK: - Action Sheet
    
    private var actionSheetButtons: [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        
        guard let playlist = selectedPlaylistForAction else {
            return [.cancel()]
        }
        
        let currentAssignment = getPlaylistAssignment(playlist)
        
        // High Intensity option
        if currentAssignment != .highIntensity {
            buttons.append(.default(Text("Use for High Intensity")) {
                spotifyViewModel.selectHighIntensityPlaylist(playlist)
                print("🎵 Assigned \(playlist.name) to High Intensity")
            })
        }
        
        // Rest option
        if currentAssignment != .rest {
            buttons.append(.default(Text("Use for Rest")) {
                spotifyViewModel.selectRestPlaylist(playlist)
                print("🎵 Assigned \(playlist.name) to Rest")
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
                print("🗑️ Removed assignment for \(playlist.name)")
            })
        }
        
        buttons.append(.cancel())
        return buttons
    }
    
    // MARK: - Full Library View
    
    private var fullLibraryView: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: AppSpacing.xs) {
                Text("Your Library")
                    .font(AppTypography.largeTitle)
                    .foregroundColor(AppColors.onBackground)
                
                Text("All \(spotifyViewModel.availablePlaylists.count) playlists")
                    .font(AppTypography.callout)
                    .foregroundColor(AppColors.secondary)
            }
            .padding(.bottom, AppSpacing.md)
            
            // All playlists in condensed list
            fullPlaylistList
        }
    }
    
    private var fullPlaylistList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(spotifyViewModel.availablePlaylists) { playlist in
                    CondensedPlaylistRow(
                        playlist: playlist,
                        assignment: getPlaylistAssignment(playlist)
                    ) {
                        selectedPlaylistForAction = playlist
                        showingActionSheet = true
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }
    
    // MARK: - Helper Methods
    
    private func getBadgeForAssignment(_ assignment: PlaylistAssignment) -> PlaylistBadge? {
        switch assignment {
        case .none:
            return nil
        case .highIntensity:
            return .highIntensity
        case .rest:
            return .rest
        }
    }
    
    private func getPlaylistAssignment(_ playlist: SpotifyPlaylist) -> PlaylistAssignment {
        if playlist.id == spotifyViewModel.playlistSelection.highIntensityPlaylistID {
            return .highIntensity
        } else if playlist.id == spotifyViewModel.playlistSelection.restPlaylistID {
            return .rest
        } else {
            return .none
        }
    }
}



#Preview {
    PlaylistSelectionView()
}
