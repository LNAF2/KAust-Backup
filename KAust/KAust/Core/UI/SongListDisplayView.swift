import SwiftUI

struct SongListDisplayView: View {
    @ObservedObject var playlistViewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    @EnvironmentObject var userPreferences: UserPreferencesManager // Use centralized preferences
    
    var body: some View {
        VStack(spacing: 0) {
            // Main song list content with search
            SongListView(playlistViewModel: playlistViewModel)
        }
        .background(Color.white)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
        )
        .padding(.all, 8)
    }
}

private extension SongListDisplayView {
    func addToPlaylist(_ song: Song) {
        // Check if song is already in playlist or currently playing
        let isInPlaylist = playlistViewModel.playlistItems.contains { $0.id == song.id }
        let isCurrentlyPlaying = videoPlayerViewModel.currentVideo?.id == song.id
        
        if isInPlaylist || isCurrentlyPlaying {
            // Provide haptic feedback for "already selected" state
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        } else {
            playlistViewModel.addToPlaylist(song)
        }
    }
}

// MARK: - Internal Song Row View

private struct SongRowView: View {
    let song: Song
    let isInPlaylist: Bool
    let isCurrentlyPlaying: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?
    @EnvironmentObject var userPreferences: UserPreferencesManager
    
    var body: some View {
        SongListItemView(
            song: song,
            isInPlaylist: isInPlaylist,
            isCurrentlyPlaying: isCurrentlyPlaying
        )
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .if(userPreferences.swipeToDeleteEnabled && onDelete != nil) { view in
            view.swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    onDelete?()
                }
            }
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Conditionally applies a view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
} 