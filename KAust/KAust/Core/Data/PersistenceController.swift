//
//  PersistenceController.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer // Using NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // Ensure "KAustModel" matches the name of your .xcdatamodeld file
        container = NSPersistentCloudKitContainer(name: "KAustModel")

        if inMemory {
            // For in-memory stores (useful for previews or unit tests)
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        // Load the persistent stores
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                // This is a serious error. Replace this with proper error handling for a shipping app.
                // fatalError() causes a crash. Useful during development to catch issues early.
                // For production, you might log the error and alert the user.
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        // Automatically merge changes from the parent context (useful for CloudKit)
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Preview Provider for SwiftUI Previews
    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Example: Add some sample data for SwiftUI Previews
        // You can expand this to create a more representative preview state
        
        // Sample User
        let previewUser = UserEntity(context: viewContext)
        previewUser.appleUserID = "previewUser123"
        previewUser.role = "owner"
        previewUser.userName = "Preview User"

        // Sample Genre
        let rockGenre = GenreEntity(context: viewContext)
        rockGenre.id = UUID()
        rockGenre.name = "Rock"

        // Sample Song 1
        let sampleSong1 = SongEntity(context: viewContext)
        sampleSong1.id = UUID()
        sampleSong1.title = "Karaoke Classic Hits Vol. 1"
        sampleSong1.artist = "Various Artists"
        sampleSong1.duration = 200
        sampleSong1.filePath = "sample_song1.mp4"
        sampleSong1.dateAdded = Date()
        sampleSong1.playCount = 5
        sampleSong1.isDownloaded = true
        sampleSong1.genres = [rockGenre] // Add relationship

        // Sample Song 2
        let sampleSong2 = SongEntity(context: viewContext)
        sampleSong2.id = UUID()
        sampleSong2.title = "Power Ballad Singalong"
        sampleSong2.artist = "Karaoke Stars"
        sampleSong2.duration = 240
        sampleSong2.filePath = "sample_song2.mp4"
        sampleSong2.dateAdded = Date()
        sampleSong2.playCount = 2
        sampleSong2.isDownloaded = true
        sampleSong2.genres = [rockGenre] // Add relationship


        // Sample Playlist
        let previewPlaylist = PlaylistEntity(context: viewContext)
        previewPlaylist.id = UUID()
        previewPlaylist.name = "My Awesome Karaoke Party"
        previewPlaylist.dateCreated = Date()
        previewPlaylist.lastModifiedDate = Date()
        previewPlaylist.owner = previewUser // Add relationship
        // Add songs to playlist (ordered)
        let songsForPlaylist = NSOrderedSet(array: [sampleSong1, sampleSong2])
        previewPlaylist.songs = songsForPlaylist


        // Sample Played Song
        let playedSong = PlayedSongEntity(context: viewContext)
        playedSong.id = UUID()
        playedSong.playedDate = Date().addingTimeInterval(-3600) // Played an hour ago
        playedSong.songTitleSnapshot = sampleSong1.title
        playedSong.artistNameSnapshot = sampleSong1.artist ?? ""
        playedSong.song = sampleSong1 // Add relationship
        playedSong.user = previewUser // Add relationship
        
        do {
            try viewContext.save()
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo) while saving preview context")
        }
        return result
    }()
}
