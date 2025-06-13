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
    
    init() {
        // Restore songs from saved bookmarks on app startup
        Task {
            await restoreSongsFromBookmarks()
        }
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
    
    // MARK: - Bookmark Restoration
    
    @MainActor
    private func restoreSongsFromBookmarks() async {
        print("🔄 PlaylistViewModel - Restoring songs from saved bookmarks...")
        
        // Get all saved file bookmarks from UserDefaults
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let bookmarkKeys = allKeys.filter { $0.hasPrefix("fileBookmark_") }
        
        print("📁 Found \(bookmarkKeys.count) saved file bookmarks")
        
        var restoredSongs: [Song] = []
        
        for bookmarkKey in bookmarkKeys {
            guard let bookmarkData = userDefaults.data(forKey: bookmarkKey) else {
                continue
            }
            
            do {
                // Restore URL from bookmark
                var isStale = false
                let fileURL = try URL(
                    resolvingBookmarkData: bookmarkData,
                    options: .withoutUI,
                    relativeTo: nil,
                    bookmarkDataIsStale: &isStale
                )
                
                // Check if file still exists
                guard FileManager.default.fileExists(atPath: fileURL.path) else {
                    print("⚠️ File no longer exists, removing bookmark: \(fileURL.lastPathComponent)")
                    userDefaults.removeObject(forKey: bookmarkKey)
                    continue
                }
                
                // Start accessing security scoped resource
                guard fileURL.startAccessingSecurityScopedResource() else {
                    print("❌ Failed to access security-scoped resource: \(fileURL.lastPathComponent)")
                    continue
                }
                
                // Create Song object
                let fileName = fileURL.lastPathComponent
                let title = fileName.replacingOccurrences(of: ".mp4", with: "")
                
                let song = Song(
                    id: UUID().uuidString,
                    title: title,
                    artist: "Unknown Artist",
                    duration: "0:00", // Duration will be calculated when played
                    filePath: fileURL.path
                )
                
                restoredSongs.append(song)
                print("✅ Restored song: \(title)")
                
                // Stop accessing security scoped resource (will be re-accessed when played)
                fileURL.stopAccessingSecurityScopedResource()
                
            } catch {
                print("❌ Failed to restore bookmark for key \(bookmarkKey): \(error)")
                // Remove invalid bookmark
                userDefaults.removeObject(forKey: bookmarkKey)
            }
        }
        
        // Add restored songs to playlist
        if !restoredSongs.isEmpty {
            // Sort songs alphabetically by title
            restoredSongs.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            playlistItems.append(contentsOf: restoredSongs)
            print("🎵 Restored \(restoredSongs.count) songs to playlist")
        } else {
            print("📭 No songs to restore from bookmarks")
        }
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
