import SwiftUI
import Foundation
import Combine

struct PlaylistPanelView: View {
    @StateObject private var viewModel: PlaylistViewModel
    @EnvironmentObject private var videoPlayerViewModel: VideoPlayerViewModel
    
    init(videoPlayerViewModel: VideoPlayerViewModel) {
        _viewModel = StateObject(wrappedValue: PlaylistViewModel(videoPlayerViewModel: videoPlayerViewModel))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PLAY LIST")
                    .font(.headline)
                    .foregroundColor(AppTheme.rightPanelAccent)
                Spacer()
                Text("\(viewModel.playlistItems.count) Songs")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.rightPanelAccent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            
            // Playlist
            PlaylistView(viewModel: viewModel)
                .frame(maxHeight: .infinity)
        }
        .background(AppTheme.rightPanelBackground)
    }
}

#Preview {
    PlaylistPanelView(videoPlayerViewModel: VideoPlayerViewModel())
} 