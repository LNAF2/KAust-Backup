import Foundation
import CoreData
import AVFoundation

final class DataProviderService: DataProviderServiceProtocol {
    private let persistenceController: PersistenceController
    private let fileManager: FileManager
    private let metadataService: MediaMetadataServiceProtocol
    
    init(persistenceController: PersistenceController = .shared,
         fileManager: FileManager = .default,
         metadataService: MediaMetadataServiceProtocol = MediaMetadataService()) {
        self.persistenceController = persistenceController
        self.fileManager = fileManager
        self.metadataService = metadataService
    }
    
    // MARK: - File Management Helpers
    
    private func copyFileToAppSandbox(from sourceURL: URL) throws -> URL {
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media", isDirectory: true)
        try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        
        let destinationURL = mediaDirectory.appendingPathComponent(sourceURL.lastPathComponent)
        
        // If file already exists, remove it
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }
    
    // MARK: - User Management
    
    func fetchOrCreateUser(appleUserID: String, userName: String?, role: String) async throws -> UserEntity {
        let context = persistenceController.container.viewContext
        
        // Try to fetch existing user
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        
        if let existingUser = try context.fetch(request).first {
            return existingUser
        }
        
        // Create new user
        let user = UserEntity(context: context)
        user.appleUserID = appleUserID
        user.userName = userName
        user.role = role
        user.joinDate = Date()
        
        try context.save()
        return user
    }
    
