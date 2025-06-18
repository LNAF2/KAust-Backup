import SwiftUI
import Combine
import CoreData

// MARK: - Song List View Model

/// ViewModel for managing song list display and interactions
@MainActor
class SongListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var songs: [SongEntity] = []
    @Published private(set) var filteredSongs: [SongEntity] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    @Published var searchText = ""
    @Published var selectedGenres: Set<String> = []
    @Published var selectedLanguage: String?
    @Published var selectedEvent: String?
    @Published var sortOption: SortOption = .titleAscending
    
    // MARK: - Filter Options
    @Published private(set) var availableGenres: [GenreEntity] = []
    @Published private(set) var availableLanguages: [String] = []
    @Published private(set) var availableEvents: [String] = []
    
    // MARK: - Dependencies
    private let dataProvider: DataProviderServiceProtocol
    private let persistenceController: PersistenceController
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Performance Mode Tracking
    @Published private(set) var isInPerformanceMode = false
    private var suspendedObservers = false
    
    // MARK: - Computed Properties
    var isEmpty: Bool {
        filteredSongs.isEmpty
    }
    
    var songCount: Int {
        filteredSongs.count
    }
    
    var totalSongCount: Int {
        songs.count
    }
    
    // MARK: - Initializer
    init(dataProvider: DataProviderServiceProtocol = DataProviderService(), 
         persistenceController: PersistenceController = .shared) {
        print("🏗️ SongListViewModel.init() - Creating new SongListViewModel instance")
        self.dataProvider = dataProvider
        self.persistenceController = persistenceController
        setupBindings()
        setupCoreDataObserver()
        print("✅ SongListViewModel.init() - Setup complete")
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Observe search and filter changes
        Publishers.CombineLatest4(
            $searchText.debounce(for: .milliseconds(300), scheduler: RunLoop.main),
            $selectedGenres,
            $selectedLanguage,
            $selectedEvent
        )
        .sink { [weak self] _, _, _, _ in
            self?.applyFilters()
        }
        .store(in: &cancellables)
        
        // Observe sort option changes
        $sortOption
            .sink { [weak self] _ in
                self?.applySorting()
            }
            .store(in: &cancellables)
    }
    
    private func setupCoreDataObserver() {
        // PERFORMANCE: Setup performance mode observers first
        setupPerformanceModeObserver()
        
        // PERFORMANCE: Suspend Core Data observers during video playback for smooth performance
        NotificationCenter.default.addObserver(
            forName: .init("SuspendCoreDataObservers"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⏸️ PERFORMANCE: SongListViewModel suspending Core Data observers for smooth video")
            Task { @MainActor in
                self?.suspendedObservers = true
                self?.cancellables.removeAll() // Suspend all reactive observers
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("RestoreCoreDataObservers"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("▶️ PERFORMANCE: SongListViewModel restoring Core Data observers")
            Task { @MainActor in
                self?.suspendedObservers = false
                self?.setupCoreDataObserver() // Restore observers
            }
        }
        
        // Don't setup observers if they are currently suspended
        guard !suspendedObservers else {
            print("⏸️ PERFORMANCE: Skipping Core Data observer setup - currently suspended")
            return
        }
        
        // PERFORMANCE: Debounced Core Data observer to prevent excessive refreshes with large datasets
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main) // Debounce rapid changes
            .sink { [weak self] notification in
                // Skip processing during performance mode
                guard !(self?.isInPerformanceMode ?? false) else {
                    print("⏸️ PERFORMANCE: Skipping Core Data update during video playback")
                    return
                }
                
                // Check if the notification is from our context or a related context
                if let context = notification.object as? NSManagedObjectContext,
                   context.persistentStoreCoordinator == self?.persistenceController.container.persistentStoreCoordinator {
                    
                    // Check if SongEntity objects were inserted, updated, or deleted
                    let insertedObjects = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? Set()
                    let updatedObjects = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? Set()
                    let deletedObjects = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? Set()
                    
                    let songChanges = insertedObjects.union(updatedObjects).union(deletedObjects)
                        .contains { $0 is SongEntity }
                    
                    if songChanges {
                        // PERFORMANCE: For large datasets, only refresh if significant changes
                        let changeCount = insertedObjects.count + updatedObjects.count + deletedObjects.count
                        print("🔄 Core Data change detected: \(changeCount) changes")
                        
                        Task { @MainActor in
                            // Immediate refresh for small changes, debounced for large changes
                            if changeCount <= 10 || self?.songs.count ?? 0 <= 1000 {
                                await self?.refresh()
                            } else {
                                print("🚀 Large dataset change - using optimized refresh")
                                await self?.optimizedRefresh()
                            }
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Also listen for manual import notifications with debouncing
        NotificationCenter.default.publisher(for: NSNotification.Name("SongImported"))
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                // Skip processing during performance mode
                guard !(self?.isInPerformanceMode ?? false) else {
                    print("⏸️ PERFORMANCE: Skipping song import refresh during video playback")
                    return
                }
                
                Task { @MainActor in
                    print("🔄 Received SongImported notification - refreshing song list")
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Setup performance mode observer to track video playback state
    private func setupPerformanceModeObserver() {
        NotificationCenter.default.addObserver(
            forName: .init("VideoPerformanceModeEnabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🚀 PERFORMANCE: SongListViewModel entering performance mode")
            Task { @MainActor in
                self?.isInPerformanceMode = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("VideoPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 PERFORMANCE: SongListViewModel exiting performance mode")
            Task { @MainActor in
                self?.isInPerformanceMode = false
            }
        }
        
        // ULTRA-PERFORMANCE: Additional observers for drag operations
        NotificationCenter.default.addObserver(
            forName: .init("VideoUltraPerformanceModeEnabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🎯 ULTRA-PERFORMANCE: SongListViewModel entering ultra-performance mode")
            Task { @MainActor in
                self?.isInPerformanceMode = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("VideoUltraPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🎯 ULTRA-PERFORMANCE: SongListViewModel exiting ultra-performance mode")
            Task { @MainActor in
                // Keep normal performance mode if video is still playing
                self?.isInPerformanceMode = true
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Load all songs from Core Data with performance optimizations
    func loadSongs() async {
        print("🔄 SongListViewModel.loadSongs() - Starting optimized load for large dataset...")
        isLoading = true
        error = nil
        
        do {
            // PERFORMANCE: Load songs in background thread to prevent UI blocking
            let loadedSongs = await withCheckedContinuation { continuation in
                Task.detached { [weak self] in
                    guard let self = self else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    do {
                        let songs = try await self.dataProvider.fetchAllSongs(
                            sortedBy: self.sortOption.coreDataKey,
                            ascending: self.sortOption.isAscending
                        )
                        
                        // PERFORMANCE: Reduced logging for large datasets
                        print("🎵 SongListViewModel.loadSongs() - Fetched \(songs.count) songs from Core Data")
                        if songs.count <= 50 {
                            // Only log individual songs for small datasets
                            for song in songs.prefix(50) {
                                print("  - '\(song.title ?? "Unknown")' by '\(song.artist ?? "Unknown")'")
                            }
                        } else {
                            print("  - Large dataset (\(songs.count) songs) - skipping detailed logging for performance")
                        }
                        
                        continuation.resume(returning: songs)
                    } catch {
                        print("❌ SongListViewModel.loadSongs() - Error: \(error)")
                        continuation.resume(returning: [])
                    }
                }
            }
            
            // Update UI on main thread
            await MainActor.run {
                self.songs = loadedSongs
            }
            
            print("🔧 SongListViewModel.loadSongs() - Loading filter options...")
            // Load filter options in background
            await loadFilterOptions()
            
            print("🎯 SongListViewModel.loadSongs() - Applying filters...")
            // Apply current filters
            await MainActor.run {
                self.applyFilters()
            }
            
            print("✅ SongListViewModel.loadSongs() - Completed successfully with \(filteredSongs.count) filtered songs")
            isLoading = false
        } catch {
            print("❌ SongListViewModel.loadSongs() - Error: \(error)")
            await MainActor.run {
                self.error = error
                self.isLoading = false
            }
        }
    }
    
    /// Refresh song list
    func refresh() async {
        await loadSongs()
    }
    
    /// Optimized refresh for large datasets - only updates if needed
    func optimizedRefresh() async {
        print("🚀 Performing optimized refresh for large dataset...")
        isLoading = true
        
        do {
            // Quick count check first
            let context = persistenceController.container.viewContext
            let countRequest: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
            let currentCount = try context.count(for: countRequest)
            
            // Only do full reload if count changed significantly
            if abs(currentCount - songs.count) > 5 {
                print("📊 Dataset size changed significantly (\(songs.count) → \(currentCount)) - full reload")
                await loadSongs()
            } else {
                print("📊 Dataset size stable (\(currentCount) songs) - skipping full reload")
                await MainActor.run {
                    self.applyFilters() // Just re-apply filters
                    self.isLoading = false
                }
            }
        } catch {
            // Fallback to full refresh on error
            print("❌ Optimized refresh failed, falling back to full refresh: \(error)")
            await loadSongs()
        }
    }
    
    /// Force complete refresh - used after major operations like clear all songs
    func forceRefresh() async {
        print("🔄 Forcing complete refresh - clearing cache and reloading")
        await MainActor.run {
            self.songs = []
            self.filteredSongs = []
        }
        await loadSongs()
    }
    
    /// Delete a song
    func deleteSong(_ song: SongEntity) async {
        do {
            try await dataProvider.deleteSong(song)
            await loadSongs() // Refresh list
        } catch {
            self.error = error
        }
    }
    
    /// Update play count for a song
    func playedSong(_ song: SongEntity) async {
        do {
            try await dataProvider.updateSongPlayCount(songID: song.id ?? UUID())
            // Update local copy
            if let index = songs.firstIndex(where: { $0.id == song.id }) {
                songs[index].playCount += 1
                songs[index].lastPlayedDate = Date()
            }
            applyFilters()
        } catch {
            self.error = error
        }
    }
    
    /// Clear all filters
    func clearFilters() {
        searchText = ""
        selectedGenres.removeAll()
        selectedLanguage = nil
        selectedEvent = nil
    }
    
    /// Add genre filter
    func addGenreFilter(_ genreName: String) {
        selectedGenres.insert(genreName)
    }
    
    /// Remove genre filter
    func removeGenreFilter(_ genreName: String) {
        selectedGenres.remove(genreName)
    }
    
    /// Toggle genre filter
    func toggleGenreFilter(_ genreName: String) {
        if selectedGenres.contains(genreName) {
            selectedGenres.remove(genreName)
        } else {
            selectedGenres.insert(genreName)
        }
    }
    
    // MARK: - Private Methods
    
    private func loadFilterOptions() async {
        do {
            // Load available genres
            availableGenres = try await dataProvider.fetchAllGenres()
            
            // Extract unique languages and events from songs
            availableLanguages = Array(Set(songs.compactMap { $0.language })).sorted()
            availableEvents = Array(Set(songs.compactMap { $0.event })).sorted()
            
        } catch {
            // Handle error silently for filter options
            print("Failed to load filter options: \(error)")
        }
    }
    
    private func applyFilters() {
        var filtered = songs
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { song in
                (song.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (song.artist?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
        
        // Apply genre filter
        if !selectedGenres.isEmpty {
            filtered = filtered.filter { song in
                guard let genres = song.genres?.allObjects as? [GenreEntity] else { return false }
                return genres.contains { genre in
                    selectedGenres.contains(genre.name ?? "")
                }
            }
        }
        
        // Apply language filter
        if let language = selectedLanguage {
            filtered = filtered.filter { $0.language == language }
        }
        
        // Apply event filter
        if let event = selectedEvent {
            filtered = filtered.filter { $0.event == event }
        }
        
        filteredSongs = filtered
        applySorting()
    }
    
    private func applySorting() {
        filteredSongs.sort { song1, song2 in
            switch sortOption {
            case .titleAscending:
                return (song1.title ?? "") < (song2.title ?? "")
            case .titleDescending:
                return (song1.title ?? "") > (song2.title ?? "")
            case .artistAscending:
                return (song1.artist ?? "") < (song2.artist ?? "")
            case .artistDescending:
                return (song1.artist ?? "") > (song2.artist ?? "")
            case .dateAddedNewest:
                return (song1.dateAdded ?? Date.distantPast) > (song2.dateAdded ?? Date.distantPast)
            case .dateAddedOldest:
                return (song1.dateAdded ?? Date.distantPast) < (song2.dateAdded ?? Date.distantPast)
            case .durationShortest:
                return song1.duration < song2.duration
            case .durationLongest:
                return song1.duration > song2.duration
            case .playCountMost:
                return song1.playCount > song2.playCount
            case .playCountLeast:
                return song1.playCount < song2.playCount
            }
        }
    }
}

// MARK: - Sort Options

enum SortOption: String, CaseIterable {
    case titleAscending = "Title A-Z"
    case titleDescending = "Title Z-A"
    case artistAscending = "Artist A-Z"
    case artistDescending = "Artist Z-A"
    case dateAddedNewest = "Newest First"
    case dateAddedOldest = "Oldest First"
    case durationShortest = "Shortest First"
    case durationLongest = "Longest First"
    case playCountMost = "Most Played"
    case playCountLeast = "Least Played"
    
    var coreDataKey: String? {
        switch self {
        case .titleAscending, .titleDescending:
            return "title"
        case .artistAscending, .artistDescending:
            return "artist"
        case .dateAddedNewest, .dateAddedOldest:
            return "dateAdded"
        case .durationShortest, .durationLongest:
            return "duration"
        case .playCountMost, .playCountLeast:
            return "playCount"
        }
    }
    
    var isAscending: Bool {
        switch self {
        case .titleAscending, .artistAscending, .dateAddedOldest, .durationShortest, .playCountLeast:
            return true
        case .titleDescending, .artistDescending, .dateAddedNewest, .durationLongest, .playCountMost:
            return false
        }
    }
}

// MARK: - Extensions

extension SongEntity {
    /// Formatted duration string
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Formatted file size
    var formattedFileSize: String {
        let bytes = fileSizeBytes
        let formatter = ByteCountFormatter()
        formatter.unitStyle = .abbreviated
        return formatter.string(fromByteCount: bytes)
    }
    
    /// Formatted date added
    var formattedDateAdded: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: dateAdded ?? Date())
    }
    
    /// Genre names as array
    var genreNames: [String] {
        guard let genres = genres?.allObjects as? [GenreEntity] else { return [] }
        return genres.compactMap { $0.name }.sorted()
    }
    
    /// Genre names as comma-separated string
    var genresString: String {
        genreNames.joined(separator: ", ")
    }
} 