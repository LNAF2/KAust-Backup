//
//  SongsPlayedTableViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation
import Combine
import CoreData

@MainActor
class SongsPlayedTableViewModel: ObservableObject {
    @Published private(set) var playedSongs: [PlayedSongEntity] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    
    private let persistenceController: PersistenceController
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        
        // Setup date formatter for DATE column
        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateStyle = .medium
        self.dateFormatter.timeStyle = .none
        
        // Setup time formatter for TIME column
        self.timeFormatter = DateFormatter()
        self.timeFormatter.dateStyle = .none
        self.timeFormatter.timeStyle = .medium
        
        // Load data on initialization
        Task {
            await loadPlayedSongs()
        }
    }
    
    /// Load all played songs from Core Data, sorted by most recent first
    func loadPlayedSongs() async {
        print("🔄 Loading played songs from Core Data...")
        isLoading = true
        error = nil
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
        
        // Sort by played date descending (most recent first)
        request.sortDescriptors = [NSSortDescriptor(key: "playedDate", ascending: false)]
        
        do {
            let songs = try context.fetch(request)
            playedSongs = songs
            print("✅ Loaded \(songs.count) played songs")
        } catch {
            print("❌ Error loading played songs: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Clear all played songs history
    func clearPlayedSongs() async {
        print("🗑️ Clearing all played songs history...")
        isLoading = true
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
        
        do {
            let songs = try context.fetch(request)
            for song in songs {
                context.delete(song)
            }
            try context.save()
            playedSongs = []
            print("✅ Cleared \(songs.count) played songs from history")
        } catch {
            print("❌ Error clearing played songs: \(error)")
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Format date for display in DATE column
    func formatDate(_ date: Date) -> String {
        return dateFormatter.string(from: date)
    }
    
    /// Format time for display in TIME column
    func formatTime(_ date: Date) -> String {
        return timeFormatter.string(from: date)
    }
    
    /// Get data for printing
    func getDataForPrinting() -> [(date: String, time: String, song: String, artist: String)] {
        return playedSongs.map { song in
            (
                date: formatDate(song.playedDate ?? Date()),
                time: formatTime(song.playedDate ?? Date()),
                song: song.songTitleSnapshot ?? "Unknown",
                artist: song.artistNameSnapshot ?? "Unknown"
            )
        }
    }
    
    /// Clear any error state
    func clearError() {
        error = nil
    }
} 