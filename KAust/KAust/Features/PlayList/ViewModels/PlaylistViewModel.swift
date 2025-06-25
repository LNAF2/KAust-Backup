import Foundation
import Combine

@MainActor
final class PlaylistViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var playlistItems: [Song] = []
    @Published private(set) var currentlyPlayingSong: Song?
    
    // MARK: - Publishers
    let scrollToBottomPublisher = PassthroughSubject<Void, Never>()
    
    // MARK: - Dependencies
    private let videoPlayerViewModel: VideoPlayerViewModel
    
    // MARK: - Initialization
    init(videoPlayerViewModel: VideoPlayerViewModel) {
        self.videoPlayerViewModel = videoPlayerViewModel
        print("✅ PlaylistViewModel initialized")
    }
    
    // MARK: - Public Methods
    func addSong(_ song: Song) {
        guard !playlistItems.contains(where: { $0.id == song.id }) else {
            print("⚠️ Song already in playlist: \(song.title)")
            return
        }
        playlistItems.append(song)
        print("✅ Added song to playlist: \(song.title)")
        scrollToBottomPublisher.send() // Trigger scroll to bottom
    }
    
    func removeSong(at index: Int) async {
        guard index >= 0 && index < playlistItems.count else {
            print("❌ Invalid index for removal: \(index)")
            return
        }
        let song = playlistItems[index]
        playlistItems.remove(at: index)
        print("✅ Removed song from playlist: \(song.title)")
    }
    
    func playSong(_ song: Song) {
        Task {
            print("▶️ Playing song: \(song.title)")
            
            // Add to playlist if not already there
            if !playlistItems.contains(where: { $0.id == song.id }) {
                playlistItems.append(song)
                print("✅ Added song to playlist: \(song.title)")
                scrollToBottomPublisher.send() // Trigger scroll to bottom when adding during play
            }
            
            // Update currently playing song
            currentlyPlayingSong = song
            
            // Play the song
            await videoPlayerViewModel.play(song: song)
            print("🎵 Started playback: \(song.title)")
        }
    }
    
    func moveItem(from source: IndexSet, to destination: Int) {
        playlistItems.move(fromOffsets: source, toOffset: destination)
        print("📦 Reordered playlist items")
    }
    
    func clearPlaylist() {
        playlistItems.removeAll()
        currentlyPlayingSong = nil
        print("🧹 Cleared playlist")
    }
    
    /// Remove a song from the playlist
    func removeFromPlaylist(_ song: Song) async {
        if let index = playlistItems.firstIndex(where: { $0.id == song.id }) {
            await removeSong(at: index)
        }
    }
    
    // MARK: - Helper Methods
    func isSongInPlaylist(_ song: Song) -> Bool {
        let isInPlaylist = playlistItems.contains(where: { $0.id == song.id })
        print("🔍 Checking if song is in playlist: \(song.title) - \(isInPlaylist ? "Yes" : "No")")
        return isInPlaylist
    }
    
    func isSongCurrentlyPlaying(_ song: Song) -> Bool {
        let isPlaying = currentlyPlayingSong?.id == song.id
        print("🎵 Checking if song is playing: \(song.title) - \(isPlaying ? "Yes" : "No")")
        return isPlaying
    }
} 