//
//  VO2TrainingBottomDrawer.swift
//  RunBeat
//
//  Created by Claude Code on 9/11/25.
//

import SwiftUI

struct VO2TrainingBottomDrawer: View {
    @StateObject private var musicViewModel = MusicViewModel.shared
    @EnvironmentObject var appState: AppState
    @State private var isExpanded: Bool = false

    // MARK: - State Management

    private var shouldShowDrawer: Bool {
        appState.vo2TrainingState == .setup || appState.vo2TrainingState == .active || appState.vo2TrainingState == .complete
    }

    private var isTrainingActive: Bool {
        appState.vo2TrainingState == .active
    }

    private var drawerContent: DrawerContent {
        if !musicViewModel.isAuthorized {
            return .connectMusic
        } else if isTrainingActive || appState.vo2TrainingState == .complete {
            return .trackInfo
        } else {
            return .playlistStatus
        }
    }
    
    private var drawerHeight: CGFloat {
        switch drawerContent {
        case .connectMusic:
            return 120 // Button + padding
        case .trackInfo:
            return 100 // Track info only - reduced to fix excessive padding
        case .playlistStatus:
            return isExpanded ? 400 : 150 // Setup states
        }
    }

    private var isDrawerExpandable: Bool {
        drawerContent == .playlistStatus && !isTrainingActive // Only expandable when showing playlist status during setup
    }

    private var shouldAutoExpand: Bool {
        musicViewModel.isAuthorized &&
        !musicViewModel.playlistSelection.isComplete &&
        !isTrainingActive &&
        drawerContent == .playlistStatus
    }

    enum DrawerContent {
        case connectMusic
        case trackInfo
        case playlistStatus
    }
    
    // MARK: - Body
    
