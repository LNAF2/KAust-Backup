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
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms delay
                updateDisplaySongs()
            }
        }
    }
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var isSearching = false
    @Published var showingSuggestions = false
    @Published var error: Error?
    
    // MARK: - Performance Mode Tracking
    @Published private(set) var isInPerformanceMode = false
    private var suspendedObservers = false

    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = [] // Keep original list for searching
    private let searchSubject = PassthroughSubject<String, Never>()
    private var searchDebounceTask: Task<Void, Error>?
    
    // Computed property for display
    var displayCount: Int {
        displaySongs.count
    }

    init() {
        setupObservers()
        Task {
            await loadSongs()
        }
    }
    
    deinit {
        searchDebounceTask?.cancel()
    }
    
    private func setupObservers() {
        // PERFORMANCE: Setup performance mode observers first
        setupPerformanceModeObserver()
        
        // PERFORMANCE: Suspend Core Data observers during video playback for smooth performance
        NotificationCenter.default.addObserver(
            forName: .init("SuspendCoreDataObservers"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⏸️ PERFORMANCE: OLD SongListViewModel suspending Core Data observers for smooth video")
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
            print("▶️ PERFORMANCE: OLD SongListViewModel restoring Core Data observers")
            Task { @MainActor in
                self?.suspendedObservers = false
                self?.setupObservers() // Restore observers
            }
        }
        
        // Don't setup observers if they are currently suspended
        guard !suspendedObservers else {
            print("⏸️ PERFORMANCE: Skipping Core Data observer setup - currently suspended")
            return
        }
        
        // PERFORMANCE: Debounced Core Data observer to prevent excessive refreshes
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Skip processing during performance mode
                guard !(self?.isInPerformanceMode ?? false) else {
                    print("⏸️ PERFORMANCE: Skipping Core Data update during video playback")
                    return
                }
                
                Task { @MainActor in
                    print("🔄 Received Core Data change notification - Reloading songs (debounced)")
                    await self?.loadSongs()
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
            print("🚀 PERFORMANCE: OLD SongListViewModel entering performance mode")
            Task { @MainActor in
                self?.isInPerformanceMode = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("VideoPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 PERFORMANCE: OLD SongListViewModel exiting performance mode")
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
            print("🎯 ULTRA-PERFORMANCE: OLD SongListViewModel entering ultra-performance mode")
            Task { @MainActor in
                self?.isInPerformanceMode = true
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("VideoUltraPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🎯 ULTRA-PERFORMANCE: OLD SongListViewModel exiting ultra-performance mode")
            Task { @MainActor in
                // Stay in normal performance mode if video is still playing
                if self?.getCurrentVideo() != nil {
                    print("🎯 ULTRA-PERFORMANCE: Maintaining normal performance mode - video still playing")
                    // Keep performance mode active
                } else {
                    self?.isInPerformanceMode = false
                }
            }
        }
    }
    
    /// Get current video from VideoPlayerViewModel (helper method)
    private func getCurrentVideo() -> Song? {
        // Access VideoPlayerViewModel through ContentView or use notification pattern
        // For now, return nil to be safe
        return nil
    }
    
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
    
    // MARK: - Fuzzy Search Implementation
    
    private func performFuzzySearch(_ searchText: String) {
        guard !searchText.isEmpty else {
            filteredSongs = []
            searchSuggestions = []
            showingSuggestions = false
            isSearching = false
            return
        }
        
        isSearching = true
        print("🔍 Performing optimized search for: '\(searchText)'")
        
        // Perform search in background to avoid UI blocking
        Task.detached { [weak self] in
            guard let self = self else { return }
            
            let searchResults = await self.optimizedFuzzySearch(query: searchText)
            
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
    
    private func optimizedFuzzySearch(query: String) async -> (songs: [Song], suggestions: [SearchSuggestion]) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = normalizedQuery.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        
        print("🔍 DEBUG: Searching through \(allSongs.count) songs for query: '\(normalizedQuery)'")
        
        var scoredSongs: [(song: Song, score: Double)] = []
        var suggestionSet: Set<String> = []
        let maxResults = 100 // Limit results for performance
        
        // Process songs in chunks to avoid blocking
        let chunkSize = 100
        let songChunks = allSongs.chunked(into: chunkSize)
        
        for chunk in songChunks {
            // Fast path: Simple contains search first
            for song in chunk {
                let artist = song.cleanArtist.lowercased()
                let title = song.cleanTitle.lowercased()
                
                var score: Double = 0
                
                // 1. Exact matches (fastest)
                if artist.contains(normalizedQuery) || title.contains(normalizedQuery) {
                    score += 100
                }
                
                // 2. Word matches (fast)
                for word in queryWords {
                    if artist.contains(word) { score += 50 }
                    if title.contains(word) { score += 50 }
                }
                
                // 3. Prefix matches (fast)
                for word in queryWords {
                    if artist.hasPrefix(word) { score += 25 }
                    if title.hasPrefix(word) { score += 25 }
                }
                
                // 4. Only do expensive fuzzy matching if we don't have enough results yet
                if score < 50 && scoredSongs.count < maxResults && normalizedQuery.count > 2 {
                    score += calculateLimitedFuzzyScore(song: song, query: normalizedQuery)
                }
                
                if score > 0 {
                    scoredSongs.append((song: song, score: score))
                    
                    // Generate suggestions (limit to top matches)
                    if score > 50 {
                        addSuggestions(for: song, query: normalizedQuery, to: &suggestionSet)
                    }
                }
            }
            
            // Yield control periodically to avoid blocking
            await Task.yield()
        }
        
        // Sort by score and limit results
        scoredSongs.sort { $0.score > $1.score }
        let topSongs = Array(scoredSongs.prefix(maxResults))
        
        let suggestions = Array(suggestionSet.prefix(5)).map { SearchSuggestion(text: $0, type: .completion) }
        
        print("🎯 Found \(topSongs.count) matches (limited from \(scoredSongs.count) total)")
        
        return (songs: topSongs.map { $0.song }, suggestions: suggestions)
    }
    
    private func calculateLimitedFuzzyScore(song: Song, query: String) -> Double {
        let artist = song.cleanArtist.lowercased()
        let title = song.cleanTitle.lowercased()
        
        // Only calculate fuzzy score for shorter strings to save time
        let maxLength = 30
        let truncatedArtist = String(artist.prefix(maxLength))
        let truncatedTitle = String(title.prefix(maxLength))
        
        let artistDistance = levenshteinDistance(truncatedArtist, query)
        let titleDistance = levenshteinDistance(truncatedTitle, query)
        
        let artistScore = max(0, Double(truncatedArtist.count - artistDistance) / Double(max(truncatedArtist.count, 1))) * 20
        let titleScore = max(0, Double(truncatedTitle.count - titleDistance) / Double(max(truncatedTitle.count, 1))) * 20
        
        return max(artistScore, titleScore)
    }
    
    private func calculateFuzzyScore(song: Song, query: String, queryWords: [String]) -> Double {
        let artist = song.artist.lowercased()
        let title = song.title.lowercased()
        let fullText = "\(artist) \(title)"
        
        var totalScore: Double = 0
        
        // 1. Exact matches (highest priority)
        if artist.contains(query) || title.contains(query) {
            totalScore += 100
        }
        
        // 2. Word-by-word matching
        for word in queryWords {
            if artist.contains(word) {
                totalScore += 50
            }
            if title.contains(word) {
                totalScore += 50
            }
        }
        
        // 3. Fuzzy matching with Levenshtein distance
        let artistDistance = levenshteinDistance(artist, query)
        let titleDistance = levenshteinDistance(title, query)
        let fullTextDistance = levenshteinDistance(fullText, query)
        
        // Convert distance to score (lower distance = higher score)
        let maxLength = max(artist.count, title.count, fullText.count)
        if maxLength > 0 {
            let artistFuzzyScore = max(0, Double(maxLength - artistDistance) / Double(maxLength)) * 30
            let titleFuzzyScore = max(0, Double(maxLength - titleDistance) / Double(maxLength)) * 30
            let fullTextFuzzyScore = max(0, Double(maxLength - fullTextDistance) / Double(maxLength)) * 20
            
            totalScore += max(artistFuzzyScore, titleFuzzyScore, fullTextFuzzyScore)
        }
        
        // 4. Starts with bonus
        if artist.hasPrefix(query) || title.hasPrefix(query) {
            totalScore += 25
        }
        
        // 5. Word starts with bonus
        for word in queryWords {
            if artist.hasPrefix(word) || title.hasPrefix(word) {
                totalScore += 15
            }
        }
        
        // 6. Acronym matching (e.g., "ac" matches "Alan Jackson")
        if matchesAcronym(query: query, text: artist) || matchesAcronym(query: query, text: title) {
            totalScore += 20
        }
        
        return totalScore
    }
    
    private func addSuggestions(for song: Song, query: String, to suggestionSet: inout Set<String>) {
        let artist = song.artist.lowercased()
        let title = song.title.lowercased()
        
        // Add artist name if it partially matches
        if artist.contains(query) && artist != query {
            suggestionSet.insert(song.artist)
        }
        
        // Add song title if it partially matches
        if title.contains(query) && title != query {
            suggestionSet.insert(song.title)
        }
        
        // Add combined suggestion
        if artist.contains(query) || title.contains(query) {
            suggestionSet.insert("\(song.artist) - \(song.title)")
        }
    }
    
    private func matchesAcronym(query: String, text: String) -> Bool {
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        let acronym = words.compactMap { $0.first?.lowercased() }.joined()
        return acronym.hasPrefix(query.lowercased())
    }
    
    // MARK: - Levenshtein Distance Algorithm
    
    private func levenshteinDistance(_ s1: String, _ s2: String) -> Int {
        let s1Array = Array(s1)
        let s2Array = Array(s2)
        let s1Count = s1Array.count
        let s2Count = s2Array.count
        
        if s1Count == 0 { return s2Count }
        if s2Count == 0 { return s1Count }
        
        var matrix = Array(repeating: Array(repeating: 0, count: s2Count + 1), count: s1Count + 1)
        
        // Initialize first row and column
        for i in 0...s1Count {
            matrix[i][0] = i
        }
        for j in 0...s2Count {
            matrix[0][j] = j
        }
        
        // Fill the matrix
        for i in 1...s1Count {
            for j in 1...s2Count {
                let cost = s1Array[i-1] == s2Array[j-1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i-1][j] + 1,      // deletion
                    matrix[i][j-1] + 1,      // insertion
                    matrix[i-1][j-1] + cost  // substitution
                )
            }
        }
        
        return matrix[s1Count][s2Count]
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
}

// MARK: - Search Suggestion Model

struct SearchSuggestion: Identifiable, Hashable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    
    enum SuggestionType {
        case completion
        case artist
        case song
        case combined
    }
}

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
