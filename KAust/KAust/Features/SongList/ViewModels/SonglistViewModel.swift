//
//  SonglistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import Foundation
import CoreData
import Combine

@MainActor
class SonglistViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published private(set) var displaySongs: [Song] = []
    @Published var filteredSongs: [Song] = []
    @Published var searchText = "" {
        didSet {
            // Debounce search to improve performance
            searchDebounceTask?.cancel()
            searchDebounceTask = Task { @MainActor in
                try await Task.sleep(nanoseconds: UInt64(performanceOptimizationService.getCurrentSearchDelay() * 1_000_000)) // Use dynamic delay from service
                updateDisplaySongs()
            }
        }
    }
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var isSearching = false
    @Published var showingSuggestions = false
    @Published var error: Error?


    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = [] // Keep original list for searching
    private let searchSubject = PassthroughSubject<String, Never>()
    private var searchDebounceTask: Task<Void, Error>?
    
    // MARK: - Modular Services
    private let fuzzySearchService: FuzzySearchServiceProtocol = FuzzySearchService()
    private let performanceOptimizationService: any PerformanceOptimizationServiceProtocol = PerformanceOptimizationService()
    private let notificationService: NotificationServiceProtocol = NotificationService()
    
    // TEMPORARY: Repository functionality will be modularized later when file can be added to project
    private let persistenceController = PersistenceController.shared
    
    // Computed property for display
    var displayCount: Int {
        displaySongs.count
    }

    init() {
        // Start modular performance optimization service
        performanceOptimizationService.startObserving()
        
        setupObservers()
        Task {
            await loadSongs()
        }
    }
    
    deinit {
        searchDebounceTask?.cancel()
        notificationService.removeObserver(self)
        // Note: PerformanceOptimizationService and NotificationService handle their own cleanup in deinit
    }
    
    private func setupObservers() {
        print("📡 SongListViewModel: Setting up observers using NotificationService")
        
        // MODULAR NOTIFICATIONS: Using NotificationService for all notification patterns
        
        // 1. Core Data Observer Suspension/Restoration
        notificationService.addCoreDataObserver(
            self,
            onSuspend: { viewModel in
                print("⏸️ PERFORMANCE: SongListViewModel suspending Core Data observers for smooth video")
                viewModel.cancellables.removeAll() // Suspend all reactive observers
            },
            onRestore: { viewModel in
                print("▶️ PERFORMANCE: SongListViewModel restoring Core Data observers")
                viewModel.setupObservers() // Restore observers
            }
        )
        
        // 2. Scroll Optimization Observer
        notificationService.addScrollOptimizationObserver(
            self,
            onScrollStart: { viewModel in
                print("⚡ SCROLL: SongListViewModel cancelling search during active scrolling")
                viewModel.searchDebounceTask?.cancel()
            },
            onScrollStop: { _ in
                print("✅ SCROLL: SongListViewModel resuming normal operations after scrolling")
                // Normal operations resume automatically
            }
        )
        
        // 3. Debounced Core Data Observer (using new service)
        setupCoreDataObserver()
    }
    
    /// Core Data observer setup using NotificationService
    private func setupCoreDataObserver() {
        // Don't setup observers if they are currently suspended
        guard !performanceOptimizationService.areObserversSuspended else {
            print("⏸️ PERFORMANCE: Skipping Core Data observer setup - currently suspended")
            return
        }
        
        // Use NotificationService for debounced Core Data observation
        notificationService.debouncedPublisher(for: .managedObjectContextDidSave, delay: 0.5)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Skip processing during performance mode (using modular service)
                guard !(self?.performanceOptimizationService.isInPerformanceMode ?? false) else {
                    print("⏸️ PERFORMANCE: Skipping Core Data update during video playback")
                    return
                }
                
                Task { @MainActor in
                    print("🔄 Received Core Data change notification - Reloading songs (debounced)")
                    await self?.loadSongs()
                }
            }
            .store(in: &cancellables)
        
        print("📡 SongListViewModel: Core Data observer setup complete using NotificationService")
    }


    
    /// Get current video from VideoPlayerViewModel (helper method)
    private func getCurrentVideo() -> Song? {
        // Access VideoPlayerViewModel through ContentView or use notification pattern
        // For now, return nil to be safe
        return nil
    }
    
    // COMMENTED OUT: Utility methods now handled by modular SongRepositoryService
    /*
    private func formatDuration(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let remainingSeconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, remainingSeconds)
    }
    
    private func loadSongsFromCoreData() {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        // Sort alphabetically: first by artist, then by title
        request.sortDescriptors = [
            NSSortDescriptor(key: "artist", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:))),
            NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
        ]
        
        do {
            let songEntities = try context.fetch(request)
            print("🎵 OLD SongListViewModel - Fetched \(songEntities.count) songs from Core Data (sorted alphabetically):")
            
            // Convert SongEntity to Song for compatibility  
            let convertedSongs = songEntities.compactMap { entity -> Song? in
                guard let title = entity.title,
                      let id = entity.id else { return nil }
                
                let artist = entity.artist ?? "Unknown Artist"
                // PERFORMANCE: Removed individual song logging for large datasets
                
                return Song(
                    id: id.uuidString,
                    title: title,
                    artist: artist,
                    duration: formatDuration(entity.duration),
                    filePath: entity.filePath ?? ""
                )
            }
            
            self.allSongs = convertedSongs
            self.songs = convertedSongs
            
            // Re-apply search if there's active search text
            if !searchText.isEmpty {
                performFuzzySearch(searchText)
            }
            
            print("✅ OLD SongListViewModel - Converted to \(songs.count) Song objects (alphabetically sorted)")
        } catch {
            print("❌ OLD SongListViewModel - Error fetching songs: \(error)")
            // No fallback - just show empty list if Core Data fails
            self.allSongs = []
            self.songs = []
        }
    }
    */
    
    // MARK: - Fuzzy Search Implementation (Using Modular Service)
    
    private func performFuzzySearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            filteredSongs = []
            searchSuggestions = []
            showingSuggestions = false
            isSearching = false
            return
        }
        
        isSearching = true
        print("🔍 Performing optimized search for: '\(searchText)' using FuzzySearchService")
        
        // Use modular fuzzy search service
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            // Use simple mode during scroll optimization (capture delay values from service)
            let useSimpleMode = await MainActor.run {
                self.performanceOptimizationService.getCurrentSearchDelay() < 300.0 // Simple mode if delay is reduced
            }
            let songsToSearch = await MainActor.run { self.allSongs }
            let searchResults = await self.fuzzySearchService.performSearch(
                query: searchText,
                in: songsToSearch,
                useSimpleMode: useSimpleMode
            )
            
            await MainActor.run { [weak self] in
                // Check if this is still the current search
                guard self?.searchText == searchText else { return }
                
                self?.filteredSongs = searchResults.songs
                self?.searchSuggestions = searchResults.suggestions
                self?.showingSuggestions = !searchResults.suggestions.isEmpty
                self?.isSearching = false
                
                print("🎯 Search results: \(searchResults.songs.count) songs, \(searchResults.suggestions.count) suggestions")
            }
        }
    }
    

    

    

    

    

    
    // MARK: - Public Search Methods
    
    func clearSearch() {
        searchText = ""
        filteredSongs = []
        searchSuggestions = []
        showingSuggestions = false
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
        showingSuggestions = false
    }
    
    // MARK: - Song Management
    
    func deleteSong(_ song: Song) async {
        print("\n🗑️ Starting song deletion")
        print("  - Title: '\(song.cleanTitle)'")
        print("  - Artist: '\(song.cleanArtist)'")
        
        let context = persistenceController.container.viewContext
        
        do {
            // Find the song in Core Data
            let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
            let songUUID = UUID(uuidString: song.id) ?? UUID()
            request.predicate = NSPredicate(format: "id == %@", songUUID as CVarArg)
            
            guard let songEntity = try context.fetch(request).first else {
                print("❌ Song not found in database")
                return
            }
            
            // Get file path before deleting
            let filePath = songEntity.filePath ?? ""
            let fileManager = FileManager.default
            
            // Check if this is an internal file (in app's sandbox) or external (in folder)
            let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
            let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
            let mediaPath = mediaDirectory.path
            
            if filePath.hasPrefix(mediaPath) {
                // Internal file - delete everything
                print("📱 Internal file - deleting MP4 and all associated data")
                
                // Delete MP4 if it exists
                if fileManager.fileExists(atPath: filePath) {
                    try fileManager.removeItem(atPath: filePath)
                    print("  ✅ Deleted MP4 file")
                }
                
                // Delete LRC if it exists
                if let lrcPath = songEntity.lrcFilePath,
                   fileManager.fileExists(atPath: lrcPath) {
                    try fileManager.removeItem(atPath: lrcPath)
                    print("  ✅ Deleted LRC file")
                }
            } else {
                // External file - only delete app data
                print("📁 External file - deleting only app data")
            }
            
            // Delete Core Data entity
            context.delete(songEntity)
            try context.save()
            print("✅ Deleted song data from database")
            
            // Refresh song list
            await loadSongs()
            
        } catch {
            print("❌ Error during deletion: \(error.localizedDescription)")
            self.error = error
        }
    }
    

    
    /// Load all songs from Core Data
    func loadSongs() async {
        print("🔄 Loading songs from Core Data...")
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        // Sort by title
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            // PERFORMANCE: Load in background to prevent UI blocking
            let songEntities = try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        let entities = try context.fetch(request)
                        continuation.resume(returning: entities)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            print("📝 Found \(songEntities.count) songs in Core Data")
            
            // PERFORMANCE: Reduce logging for large datasets
            let loadedSongs = songEntities.compactMap { Song(from: $0) }
            print("✅ Converted to \(loadedSongs.count) Song objects")
            
            // Update the UI on the main thread
            await MainActor.run {
                self.songs = loadedSongs
                self.allSongs = loadedSongs  // CRITICAL: Update allSongs for fuzzy search!
                self.updateDisplaySongs()
                self.error = nil
                print("🎵 Updated UI with \(self.displaySongs.count) songs")
            }
        } catch {
            print("❌ Error loading songs: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    
    // COMMENTED OUT: Replaced by modular SongRepositoryService
    /*
    /// Load all songs from Core Data (OLD IMPLEMENTATION)
    func loadSongsOLD() async {
        print("🔄 Loading songs from Core Data...")
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        // Sort by title
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        
        do {
            // PERFORMANCE: Load in background to prevent UI blocking
            let songEntities = try await withCheckedThrowingContinuation { continuation in
                Task.detached {
                    do {
                        let entities = try context.fetch(request)
                        continuation.resume(returning: entities)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
            
            print("📝 Found \(songEntities.count) songs in Core Data")
            
            // PERFORMANCE: Reduce logging for large datasets
            let loadedSongs = songEntities.compactMap { Song(from: $0) }
            print("✅ Converted to \(loadedSongs.count) Song objects")
            
            // Update the UI on the main thread
            await MainActor.run {
                self.songs = loadedSongs
                self.allSongs = loadedSongs  // CRITICAL: Update allSongs for fuzzy search!
                self.updateDisplaySongs()
                self.error = nil
                print("🎵 Updated UI with \(self.displaySongs.count) songs")
            }
        } catch {
            print("❌ Error loading songs: \(error)")
            await MainActor.run {
                self.error = error
            }
        }
    }
    */
    
    /// Update display songs based on search text using fuzzy search
    private func updateDisplaySongs() {
        if searchText.isEmpty {
            displaySongs = songs.sorted { $0.cleanTitle < $1.cleanTitle }
            filteredSongs = []
            searchSuggestions = []
            showingSuggestions = false
            isSearching = false
            print("📋 Displaying all \(displaySongs.count) songs")
        } else {
            // Use optimized fuzzy search for advanced matching
            performFuzzySearch(searchText)
            displaySongs = filteredSongs
        }
    }
    
    /// Check if a song already exists in Core Data
    private func songExists(title: String, artist: String?, filePath: String) async -> Bool {
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        // First check by file path
        request.predicate = NSPredicate(format: "filePath == %@", filePath)
        if let _ = try? context.fetch(request).first {
            print("🔍 Found duplicate by file path: \(filePath)")
            return true
        }
        
        // Then check by title and artist
        if let artist = artist {
            request.predicate = NSPredicate(
                format: "title == %@ AND artist == %@",
                title, artist
            )
        } else {
            request.predicate = NSPredicate(
                format: "title == %@ AND artist == nil",
                title
            )
        }
        
        if let _ = try? context.fetch(request).first {
            print("🔍 Found duplicate by title/artist: \(title) by \(artist ?? "Unknown")")
            return true
        }
        
        return false
    }
    
    /// Import a song from a file path
    func importSong(title: String, artist: String?, filePath: String) async throws {
        print("\n📝 DEBUG: Attempting to import song")
        print("  - Title: \(title)")
        print("  - Artist: \(artist ?? "Unknown")")
        print("  - File path: \(filePath)")
        
        // First verify the file exists and is accessible
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            print("❌ DEBUG: File does not exist at path: \(filePath)")
            throw NSError(domain: "SongList", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "MP4 file not found at specified location"])
        }
        
        // Try to access the file
        guard let _ = try? Data(contentsOf: URL(fileURLWithPath: filePath), options: .alwaysMapped) else {
            print("❌ DEBUG: File exists but is not accessible: \(filePath)")
            throw NSError(domain: "SongList", 
                         code: -2, 
                         userInfo: [NSLocalizedDescriptionKey: "MP4 file exists but cannot be accessed"])
        }
        
        // Check for duplicates
        if await songExists(title: title, artist: artist, filePath: filePath) {
            print("⚠️ DEBUG: Song already exists in database")
            throw NSError(domain: "SongList", 
                         code: -3, 
                         userInfo: [NSLocalizedDescriptionKey: "Song already exists in library"])
        }
        
        // Get the app's Documents/Media directory path for comparison
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        let mediaPath = mediaDirectory.path
        
        print("📁 DEBUG: Checking file location")
        print("  - Media directory: \(mediaPath)")
        print("  - File path: \(filePath)")
        
        let context = persistenceController.container.viewContext
        let song = SongEntity(context: context)
        
        song.id = UUID()
        song.title = title
        song.artist = artist
        song.filePath = filePath
        song.dateAdded = Date()
        
        // If this is an internal file (in app's Media directory), verify it exists
        if filePath.hasPrefix(mediaPath) {
            print("📂 DEBUG: Internal file detected")
            if !fileManager.fileExists(atPath: filePath) {
                print("❌ DEBUG: Internal file missing at: \(filePath)")
                context.delete(song)
                throw NSError(domain: "SongList", 
                            code: -4, 
                            userInfo: [NSLocalizedDescriptionKey: "Internal MP4 file is missing"])
            }
        }
        
        try context.save()
        print("✅ DEBUG: Successfully imported song: \(title)")
        
        // Refresh the song list
        await loadSongs()
    }
    
    // COMMENTED OUT: Replaced by modular SongRepositoryService
    /*
    /// Import a song from a file path (OLD IMPLEMENTATION)
    func importSongOLD(title: String, artist: String?, filePath: String) async throws {
        print("\n📝 DEBUG: Attempting to import song")
        print("  - Title: \(title)")
        print("  - Artist: \(artist ?? "Unknown")")
        print("  - File path: \(filePath)")
        
        // First verify the file exists and is accessible
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: filePath) else {
            print("❌ DEBUG: File does not exist at path: \(filePath)")
            throw NSError(domain: "SongList", 
                         code: -1, 
                         userInfo: [NSLocalizedDescriptionKey: "MP4 file not found at specified location"])
        }
        
        // Try to access the file
        guard let _ = try? Data(contentsOf: URL(fileURLWithPath: filePath), options: .alwaysMapped) else {
            print("❌ DEBUG: File exists but is not accessible: \(filePath)")
            throw NSError(domain: "SongList", 
                         code: -2, 
                         userInfo: [NSLocalizedDescriptionKey: "MP4 file exists but cannot be accessed"])
        }
        
        // Check for duplicates
        if await songExists(title: title, artist: artist, filePath: filePath) {
            print("⚠️ DEBUG: Song already exists in database")
            throw NSError(domain: "SongList", 
                         code: -3, 
                         userInfo: [NSLocalizedDescriptionKey: "Song already exists in library"])
        }
        
        // Get the app's Documents/Media directory path for comparison
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        let mediaPath = mediaDirectory.path
        
        print("📁 DEBUG: Checking file location")
        print("  - Media directory: \(mediaPath)")
        print("  - File path: \(filePath)")
        
        let context = persistenceController.container.viewContext
        let song = SongEntity(context: context)
        
        song.id = UUID()
        song.title = title
        song.artist = artist
        song.filePath = filePath
        song.dateAdded = Date()
        
        // If this is an internal file (in app's Media directory), verify it exists
        if filePath.hasPrefix(mediaPath) {
            print("📂 DEBUG: Internal file detected")
            if !fileManager.fileExists(atPath: filePath) {
                print("❌ DEBUG: Internal file missing at: \(filePath)")
                context.delete(song)
                throw NSError(domain: "SongList", 
                            code: -4, 
                            userInfo: [NSLocalizedDescriptionKey: "Internal MP4 file is missing"])
            }
        }
        
        try context.save()
        print("✅ DEBUG: Successfully imported song: \(title)")
        
        // Refresh the song list
        await loadSongs()
    }
    */
    
    // MARK: - Scroll Performance Optimization Methods (Using Modular Service)

    
    /// Get current search delay for debugging (using modular service)
    var currentSearchDelayMs: Int {
        performanceOptimizationService.currentSearchDelayMs
    }
    
    // MARK: - Performance Optimization Methods (Delegated to Service)
    
    /// Enable scroll-optimized search delay for faster scrolling (delegated to service)
    func setScrollOptimizedSearchDelay() {
        performanceOptimizationService.setScrollOptimizedSearchDelay()
    }
    
    /// Restore normal search delay (delegated to service)
    func restoreNormalSearchDelay() {
        performanceOptimizationService.restoreNormalSearchDelay()
    }
}