    var body: some View {
        if shouldShowDrawer {
            VStack(spacing: 0) {
                // Drag Handle (only for expandable states)
                if isDrawerExpandable {
                    dragHandle
                }
                
                drawerContentContainer
                    .padding(.bottom, 20 + AppSpacing.sm)
            }
            .frame(height: drawerHeight)
            .frame(maxWidth: .infinity)
            .background(AppColors.surface)
            .clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: 16,
                    bottomLeadingRadius: 0,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 16
                )
            )
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
            .gesture(isDrawerExpandable ? dragGesture : nil)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: shouldShowDrawer)
            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: isExpanded)
            .onTapGesture {
                if isDrawerExpandable && !isExpanded && !isTrainingActive {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                        isExpanded = true
                    }
                }
            }
            .onAppear {
                // Auto-expand immediately if connected but playlist selection incomplete
                if shouldAutoExpand {
                    isExpanded = true
                }
            }
            // Safe area handling now managed at container level in parent view
            .onChange(of: appState.vo2TrainingState) { oldValue, newValue in
                // Collapse drawer when training starts to show locked track display
                if newValue == .active && isExpanded {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        isExpanded = false
                    }
                }
            }
        }
    }
    
    // MARK: - Drag Handle
    
    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(AppColors.secondary.opacity(0.3))
            .frame(width: 36, height: AppSpacing.xs)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Content Views
    
    // MARK: - Content-Based Animation Container
    
    @ViewBuilder
    private var drawerContentContainer: some View {
        switch drawerContent {
        case .connectMusic:
            connectMusicContent
        case .trackInfo:
            trackInfoContent
        case .playlistStatus:
            smoothPlaylistStatusContent // New smooth version
        }
    }
    
    // New smooth content for playlist status with content-based animation
    private var smoothPlaylistStatusContent: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded content (slides in/out)
                expandedPlaylistContent
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .move(edge: .bottom).combined(with: .opacity)
                    ))
            } else {
                // Collapsed content (only when collapsed)
                collapsedPlaylistContent
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                        removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                    ))
            }
        }
    }
    
    // Collapsed state content
    private var collapsedPlaylistContent: some View {
        playlistStatusSummary
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.sm) // Reduced from .md to .sm for better balance
    }
    
    // Expanded state content  
    private var expandedPlaylistContent: some View {
        playlistSelectionGrid
            .padding(.horizontal, AppSpacing.lg)
            // No top padding - collapsed content's padding is still there (invisible)
    }

    @ViewBuilder
    private var drawerContentView: some View {
        switch drawerContent {
        case .connectMusic:
            connectMusicContent
        case .trackInfo:
            trackInfoContent
        case .playlistStatus:
            playlistStatusContent
        }
    }

    private var connectMusicContent: some View {
        // Fixed overlay - no expansion, just authorize and fetch
        VStack(spacing: 0) {
            AppButton("Authorize Apple Music", style: .primary) {
                Task {
                    await musicViewModel.authorize()
                    if musicViewModel.isAuthorized {
                        await musicViewModel.fetchPlaylists()
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
        .padding(.top, AppSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var trackInfoContent: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded: Track info + playlist selection
                VStack(spacing: AppSpacing.lg) {
                    // Current track display
                    currentTrackDisplay
                    
                    // Playlist selection interface
                    playlistSelectionContent
                }
                .padding(.horizontal, AppSpacing.lg)
                .padding(.top, AppSpacing.lg)
            } else {
                // Collapsed: Just track info
                currentTrackDisplay
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.lg)
            }
        }
    }
    
    private var currentTrackDisplay: some View {
        HStack(spacing: 0) {
            // Display current track info
            HStack(spacing: AppSpacing.sm) {
                // Artwork
                if let artwork = musicViewModel.currentAlbumArtwork {
                    Image(uiImage: artwork)
                        .resizable()
                        .frame(width: 50, height: 50)
                        .cornerRadius(6)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(AppColors.surface)
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.secondary)
                        )
                }

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(musicViewModel.currentTrack.isEmpty ? "No track playing" : musicViewModel.currentTrack)
                        .font(AppTypography.callout.weight(.medium))
                        .foregroundColor(AppColors.onBackground)
                        .lineLimit(1)

                    Text(musicViewModel.currentArtist.isEmpty ? "Select a playlist" : musicViewModel.currentArtist)
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Play/pause button (show during training and completion)
                if isTrainingActive || appState.vo2TrainingState == .complete {
                    Button(action: {
                        musicViewModel.togglePlayPause()
                    }) {
                        Image(systemName: musicViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(AppColors.onBackground)
                    }
                }
            }
            
            // Show expand chevron only when not training and expandable
            if !isExpanded && !isTrainingActive && isDrawerExpandable {
                Image(systemName: "chevron.up")
                    .font(AppTypography.caption.weight(.medium))
                    .foregroundColor(AppColors.secondary)
                    .padding(.leading, AppSpacing.sm)
            }
        }
    }
    
    
    private var playlistSelectionContent: some View {
        Text("Playlist selection placeholder")
            .onReceive(NotificationCenter.default.publisher(for: .playlistSelectionComplete)) { _ in
                withAnimation(.easeIn(duration: 0.3)) {
                    isExpanded = false
                }
            }
    }
    
    private var playlistStatusContent: some View {
        VStack(spacing: 0) {
            if isExpanded {
                // Expanded: Show simplified playlist selection grid
                playlistSelectionGrid
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
            } else {
                // Collapsed: Show current playlist assignments
                playlistStatusSummary
                    .padding(.horizontal, AppSpacing.lg)
                    .padding(.top, AppSpacing.md)
            }
        }
    }
    
    private var playlistStatusSummary: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Work")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primary)

                if let workPlaylist = musicViewModel.selectedHighIntensityPlaylist {
                    SelectedMusicPlaylistCard(playlist: workPlaylist, type: .highIntensity) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                } else {
                    EmptyMusicPlaylistCard(type: .highIntensity) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.zone1)

                if let recoveryPlaylist = musicViewModel.selectedRestPlaylist {
                    SelectedMusicPlaylistCard(playlist: recoveryPlaylist, type: .rest) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                } else {
                    EmptyMusicPlaylistCard(type: .rest) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                }
            }
        }
    }
    
    private var playlistSelectionGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                // Selected Playlists Section (same as PlaylistSelectionView)
                selectedPlaylistsSection
                
                // Available Playlists Section
                availablePlaylistsSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .actionSheet(isPresented: $showingActionSheet) {
            playlistActionSheet
        }
        .onChange(of: showingActionSheet) { _, isShowing in
            if !isShowing {
                selectedPlaylistForAction = nil
            }
        }
        .onAppear {
            // Fetch playlists when view appears
            if musicViewModel.isAuthorized && musicViewModel.availablePlaylists.isEmpty {
                Task {
                    await musicViewModel.fetchPlaylists()
                }
            }
        }
    }
    
    // MARK: - Selected Playlists Section (from PlaylistSelectionView)
    
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
            
            // Selected playlists grid (Work | Recovery)
            selectedPlaylistsGrid
        }
    }
    
    private var selectedPlaylistsGrid: some View {
        HStack(spacing: 16) {
            // Work Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Work")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.primary)
                
                if let highIntensityPlaylist = musicViewModel.selectedHighIntensityPlaylist {
                    SelectedMusicPlaylistCard(playlist: highIntensityPlaylist, type: .highIntensity) {
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

            // Recovery Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.zone1)

                if let restPlaylist = musicViewModel.selectedRestPlaylist {
                    SelectedMusicPlaylistCard(playlist: restPlaylist, type: .rest) {
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

    @State private var selectedPlaylistForAction: MusicPlaylist?
    @State private var showingActionSheet = false
    
    private var availablePlaylistsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Available Playlists")
                .font(AppTypography.headline)
                .foregroundColor(AppColors.onBackground)
                .fontWeight(.medium)
            
            if unassignedPlaylists.isEmpty {
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
                .padding(.top, AppSpacing.md)
            } else {
                // Use existing grid layout
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(unassignedPlaylists) { playlist in
                        AvailableMusicPlaylistCard(playlist: playlist) {
                            selectedPlaylistForAction = playlist
                            showingActionSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private var unassignedPlaylists: [MusicPlaylist] {
        // Filter out already assigned playlists for cleaner organization
        musicViewModel.availablePlaylists.filter { playlist in
            playlist.id != musicViewModel.playlistSelection.highIntensityPlaylistID &&
            playlist.id != musicViewModel.playlistSelection.restPlaylistID
        }
    }
    
    // MARK: - Action Sheet
    
    private var playlistActionSheet: ActionSheet {
        guard let playlist = selectedPlaylistForAction else {
            return ActionSheet(title: Text("Error"), buttons: [.cancel()])
        }
        
        let currentAssignment = getPlaylistAssignment(playlist)
        var buttons: [ActionSheet.Button] = []
        
        // Work option (updated text)
        if currentAssignment != .highIntensity {
            buttons.append(.default(Text("Use for Work")) {
                musicViewModel.selectHighIntensityPlaylist(playlist)
            })
        }

        // Recovery option (updated text)
        if currentAssignment != .rest {
            buttons.append(.default(Text("Use for Recovery")) {
                musicViewModel.selectRestPlaylist(playlist)
            })
        }

        // Remove assignment option
        if currentAssignment != .none {
            buttons.append(.destructive(Text("Remove Assignment")) {
                if currentAssignment == .highIntensity {
                    musicViewModel.playlistSelection.highIntensity = nil
                } else if currentAssignment == .rest {
                    musicViewModel.playlistSelection.rest = nil
                }
                musicViewModel.savePlaylistSelection()
            })
        }
        
        buttons.append(.cancel() {
            selectedPlaylistForAction = nil
        })

        return ActionSheet(
            title: Text(playlist.name),
            message: Text("How would you like to use this playlist?"),
            buttons: buttons
        )
    }
    
    // MARK: - Helper Methods
    
    private func getPlaylistAssignment(_ playlist: MusicPlaylist) -> MusicPlaylistAssignment {
        if playlist.id == musicViewModel.playlistSelection.highIntensityPlaylistID {
            return .highIntensity
        } else if playlist.id == musicViewModel.playlistSelection.restPlaylistID {
            return .rest
        } else {
            return .none
        }
    }
    
    
    // MARK: - Gestures
    
    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { gesture in
                guard isDrawerExpandable && !isTrainingActive else { return }
                
                let translation = gesture.translation.height
                
                if isExpanded {
                    // Collapse when dragged down significantly
                    if translation > 30 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = false
                        }
                    }
                } else {
                    // Expand when dragged up significantly
                    if translation < -20 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                }
            }
            .onEnded { _ in
                // State changes now happen during drag, no need for onEnded logic
            }
    }
}

// MARK: - Helper Types

enum MusicPlaylistAssignment {
    case highIntensity
    case rest
    case none
}

#Preview {
    ZStack {
        AppColors.background
            .ignoresSafeArea()

        VStack {
            Spacer()
            VO2TrainingBottomDrawer()
        }
    }
    .environmentObject(AppState())
}