    func fetchUser(appleUserID: String) async throws -> UserEntity? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        
        return try context.fetch(request).first
    }
    
    func updateUserRole(appleUserID: String, newRole: String) async throws {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
        request.predicate = NSPredicate(format: "appleUserID == %@", appleUserID)
        
        guard let user = try context.fetch(request).first else {
            throw DataProviderError.userNotFound
        }
        
        user.role = newRole
        try context.save()
    }
    
    // MARK: - Song Management
    
    func importSong(title: String, artist: String?, duration: Float, filePath: String, lrcFilePath: String?,
                   year: Int16?, language: String?, event: String?,
                   genres: [String]) async throws -> SongEntity {
        let sourceURL = URL(fileURLWithPath: filePath)
        
        // Validate MP4 file with processing mode (DataProviderService always copies files)
        try await metadataService.validateMP4File(at: sourceURL, processingMode: .filePickerCopy)
        
        // Extract metadata
        let metadata = try await metadataService.extractMetadata(from: sourceURL)
        
        // Copy file to app sandbox
        let destinationURL = try copyFileToAppSandbox(from: sourceURL)
        
        // Create Core Data entity
        let context = persistenceController.container.viewContext
        let song = SongEntity(context: context)
        
        song.id = UUID()
        song.title = title
        song.artist = artist
        song.duration = metadata.duration > 0 ? metadata.duration : Double(duration)
        song.filePath = destinationURL.path
        song.lrcFilePath = lrcFilePath
        song.year = year ?? 0
        song.language = language
        song.event = event
        song.dateAdded = Date()
        song.isDownloaded = true
        song.playCount = 0
        
        // Set metadata from extraction
        song.fileSizeBytes = metadata.fileSizeBytes
        song.audioBitRate = metadata.audioBitRate
        song.videoBitRate = metadata.videoBitRate
        song.totalBitRate = metadata.totalBitRate
        song.audioChannelCount = metadata.audioChannelCount
        song.pixelWidth = metadata.pixelWidth
        song.pixelHeight = metadata.pixelHeight
        
        // Store media types as a JSON array
        if !metadata.mediaTypes.isEmpty {
            let mediaTypesData = try JSONEncoder().encode(metadata.mediaTypes)
            song.mediaTypes = mediaTypesData as NSObject
        }
        
        // Add genres
        for genreName in genres {
            let genre = try await fetchOrCreateGenre(name: genreName)
            song.addToGenres(genre)
        }
        
        try context.save()
        return song
    }
    
    func fetchAllSongs(sortedBy key: String?, ascending: Bool) async throws -> [SongEntity] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        if let sortKey = key {
            request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
        }
        
        return try context.fetch(request)
    }
    
    func fetchSongs(matching searchText: String?,
                   filteredByDecade: Int?, year: Int16?, language: String?, event: String?, genreNames: [String]?) async throws -> [SongEntity] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        // Search text filter
        if let searchText = searchText, !searchText.isEmpty {
            let searchPredicate = NSPredicate(format: "title CONTAINS[cd] %@ OR artist CONTAINS[cd] %@", searchText, searchText)
            predicates.append(searchPredicate)
        }
        
        // Year filter
        if let year = year {
            predicates.append(NSPredicate(format: "year == %d", year))
        }
        
        // Language filter
        if let language = language {
            predicates.append(NSPredicate(format: "language == %@", language))
        }
        
        // Event filter
        if let event = event {
            predicates.append(NSPredicate(format: "event == %@", event))
        }
        
        // Genre filter
        if let genreNames = genreNames, !genreNames.isEmpty {
            let genrePredicate = NSPredicate(format: "ANY genres.name IN %@", genreNames)
            predicates.append(genrePredicate)
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        return try context.fetch(request)
    }
    
    func fetchSong(with id: UUID) async throws -> SongEntity? {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        
        return try context.fetch(request).first
    }
    
    func deleteSong(_ song: SongEntity) async throws {
        let context = persistenceController.container.viewContext
        
        guard let filePath = song.filePath else {
            // No file path, just delete the Core Data entity
            context.delete(song)
            try context.save()
            return
        }
        
        // Get the app's Documents/Media directory path for comparison
        let documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        let mediaPath = mediaDirectory.path
        let fileName = URL(fileURLWithPath: filePath).lastPathComponent
        
        // Check if the file is in our app's Media directory (internal file)
        if filePath.hasPrefix(mediaPath) {
            print("📁 Deleting internal file: \(fileName)")
            
            // Delete associated MP4 file if it exists
            if fileManager.fileExists(atPath: filePath) {
                try fileManager.removeItem(atPath: filePath)
                print("✅ Deleted MP4 file: \(fileName)")
            }
            
            // Delete associated LRC file if exists
            if let lrcPath = song.lrcFilePath, fileManager.fileExists(atPath: lrcPath) {
                try fileManager.removeItem(atPath: lrcPath)
                print("✅ Deleted LRC file: \(URL(fileURLWithPath: lrcPath).lastPathComponent)")
            }
        } else {
            print("🔒 Deleting external file reference: \(fileName)")
            print("🗑️ Preserving external file, deleting only metadata")
            
            // For external files, clean up any associated bookmark
            let bookmarkKey = "fileBookmark_\(fileName)"
            if UserDefaults.standard.data(forKey: bookmarkKey) != nil {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                print("🧹 Cleaned up bookmark for external file: \(fileName)")
            }
        }
        
        // Always delete the Core Data entity
        context.delete(song)
        try context.save()
    }
    
    func updateSongPlayCount(songID: UUID) async throws {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", songID as CVarArg)
        
        guard let song = try context.fetch(request).first else {
            throw DataProviderError.songNotFound
        }
        
        song.playCount += 1
        song.lastPlayedDate = Date()
        try context.save()
    }
    
    // MARK: - Genre Management
    
    func fetchOrCreateGenre(name: String) async throws -> GenreEntity {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GenreEntity> = GenreEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@", name)
        
        if let existingGenre = try context.fetch(request).first {
            return existingGenre
        }
        
        // Create new genre
        let genre = GenreEntity(context: context)
        genre.id = UUID()
        genre.name = name
        
        try context.save()
        return genre
    }
    
    func fetchAllGenres() async throws -> [GenreEntity] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<GenreEntity> = GenreEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        return try context.fetch(request)
    }
    
    // MARK: - Playlist Management (Basic implementations - can be expanded)
    
    func fetchOrCreatePlaylist(name: String, forUser user: UserEntity) async throws -> PlaylistEntity {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
        request.predicate = NSPredicate(format: "name == %@ AND owner == %@", name, user)
        
        if let existingPlaylist = try context.fetch(request).first {
            return existingPlaylist
        }
        
        // Create new playlist
        let playlist = PlaylistEntity(context: context)
        playlist.id = UUID()
        playlist.name = name
        playlist.dateCreated = Date()
        playlist.lastModifiedDate = Date()
        playlist.owner = user
        
        try context.save()
        return playlist
    }
    
    func addSong(_ song: SongEntity, toPlaylist playlist: PlaylistEntity) async throws {
        let context = persistenceController.container.viewContext
        playlist.addToSongs(song)
        playlist.lastModifiedDate = Date()
        try context.save()
    }
    
    func removeSong(_ song: SongEntity, fromPlaylist playlist: PlaylistEntity) async throws {
        let context = persistenceController.container.viewContext
        playlist.removeFromSongs(song)
        playlist.lastModifiedDate = Date()
        try context.save()
    }
    
    func reorderSongs(inPlaylist playlist: PlaylistEntity, newOrderedSongs: NSOrderedSet) async throws {
        let context = persistenceController.container.viewContext
        playlist.songs = newOrderedSongs
        playlist.lastModifiedDate = Date()
        try context.save()
    }
    
    func clearPlaylist(_ playlist: PlaylistEntity) async throws {
        let context = persistenceController.container.viewContext
        playlist.removeFromSongs(playlist.songs!)
        playlist.lastModifiedDate = Date()
        try context.save()
    }
    
    // MARK: - Played Song History (Basic implementations)
    
    func addPlayedSong(song: SongEntity, forUser user: UserEntity, playedDate: Date) async throws -> PlayedSongEntity {
        let context = persistenceController.container.viewContext
        let playedSong = PlayedSongEntity(context: context)
        
        playedSong.id = UUID()
        playedSong.playedDate = playedDate
        playedSong.songTitleSnapshot = song.title ?? ""
        playedSong.artistNameSnapshot = song.artist ?? ""
        playedSong.song = song
        playedSong.user = user
        
        try context.save()
        return playedSong
    }
    
    func fetchPlayHistory(forUser user: UserEntity, limit: Int?) async throws -> [PlayedSongEntity] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        request.sortDescriptors = [NSSortDescriptor(key: "playedDate", ascending: false)]
        
        if let limit = limit {
            request.fetchLimit = limit
        }
        
        return try context.fetch(request)
    }
    
    func clearPlayHistory(forUser user: UserEntity) async throws {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "user == %@", user)
        
        let playedSongs = try context.fetch(request)
        for playedSong in playedSongs {
            context.delete(playedSong)
        }
        
        try context.save()
    }
    
    // MARK: - Filter Genre Mapping (Basic implementations)
    
    func createFilterGenreMapping(filterCategoryName: String, mapsToGenreNames: [String], displayOrder: Int16?) async throws -> FilterGenreMappingEntity {
        let context = persistenceController.container.viewContext
        let mapping = FilterGenreMappingEntity(context: context)
        
        mapping.id = UUID()
        mapping.filterCategoryName = filterCategoryName
        mapping.displayOrder = displayOrder ?? 0
        
        // Add mapped genres
        for genreName in mapsToGenreNames {
            let genre = try await fetchOrCreateGenre(name: genreName)
            mapping.addToMappedGenres(genre)
        }
        
        try context.save()
        return mapping
    }
    
    func fetchFilterGenreMappings() async throws -> [FilterGenreMappingEntity] {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<FilterGenreMappingEntity> = FilterGenreMappingEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "displayOrder", ascending: true)]
        
        return try context.fetch(request)
    }
    
    func mapGenre(_ genre: GenreEntity, toFilterMapping filterMapping: FilterGenreMappingEntity) async throws {
        let context = persistenceController.container.viewContext
        filterMapping.addToMappedGenres(genre)
        try context.save()
    }
    
    // MARK: - Factory Reset
    
    /// Performs a complete factory reset of all app data
    /// - Warning: This will delete ALL data except the current user's authentication
    func performFactoryReset() async throws {
        print("\n🏭 Starting Factory Reset - Complete app data cleanup")
        
        let context = persistenceController.container.viewContext
        
        do {
            // Step 1: Delete all playlists
            print("🗑️ Step 1: Deleting all playlists...")
            let playlistRequest: NSFetchRequest<PlaylistEntity> = PlaylistEntity.fetchRequest()
            let batchDeletePlaylists = NSBatchDeleteRequest(fetchRequest: playlistRequest as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeletePlaylists)
            print("  ✅ Deleted all playlists")
            
            // Step 2: Delete all played song history
            print("🗑️ Step 2: Deleting all played song history...")
            let playedSongsRequest: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
            let batchDeletePlayedSongs = NSBatchDeleteRequest(fetchRequest: playedSongsRequest as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeletePlayedSongs)
            print("  ✅ Deleted all played song history")
            
            // Step 3: Delete all filter genre mappings
            print("🗑️ Step 3: Deleting all filter genre mappings...")
            let filterMappingRequest: NSFetchRequest<FilterGenreMappingEntity> = FilterGenreMappingEntity.fetchRequest()
            let batchDeleteFilterMappings = NSBatchDeleteRequest(fetchRequest: filterMappingRequest as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeleteFilterMappings)
            print("  ✅ Deleted all filter genre mappings")
            
            // Step 4: Delete all songs (includes file cleanup)
            print("🗑️ Step 4: Deleting all songs and associated files...")
            let songsRequest: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
            let songs = try context.fetch(songsRequest)
            
            // Clean up files first (internal files only - external files are preserved)
            let documentsDirectory = try fileManager.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
            let mediaPath = mediaDirectory.path
            
            var internalFilesDeleted = 0
            for song in songs {
                if let filePath = song.filePath, filePath.hasPrefix(mediaPath) {
                    if fileManager.fileExists(atPath: filePath) {
                        try fileManager.removeItem(atPath: filePath)
                        internalFilesDeleted += 1
                    }
                    // Delete LRC file if exists
                    if let lrcPath = song.lrcFilePath, fileManager.fileExists(atPath: lrcPath) {
                        try fileManager.removeItem(atPath: lrcPath)
                    }
                }
            }
            
            // Batch delete all songs from Core Data
            let batchDeleteSongs = NSBatchDeleteRequest(fetchRequest: songsRequest as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeleteSongs)
            print("  ✅ Deleted all songs from database and \(internalFilesDeleted) internal files")
            
            // Step 5: Delete all genres
            print("🗑️ Step 5: Deleting all genres...")
            let genresRequest: NSFetchRequest<GenreEntity> = GenreEntity.fetchRequest()
            let batchDeleteGenres = NSBatchDeleteRequest(fetchRequest: genresRequest as! NSFetchRequest<NSFetchRequestResult>)
            try context.execute(batchDeleteGenres)
            print("  ✅ Deleted all genres")
            
            // Step 6: Delete all users EXCEPT the current authenticated user
            print("🗑️ Step 6: Deleting all users except current user...")
            let currentUserID = getCurrentAuthenticatedUserID()
            let usersRequest: NSFetchRequest<UserEntity> = UserEntity.fetchRequest()
            if let currentUserID = currentUserID {
                // Keep the current user, delete all others
                usersRequest.predicate = NSPredicate(format: "appleUserID != %@", currentUserID)
            }
            let users = try context.fetch(usersRequest)
            for user in users {
                context.delete(user)
            }
            print("  ✅ Deleted \(users.count) other users (preserved current user)")
            
            // Step 7: Clean up entire Media directory if it exists
            print("🗑️ Step 7: Cleaning up Media directory...")
            if fileManager.fileExists(atPath: mediaPath) {
                try fileManager.removeItem(at: mediaDirectory)
                try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
                print("  ✅ Cleaned up Media directory")
            }
            
            // Step 8: Save context changes
            try context.save()
            print("  ✅ Saved all database changes")
            
            print("\n🎉 FACTORY RESET COMPLETED SUCCESSFULLY:")
            print("  - All songs and media files deleted")
            print("  - All playlists deleted")
            print("  - All played song history deleted")
            print("  - All genres and filter mappings deleted")
            print("  - All other users deleted (current user preserved)")
            print("  - Media directory cleaned")
            print("  - App restored to initial state")
            
        } catch {
            print("❌ Factory reset failed: \(error)")
            throw DataProviderError.coreDataError
        }
    }
    
    // MARK: - Helper Methods
    
    /// Get the current authenticated user's Apple ID
    private func getCurrentAuthenticatedUserID() -> String? {
        // Get from UserDefaults (matches AuthenticationService)
        return UserDefaults.standard.string(forKey: "user_id")
    }
}

// MARK: - Supporting Types

enum DataProviderError: Error, LocalizedError {
    case userNotFound
    case songNotFound
    case fileOperationFailed
    case coreDataError
    
    var errorDescription: String? {
        switch self {
        case .userNotFound:
            return "User not found"
        case .songNotFound:
            return "Song not found"
        case .fileOperationFailed:
            return "File operation failed"
        case .coreDataError:
            return "Database error occurred"
        }
    }
} 