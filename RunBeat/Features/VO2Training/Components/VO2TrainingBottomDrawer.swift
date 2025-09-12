//
//  VO2TrainingBottomDrawer.swift
//  RunBeat
//
//  Created by Claude Code on 9/11/25.
//

import SwiftUI

struct VO2TrainingBottomDrawer: View {
    @StateObject private var spotifyViewModel = SpotifyViewModel.shared
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
        if !spotifyViewModel.isConnected {
            return .connectSpotify
        } else if isTrainingActive || appState.vo2TrainingState == .complete {
            return .trackInfo
        } else {
            return .playlistStatus
        }
    }
    
    private var drawerHeight: CGFloat {
        switch drawerContent {
        case .connectSpotify:
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
        spotifyViewModel.isConnected && 
        !spotifyViewModel.playlistSelection.isComplete && 
        !isTrainingActive &&
        drawerContent == .playlistStatus
    }
    
    enum DrawerContent {
        case connectSpotify
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
                // Auto-expand if connected but playlist selection incomplete
                if shouldAutoExpand {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.5)) {
                        isExpanded = true
                    }
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
        case .connectSpotify:
            connectSpotifyContent
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
        case .connectSpotify:
            connectSpotifyContent
        case .trackInfo:
            trackInfoContent
        case .playlistStatus:
            playlistStatusContent
        }
    }
    
    private var connectSpotifyContent: some View {
        // Fixed overlay - no expansion, just the connect button
        VStack(spacing: 0) {
            AppButton("Connect Spotify", style: .spotify) {
                spotifyViewModel.connect()
            }
            .disabled(!spotifyViewModel.canConnect)
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
            // Use the reusable TrackDisplayWithControls component
            TrackDisplayWithControls(
                trackInfo: spotifyViewModel.currentTrackInfo,
                isPlaying: spotifyViewModel.isPlaying,
                showControls: isTrainingActive || appState.vo2TrainingState == .complete, // Show controls during active training and completion
                onPlayPauseToggle: {
                    spotifyViewModel.togglePlayPause()
                }
            )
            
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
        PlaylistSectionNavigator()
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
                
                if let workPlaylist = spotifyViewModel.selectedHighIntensityPlaylist {
                    SelectedPlaylistCard(playlist: workPlaylist, type: .highIntensity) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                } else {
                    EmptySelectionCard(type: .highIntensity) {
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
                
                if let recoveryPlaylist = spotifyViewModel.selectedRestPlaylist {
                    SelectedPlaylistCard(playlist: recoveryPlaylist, type: .rest) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.75)) {
                            isExpanded = true
                        }
                    }
                } else {
                    EmptySelectionCard(type: .rest) {
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
        .onAppear {
            // Fetch playlists when view appears
            if spotifyViewModel.isConnected {
                spotifyViewModel.fetchPlaylists()
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
            
            // Recovery Section
            VStack(alignment: .leading, spacing: 8) {
                Text("Recovery")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppColors.zone1)
                
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
    
    @State private var selectedPlaylistForAction: SpotifyPlaylist?
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
                // Use existing grid layout from PlaylistSelectionView
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(unassignedPlaylists) { playlist in
                        AvailablePlaylistCard(playlist: playlist) {
                            selectedPlaylistForAction = playlist
                            showingActionSheet = true
                        }
                    }
                }
            }
        }
    }
    
    private var unassignedPlaylists: [SpotifyPlaylist] {
        // Filter out already assigned playlists for cleaner organization
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
        
        // Work option (updated text)
        if currentAssignment != .highIntensity {
            buttons.append(.default(Text("Use for Work")) {
                spotifyViewModel.selectHighIntensityPlaylist(playlist)
            })
        }
        
        // Recovery option (updated text)
        if currentAssignment != .rest {
            buttons.append(.default(Text("Use for Recovery")) {
                spotifyViewModel.selectRestPlaylist(playlist)
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


