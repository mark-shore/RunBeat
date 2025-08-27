//
//  PlaylistCell.swift
//  RunBeat
//
//  Visual playlist cell component for music app-style browsing
//

import SwiftUI

// MARK: - Playlist Assignment Enum

enum PlaylistAssignment {
    case none
    case highIntensity
    case rest
    
    var badgeText: String? {
        switch self {
        case .none:
            return nil
        case .highIntensity:
            return "H"
        case .rest:
            return "R"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .none:
            return .clear
        case .highIntensity:
            return Color(red: 1.0, green: 0.27, blue: 0.0) // RunBeat primary color
        case .rest:
            return Color.blue // Rest color
        }
    }
}

struct PlaylistCell: View {
    let playlist: SpotifyPlaylist
    let selectionMode: PlaylistSelectionMode?
    let isSelected: Bool
    let isOtherModeSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Playlist Artwork (Primary Visual Element)
            artworkSection
            
            // Playlist Info
            playlistInfo
        }
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: borderWidth)
        )
        .overlay(alignment: .topTrailing) {
            selectionBadge
        }
        .scaleEffect(isOtherModeSelected ? 0.95 : 1.0)
        .opacity(isOtherModeSelected ? 0.6 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isOtherModeSelected)
        .onTapGesture {
            if !isOtherModeSelected {
                onTap()
            }
        }
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        ZStack {
            // Background for loading state
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface)
                .frame(height: 120)
            
            // Playlist artwork
            if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(height: 120)
                .clipped()
                .cornerRadius(8)
            } else {
                artworkPlaceholder
                    .frame(height: 120)
                    .cornerRadius(8)
            }
            
            // Play icon overlay for visual appeal
            if !isOtherModeSelected {
                playIconOverlay
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            AppColors.surface
            
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.secondary)
                
                Text("Playlist")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.secondary)
            }
        }
    }
    
    private var playIconOverlay: some View {
        ZStack {
            // Subtle dark overlay
            Color.black.opacity(0.3)
                .cornerRadius(8)
            
            // Play icon
            Image(systemName: "play.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(.white.opacity(0.9))
                .shadow(radius: 2)
        }
        .opacity(isSelected ? 1.0 : 0.0)
    }
    
    // MARK: - Playlist Info
    
    private var playlistInfo: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Playlist name
            Text(playlist.displayName)
                .font(AppTypography.callout)
                .foregroundColor(AppColors.onBackground)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Track count and creator
            HStack {
                Text("\(playlist.trackCount)")
                    .font(AppTypography.caption)
                    .foregroundColor(modeColor)
                    .fontWeight(.medium)
                
                Text(playlist.trackCount == 1 ? "track" : "tracks")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary)
                
                Spacer()
            }
            
            // Creator info
            Text("by \(playlist.owner)")
                .font(AppTypography.caption2)
                .foregroundColor(AppColors.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }
    
    // MARK: - Selection Badge
    
    private var selectionBadge: some View {
        Group {
            if isSelected {
                ZStack {
                    Circle()
                        .fill(modeColor)
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: -8, y: 8)
                .shadow(radius: 2)
            }
        }
    }
    
    // MARK: - Visual Properties
    
    private var backgroundColor: Color {
        if isOtherModeSelected {
            return AppColors.surface.opacity(0.5)
        } else if isSelected {
            return modeColor.opacity(0.1)
        } else {
            return AppColors.surface
        }
    }
    
    private var borderColor: Color {
        if isOtherModeSelected {
            return Color.clear
        } else if isSelected {
            return modeColor
        } else {
            return Color.clear
        }
    }
    
    private var borderWidth: CGFloat {
        isSelected ? 2 : 0
    }
    
    private var modeColor: Color {
        switch selectionMode {
        case .highIntensity:
            return AppColors.primary // Red-orange
        case .rest:
            return AppColors.zone1   // Blue/green
        case .none:
            return AppColors.secondary
        }
    }
}

// MARK: - Selection Mode Enum

enum PlaylistSelectionMode: CaseIterable, Hashable {
    case highIntensity
    case rest
    
    var title: String {
        switch self {
        case .highIntensity:
            return "High Intensity"
        case .rest:
            return "Rest"
        }
    }
    
    var description: String {
        switch self {
        case .highIntensity:
            return "Energetic music for 4-minute intervals"
        case .rest:
            return "Calming music for 3-minute breaks"
        }
    }
    
    var color: Color {
        switch self {
        case .highIntensity:
            return AppColors.primary
        case .rest:
            return AppColors.zone1
        }
    }
    
