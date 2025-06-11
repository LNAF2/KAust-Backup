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
        // Observe Core Data changes for SongEntity
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
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
                        Task { @MainActor in
                            await self?.refresh()
                        }
                    }
                }
            }
            .store(in: &cancellables)
        
        // Also listen for manual import notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("SongImported"))
            .sink { [weak self] _ in
                Task { @MainActor in
                    print("🔄 Received SongImported notification - refreshing song list")
                    await self?.refresh()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Public Methods
    
    /// Load all songs from Core Data
    func loadSongs() async {
        print("🔄 SongListViewModel.loadSongs() - Starting to load songs...")
        isLoading = true
        error = nil
        
        do {
            print("📡 SongListViewModel.loadSongs() - Calling dataProvider.fetchAllSongs()")
            // Load songs
            songs = try await dataProvider.fetchAllSongs(
                sortedBy: sortOption.coreDataKey,
                ascending: sortOption.isAscending
            )
            
            // Debug logging
            print("🎵 SongListViewModel.loadSongs() - Fetched \(songs.count) songs from Core Data:")
            for song in songs {
                print("  - '\(song.title ?? "Unknown")' by '\(song.artist ?? "Unknown")' (Added: \(song.dateAdded ?? Date()))")
            }
            
            print("🔧 SongListViewModel.loadSongs() - Loading filter options...")
            // Load filter options
            await loadFilterOptions()
            
            print("🎯 SongListViewModel.loadSongs() - Applying filters...")
            // Apply current filters
            applyFilters()
            
            print("✅ SongListViewModel.loadSongs() - Completed successfully with \(filteredSongs.count) filtered songs")
            isLoading = false
        } catch {
            print("❌ SongListViewModel.loadSongs() - Error: \(error)")
            self.error = error
            isLoading = false
        }
    }
    
    /// Refresh song list
    func refresh() async {
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