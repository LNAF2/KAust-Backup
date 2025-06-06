import SwiftUI

struct PlaylistPanelView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("PLAYLIST")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Text("\(viewModel.songs.count) songs")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }
            .padding()
            
            // Song List
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.songs) { song in
                        PlaylistItemView(song: song)
                            .onTapGesture {
                                if videoPlayerViewModel.currentVideo == nil {
                                    videoPlayerViewModel.play(song: song)
                                    viewModel.removeSong(song)
                                }
                            }
                            .opacity(videoPlayerViewModel.currentVideo == nil ? 1 : 0.5)
                            .disabled(videoPlayerViewModel.currentVideo != nil)
                    }
                }
            }
        }
        .background(Color.black)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.purple, lineWidth: 1)
        )
    }
}

struct PlaylistItemView: View {
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