    var icon: String {
        switch self {
        case .highIntensity:
            return "bolt.fill"
        case .rest:
            return "leaf.fill"
        }
    }
}

// MARK: - Exact Spotify-Style Grid Card (Ultra-Compact like screenshot)

struct SpotifyGridCard: View {
    let playlist: SpotifyPlaylist
    let assignment: PlaylistAssignment
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            artworkSection
            playlistTitle
        }
        .onTapGesture {
            onTap()
        }
    }
    
    private var artworkSection: some View {
        ZStack {
            // Ultra-compact square artwork (exactly like Spotify screenshot)
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: 100) // Ultra-compact like Spotify screenshot
            
            // Playlist artwork or placeholder
            if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    spotifyPlaceholder
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(maxHeight: 100)
                .clipped()
                .cornerRadius(6)
            } else {
                spotifyPlaceholder
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxHeight: 100)
                    .cornerRadius(6)
            }
            
            // Assignment overlay indicator (very subtle)
            if assignment != .none {
                assignmentOverlay
            }
        }
    }
    
    private var spotifyPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            Image(systemName: "music.note")
                .font(.system(size: 20))
                .foregroundColor(.gray)
        }
    }
    
    private var assignmentOverlay: some View {
        VStack {
            HStack {
                Spacer()
                ZStack {
                    Circle()
                        .fill(assignment.badgeColor)
                        .frame(width: 18, height: 18)
                    
                    Text(assignment.badgeText ?? "")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                }
                .shadow(radius: 1)
            }
            Spacer()
        }
        .padding(4)
    }
    
    private var playlistTitle: some View {
        Text(playlist.displayName)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.white)
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }
}

// MARK: - Spotify-Style Training Card (Exactly like screenshot)

struct SpotifyTrainingCard: View {
    let title: String
    let displayInfo: SpotifyViewModel.PlaylistDisplayInfo
    let onTap: () -> Void
    
    // Backwards-compatible initializer
    init(title: String, playlist: SpotifyPlaylist?, isConfigured: Bool, onTap: @escaping () -> Void) {
        self.title = title
        self.onTap = onTap
        
        if let playlist = playlist {
            self.displayInfo = .loaded(playlist)
        } else if isConfigured {
            self.displayInfo = .loading
        } else {
            self.displayInfo = .notSelected
        }
    }
    
    // New preferred initializer
    init(title: String, displayInfo: SpotifyViewModel.PlaylistDisplayInfo, onTap: @escaping () -> Void) {
        self.title = title
        self.displayInfo = displayInfo
        self.onTap = onTap
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Title above card
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
            
            // Spotify-style horizontal card - exact match to reference
            Button(action: onTap) {
                HStack(spacing: 0) {
                    // Square artwork fills entire card height (60x60pt, no internal padding)
                    artworkImage
                    
                    // Playlist name with proper padding from artwork
                    VStack(alignment: .leading) {
                        Spacer() // Center multi-line text vertically
                        
                        HStack {
                            Text(displayInfo.displayText)
                                .font(.system(size: 13, weight: .bold)) // Bold font to match Spotify
                                .foregroundColor(.white)
                                .lineLimit(2) // Allow wrapping to 2 lines like Spotify
                                .multilineTextAlignment(.leading)
                                .lineSpacing(1) // Tight line spacing
                            
                            Spacer()
                        }
                        
                        Spacer() // Center multi-line text vertically
                    }
                    .padding(.leading, 8) // Reduced padding from artwork
                    .padding(.trailing, 12) // Reduced right padding
                }
                .frame(height: 60) // Uniform 60pt height for ALL cards
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
    

    
    private var artworkImage: some View {
        // Square artwork that fills entire card height (60x60pt, no internal padding)
        ZStack {
            if let playlist = displayInfo.playlist,
               let imageURL = playlist.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: 60, height: 60)
                .clipped()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            } else {
                artworkPlaceholder
                    .frame(width: 60, height: 60)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.4)
            
            Image(systemName: artworkIconName)
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.8))
        }
    }
    
    private var artworkIconName: String {
        switch displayInfo {
        case .loading:
            return "arrow.clockwise"
        case .error:
            return "exclamationmark.triangle"
        default:
            return "music.note"
        }
    }
    

}

// MARK: - Legacy Training Setup Card (keeping for compatibility)

struct TrainingSetupCard: View {
    let title: String
    let duration: String
    let emoji: String
    let playlist: SpotifyPlaylist?
    let isConfigured: Bool
    let onTap: () -> Void
    
