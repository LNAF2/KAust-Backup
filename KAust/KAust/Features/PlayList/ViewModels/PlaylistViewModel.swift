//
//  PlaylistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/ViewModels/PlaylistViewModel.swift

import Foundation
import Combine

class PlaylistViewModel: ObservableObject {
    @Published var playlistItems: [Song] = []
    
    // Publisher to trigger scroll to bottom when new song is added
    private let scrollToBottomSubject = PassthroughSubject<Void, Never>()
    var scrollToBottomPublisher: AnyPublisher<Void, Never> {
        scrollToBottomSubject.eraseToAnyPublisher()
    }

    func addToPlaylist(_ song: Song) {
        print("🎵 PlaylistViewModel.addToPlaylist - Adding song: '\(song.title)' by '\(song.artist)'")
        print("📁 Song file path: \(song.filePath)")
        print("🔗 Song video URL: \(song.videoURL?.absoluteString ?? "nil")")
        
        // Prevent duplicates (optional)
        if !playlistItems.contains(where: { $0.id == song.id }) {
            playlistItems.append(song)
            print("✅ Song added to playlist. Total songs: \(playlistItems.count)")
            
            // Trigger scroll to bottom after a short delay to ensure the new item is rendered
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.scrollToBottomSubject.send()
            }
        } else {
            print("⚠️ Song already exists in playlist")
        }
    }

    func removeFromPlaylist(at offsets: IndexSet) {
        playlistItems.remove(atOffsets: offsets)
    }
    
    func removeFromPlaylist(_ song: Song) {
        print("🗑️ PlaylistViewModel.removeFromPlaylist - Removing song: '\(song.title)'")
        playlistItems.removeAll { $0.id == song.id }
        print("✅ Song removed from playlist. Remaining songs: \(playlistItems.count)")
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
