//
//  PlaylistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/ViewModels/PlaylistViewModel.swift

import Foundation

class PlaylistViewModel: ObservableObject {
    @Published var playlistItems: [Song] = []

    func addToPlaylist(_ song: Song) {
        // Prevent duplicates (optional)
        if !playlistItems.contains(where: { $0.id == song.id }) {
            playlistItems.append(song)
        }
    }

    func removeFromPlaylist(at offsets: IndexSet) {
        playlistItems.remove(atOffsets: offsets)
    }
}


/*
import Foundation

class PlaylistViewModel: ObservableObject {
    @Published var playlistItems: [AppSong] = [
        AppSong(title: "Imagine", artist: "John Lennon", duration: "3:12"),
        AppSong(title: "Bohemian Rhapsody", artist: "Queen", duration: "5:55"),
        AppSong(title: "Hey Jude", artist: "The Beatles", duration: "7:11")
    ]

    func moveSong(from source: IndexSet, to destination: Int) {
        playlistItems.move(fromOffsets: source, toOffset: destination)
    }

    func deleteSongs(at offsets: IndexSet) {
        playlistItems.remove(atOffsets: offsets)
    }
}
*/