    var body: some View {
        SpotifyTrainingCard(
            title: title,
            playlist: playlist,
            isConfigured: isConfigured,
            onTap: onTap
        )
    }
}

// MARK: - Simplified Playlist Cell for Direct Selection

struct SimplifiedPlaylistCell: View {
    let playlist: SpotifyPlaylist
    let assignment: PlaylistAssignment
    let onTap: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            // Square artwork (proper aspect ratio)
            artworkSection
            
            // Playlist metadata
            playlistMetadata
        }
        .background(AppColors.surface)
        .cornerRadius(12)
        .onTapGesture {
            onTap()
        }
    }
    
    // MARK: - Artwork Section
    
    private var artworkSection: some View {
        ZStack {
            // Square artwork background
            RoundedRectangle(cornerRadius: 8)
                .fill(AppColors.surface)
                .aspectRatio(1, contentMode: .fit) // Perfect square
            
            // Playlist artwork or placeholder
            if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .aspectRatio(1, contentMode: .fit)
                .clipped()
                .cornerRadius(8)
            } else {
                artworkPlaceholder
                    .aspectRatio(1, contentMode: .fit)
                    .cornerRadius(8)
            }
            
            // Assignment badge
            if let badgeText = assignment.badgeText {
                VStack {
                    HStack {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(assignment.badgeColor)
                                .frame(width: 24, height: 24)
                            
                            Text(badgeText)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    Spacer()
                }
                .padding(AppSpacing.xs)
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            AppColors.surface
            
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 32))
                    .foregroundColor(AppColors.secondary)
                
                Text("Playlist")
                    .font(AppTypography.caption2)
                    .foregroundColor(AppColors.secondary)
            }
        }
    }
    
    // MARK: - Playlist Metadata
    
    private var playlistMetadata: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            // Playlist name
            Text(playlist.displayName)
                .font(AppTypography.callout)
                .foregroundColor(AppColors.onBackground)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Track count
            Text("\(playlist.trackCount) tracks")
                .font(AppTypography.caption)
                .foregroundColor(AppColors.secondary)
        }
        .padding(.horizontal, AppSpacing.sm)
        .padding(.bottom, AppSpacing.sm)
    }
}

// MARK: - Condensed Playlist Row (Exactly like Spotify screenshot)

struct CondensedPlaylistRow: View {
    let playlist: SpotifyPlaylist
    let assignment: PlaylistAssignment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Small square artwork (exactly like Spotify)
                artworkSection
                
                // Playlist info
                VStack(alignment: .leading, spacing: 2) {
                    Text(playlist.displayName)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text("\(playlist.trackCount) songs")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Assignment indicator
                if assignment != .none {
                    ZStack {
                        Circle()
                            .fill(assignment.badgeColor)
                            .frame(width: 20, height: 20)
                        
                        Text(assignment.badgeText ?? "")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.clear)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkSection: some View {
        ZStack {
            // Very small square artwork (like Spotify list)
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 48, height: 48)
            
            // Playlist artwork or placeholder
            if let imageURL = playlist.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    condensedPlaceholder
                }
                .frame(width: 48, height: 48)
                .clipped()
                .cornerRadius(4)
            } else {
                condensedPlaceholder
            }
        }
    }
    
    private var condensedPlaceholder: some View {
        ZStack {
            Color.gray.opacity(0.2)
            
            Image(systemName: "music.note")
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(width: 48, height: 48)
        .cornerRadius(4)
    }
}



// MARK: - Selection Type Enum

enum SelectionType {
    case highIntensity
    case rest
    
    var title: String {
        switch self {
        case .highIntensity: return "High Intensity"
        case .rest: return "Rest"
        }
    }
    
    var color: Color {
        switch self {
        case .highIntensity: return Color(red: 1.0, green: 0.27, blue: 0.0) // Brand red-orange
        case .rest: return .blue
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .highIntensity: return Color(red: 1.0, green: 0.27, blue: 0.0).opacity(0.15) // Brand red-orange
        case .rest: return Color.blue.opacity(0.15)
        }
    }
}

// MARK: - Selected Playlist Card (with color accent)

struct SelectedPlaylistCard: View {
    let playlist: SpotifyPlaylist
    let type: SelectionType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Square artwork fills entire card height (60x60pt)
                artworkImage
                
