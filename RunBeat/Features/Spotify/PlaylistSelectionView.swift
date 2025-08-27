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
                            
                            // Main Content
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
    
    // MARK: - Playlist Grid Browsing Section
    
    private var playlistBrowsingSection: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Selected Playlists Section
                selectedPlaylistsSection
                
                // Available Playlists Section  
                availablePlaylistsSection
                
                // Browse Library Button
                browseLibraryButton
                    .padding(.top, 12)
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - Selected Playlists Section
    
    private var selectedPlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Selected Playlists")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.onBackground)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            // Selected playlists grid (High Intensity | Rest)
            selectedPlaylistsGrid
        }
    }
    
    // MARK: - Available Playlists Section
    
    private var availablePlaylistsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text("Choose Playlists")
                    .font(AppTypography.title2)
                    .foregroundColor(AppColors.onBackground)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            // Available playlists grid (2 columns)
            availablePlaylistsGrid
        }
    }
    
    private var selectedPlaylistsGrid: some View {
        HStack(spacing: 16) {
            // High Intensity Section
            VStack(alignment: .leading, spacing: 8) {
                Text("High Intensity")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if let highIntensityPlaylist = spotifyViewModel.selectedHighIntensityPlaylist {
                    SelectedPlaylistCard(
                        playlist: highIntensityPlaylist,
                        type: .highIntensity
                    ) {
                        selectedPlaylistForAction = highIntensityPlaylist
                        showingActionSheet = true
                    }
                } else {
                    Text("Choose from playlists below")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(height: 60, alignment: .center) // Maintain spacing for when card appears
                }
            }
            .frame(maxWidth: .infinity)
            
            // Rest Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Rest")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                if let restPlaylist = spotifyViewModel.selectedRestPlaylist {
                    SelectedPlaylistCard(
                        playlist: restPlaylist,
                        type: .rest
                    ) {
                        selectedPlaylistForAction = restPlaylist
                        showingActionSheet = true
                    }
                } else {
                    Text("Choose from playlists below")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.gray)
                        .frame(height: 60, alignment: .center) // Maintain spacing for when card appears
                }
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var availablePlaylistsGrid: some View {
        Group {
            switch spotifyViewModel.playlistFetchStatus {
            case .notStarted, .fetching:
                loadingView
            case .loaded:
                if spotifyViewModel.availablePlaylists.isEmpty {
                    emptyPlaylistsView
                } else {
                    availablePlaylistsContent
                }
            case .error(let message):
                errorView(message: message)
            }
        }
    }
    
    private var availablePlaylistsContent: some View {
        let availablePlaylists = spotifyViewModel.availablePlaylists.filter { playlist in
            // Only show playlists that aren't currently selected
            playlist.id != spotifyViewModel.playlistSelection.highIntensityPlaylistID &&
            playlist.id != spotifyViewModel.playlistSelection.restPlaylistID
        }
        
        return LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ], spacing: 12) {
            ForEach(availablePlaylists) { playlist in
                AvailablePlaylistCard(playlist: playlist) {
                    selectedPlaylistForAction = playlist
                    showingActionSheet = true
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
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                ForEach(spotifyViewModel.availablePlaylists) { playlist in
                    AvailablePlaylistCard(playlist: playlist) {
                        selectedPlaylistForAction = playlist
                        showingActionSheet = true
                    }
                }
            }
            .padding(.horizontal, 12)
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
