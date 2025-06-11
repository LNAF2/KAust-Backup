import SwiftUI

struct PlaylistPanelView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            playlistHeader
            playlistContent
        }
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple, lineWidth: 1)
        )
        .onAppear {
            print("PlaylistPanelView appeared")
            print("Number of songs in playlist: \(viewModel.playlistItems.count)")
        }
    }
    
    private var playlistHeader: some View {
        HStack {
            Text("PLAYLIST")
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Text("\(viewModel.playlistItems.count) songs")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
    
    private var playlistContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.playlistItems) { song in
                    PlaylistItemRow(song: song)
                        .contentShape(Rectangle()) // Make entire row tappable
                        .onTapGesture {
                            print("Tapped song in playlist: \(song.title)")
                            print("Song file path: \(song.filePath)")
                            handleSongTap(song)
                        }
                        .opacity(videoPlayerViewModel.currentVideo == nil ? 1 : 0.5)
                        .disabled(videoPlayerViewModel.currentVideo != nil)
                }
            }
        }
    }
    
    private func handleSongTap(_ song: Song) {
        print("handleSongTap called for: \(song.title)")
        print("currentVideo is nil: \(videoPlayerViewModel.currentVideo == nil)")
        
        if videoPlayerViewModel.currentVideo == nil {
            print("Attempting to play song: \(song.title)")
            videoPlayerViewModel.play(song: song)
            if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                print("Removing song at index: \(index)")
                viewModel.removeFromPlaylist(at: IndexSet(integer: index))
            }
        }
    }
}

struct PlaylistItemRow: View {
    let song: Song

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "play.fill")
                .foregroundColor(.purple)
        }
        .padding()
        .background(Color.black)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
}

#Preview {
    PlaylistPanelView(viewModel: PlaylistViewModel())
        .environmentObject(VideoPlayerViewModel())
}