                // Playlist info
                VStack(alignment: .leading) {
                    Spacer()
                    
                    HStack {
                        Text(playlist.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            }
            .frame(height: 60)
            .background(type.backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(type.color, lineWidth: 2)
            )
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkImage: some View {
        ZStack {
            if let imageURL = playlist.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: 60, height: 60)
                .clipped()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            } else {
                artworkPlaceholder
                    .frame(width: 60, height: 60)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(type.color.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(type.color)
            )
    }
}

// MARK: - Empty Selection Card (minimal dashed border)

struct EmptySelectionCard: View {
    let type: SelectionType
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            // Centered plus icon only
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(type.color)
                .frame(width: 60, height: 60)
                .background(Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(
                            type.color,
                            style: StrokeStyle(
                                lineWidth: 2,
                                dash: [6, 4] // Dashed pattern: 6pt dash, 4pt gap
                            )
                        )
                )
                .opacity(0.7) // Subtle opacity for refined look
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Available Playlist Card (standard)

struct AvailablePlaylistCard: View {
    let playlist: SpotifyPlaylist
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Square artwork fills entire card height (60x60pt)
                artworkImage
                
                // Playlist info
                VStack(alignment: .leading) {
                    Spacer()
                    
                    HStack {
                        Text(playlist.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            }
            .frame(height: 60)
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkImage: some View {
        ZStack {
            if let imageURL = playlist.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: 60, height: 60)
                .clipped()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            } else {
                artworkPlaceholder
                    .frame(width: 60, height: 60)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            )
    }
}

// MARK: - Playlist Selection Card (for selection screen)

struct PlaylistSelectionCard: View {
    let playlist: SpotifyPlaylist
    let assignment: PlaylistAssignment
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Square artwork fills entire card height (60x60pt)
                artworkImage
                
                // Playlist info with selection indicator
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(playlist.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        
                        if playlist.trackCount > 0 {
                            Text("\(playlist.trackCount) songs")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    Spacer()
                    
                    // Selection indicator
                    if assignment != .none {
                        selectionIndicator
                    }
                }
                .padding(.leading, 8)
                .padding(.trailing, 12)
            }
            .frame(height: 60)
            .background(backgroundColor)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var artworkImage: some View {
        ZStack {
            if let imageURL = playlist.imageURL,
               let url = URL(string: imageURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    artworkPlaceholder
                }
                .frame(width: 60, height: 60)
                .clipped()
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            } else {
                artworkPlaceholder
                    .frame(width: 60, height: 60)
                    .clipShape(UnevenRoundedRectangle(topLeadingRadius: 8, bottomLeadingRadius: 8, bottomTrailingRadius: 0, topTrailingRadius: 0))
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(.gray.opacity(0.3))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(.gray)
            )
    }
    
    private var selectionIndicator: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(selectionColor)
            
            Text(selectionText)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(selectionColor)
        }
    }
    
    private var backgroundColor: Color {
        switch assignment {
        case .none:
            return Color.gray.opacity(0.2)
        case .highIntensity:
            return Color.orange.opacity(0.15)
        case .rest:
            return Color.blue.opacity(0.15)
        }
    }
    
    private var selectionColor: Color {
        switch assignment {
        case .none:
            return .clear
        case .highIntensity:
            return .orange
        case .rest:
            return .blue
        }
    }
    
    private var selectionText: String {
        switch assignment {
        case .none:
            return ""
        case .highIntensity:
            return "HIGH"
        case .rest:
            return "REST"
        }
    }
}

#Preview {
    let samplePlaylist = SpotifyPlaylist(
        id: "123",
        name: "High Energy Workout",
        description: "Get pumped with these high-energy tracks",
        trackCount: 25,
        imageURL: nil,
        isPublic: true,
        owner: "Mark Shore"
    )
    
    VStack(spacing: 16) {
        // Test cards to match Spotify's exact layout
        SpotifyTrainingCard(
            title: "High Intensity",
            displayInfo: .loaded(samplePlaylist)
        ) { }
        
        SpotifyTrainingCard(
            title: "Rest", 
            displayInfo: .notSelected
        ) { }
        
        // Test selection cards
        PlaylistSelectionCard(
            playlist: samplePlaylist,
            assignment: .highIntensity
        ) { }
        
        PlaylistSelectionCard(
            playlist: SpotifyPlaylist(
                id: "456",
                name: "Chill Beats for Recovery",
                description: "Perfect for cool down",
                trackCount: 32,
                imageURL: nil,
                isPublic: true,
                owner: "Mark Shore"
            ),
            assignment: .rest
        ) { }
    }
    .padding()
    .background(Color.black)
}


