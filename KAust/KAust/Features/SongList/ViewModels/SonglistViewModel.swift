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
    @Published private(set) var songs: [Song] = []
    @Published private(set) var displaySongs: [Song] = []
    @Published var searchText = ""
    @Published var filteredSongs: [Song] = []
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

    private let dataProvider: DataProviderServiceProtocol
    
    // MARK: - Initialization
    init(dataProvider: DataProviderServiceProtocol = DataProviderService()) {
        self.dataProvider = dataProvider
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
    
    // MARK: - Public Methods
    func loadSongs() async {
        do {
            let songEntities = try await dataProvider.fetchAllSongs(sortedBy: "title", ascending: true)
            let songs = songEntities.compactMap { Song(from: $0) }
            await MainActor.run {
                self.songs = songs
                updateDisplaySongs()
                print("✅ Loaded \(songs.count) songs")
            }
        } catch {
            print("❌ Error loading songs: \(error)")
        }
    }
    
    func filteredSongs(matching searchText: String) -> [Song] {
        if searchText.isEmpty {
            return songs
        }
        let filtered = songs.filter { song in
            song.title.localizedCaseInsensitiveContains(searchText) ||
            song.artist.localizedCaseInsensitiveContains(searchText)
        }
        print("🔍 Found \(filtered.count) songs matching '\(searchText)'")
        return filtered
    }
    
    // MARK: - Private Methods
    private func updateDisplaySongs() {
        displaySongs = filteredSongs(matching: searchText)
        print("📱 Updated display with \(displaySongs.count) songs")
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
    
    /// Delete a song from the library
    func deleteSong(_ song: Song) async {
        print("\n🗑️ DEBUG: Attempting to delete song")
        print("  - Title: \(song.title)")
        print("  - Artist: \(song.artist ?? "Unknown")")
        print("  - File path: \(song.filePath)")
        
        let context = persistenceController.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", song.id as CVarArg)
        
        do {
            let results = try context.fetch(request)
            if let songEntity = results.first {
                // Delete the file if it's in our Media directory
                if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
                    let filePath = song.filePath
                    
                    if filePath.hasPrefix(mediaDirectory.path) {
                        print("📂 DEBUG: Deleting internal file")
                        try? FileManager.default.removeItem(atPath: filePath)
                    }
                }
                
                // Delete from Core Data
                context.delete(songEntity)
                try context.save()
                print("✅ DEBUG: Successfully deleted song")
                
                // Refresh the song list
                await loadSongs()
            }
        } catch {
            print("❌ DEBUG: Failed to delete song: \(error)")
            self.error = error
        }
    }
    
    /// Get current search delay for debugging (using modular service)
    var currentSearchDelayMs: Int {
        performanceOptimizationService.currentSearchDelayMs
    }
    
    /// Enable scroll-optimized search delay for faster scrolling (delegated to service)
    func setScrollOptimizedSearchDelay() {
        performanceOptimizationService.setScrollOptimizedSearchDelay()
    }
    
    /// Restore normal search delay (delegated to service)
    func restoreNormalSearchDelay() {
        performanceOptimizationService.restoreNormalSearchDelay()
    }
}


