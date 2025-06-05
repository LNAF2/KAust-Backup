//
//  PlaylistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/ViewModels/PlaylistViewModel.swift
import Foundation

@MainActor
class PlaylistViewModel: ObservableObject {
    @Published var playlistItems: [AppSong] = AppSong.mockSongs

    func selectPlaylistItem(_ song: AppSong) {
        print("Tapped playlist item: \(song.title) by \(song.artist)")
    }

    // Example move function for reordering
    func moveSong(from source: IndexSet, to destination: Int) {
        playlistItems.move(fromOffsets: source, toOffset: destination)
    }
}
