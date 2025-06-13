//
//  SonglistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import Foundation
import CoreData
import Combine

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []
    @Published var filteredSongs: [Song] = []
    @Published var searchText = "" {
        didSet {
            searchSubject.send(searchText)
        }
    }
    @Published var searchSuggestions: [SearchSuggestion] = []
    @Published var isSearching = false
    @Published var showingSuggestions = false
    
    private let persistenceController = PersistenceController.shared
    private var cancellables = Set<AnyCancellable>()
    private var allSongs: [Song] = [] // Keep original list for searching
    private let searchSubject = PassthroughSubject<String, Never>()
    
    // Computed property for display
    var displaySongs: [Song] {
        return searchText.isEmpty ? songs : filteredSongs
    }
    
    var displayCount: Int {
        return searchText.isEmpty ? songs.count : filteredSongs.count
    }

    init() {
        print("🏗️ OLD SongListViewModel.init() - Loading songs from Core Data")
        loadSongsFromCoreData()
        setupCoreDataObserver()
        setupSearchDebouncing()
    }
    
    private func setupCoreDataObserver() {
        // Observe Core Data changes for SongEntity
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] notification in
                DispatchQueue.main.async {
                    print("🔔 OLD SongListViewModel - Core Data change notification received")
                    self?.loadSongsFromCoreData()
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupSearchDebouncing() {
        // Debounce search input to avoid excessive filtering
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] searchText in
                self?.performFuzzySearch(searchText)
            }
            .store(in: &cancellables)
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
                print("  - '\(artist)' - '\(title)'")
                
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
        print("🔍 Performing fuzzy search for: '\(searchText)'")
        
        let searchResults = fuzzySearchSongs(query: searchText)
        
        DispatchQueue.main.async { [weak self] in
            self?.filteredSongs = searchResults.songs
            self?.searchSuggestions = searchResults.suggestions
            self?.showingSuggestions = !searchResults.suggestions.isEmpty
            self?.isSearching = false
            
            print("🎯 Search results: \(searchResults.songs.count) songs, \(searchResults.suggestions.count) suggestions")
        }
    }
    
    private func fuzzySearchSongs(query: String) -> (songs: [Song], suggestions: [SearchSuggestion]) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = normalizedQuery.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        
        var scoredSongs: [(song: Song, score: Double)] = []
        var suggestionSet: Set<String> = []
        
        for song in allSongs {
            let score = calculateFuzzyScore(song: song, query: normalizedQuery, queryWords: queryWords)
            
            if score > 0 {
                scoredSongs.append((song: song, score: score))
                
                // Generate suggestions
                addSuggestions(for: song, query: normalizedQuery, to: &suggestionSet)
            }
        }
        
        // Sort by score (highest first)
        scoredSongs.sort { $0.score > $1.score }
        
        let suggestions = Array(suggestionSet.prefix(5)).map { SearchSuggestion(text: $0, type: .completion) }
        
        return (songs: scoredSongs.map { $0.song }, suggestions: suggestions)
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
        await MainActor.run {
            let context = persistenceController.container.viewContext
            
            do {
                // Find the corresponding SongEntity in Core Data
                let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
                let songUUID = UUID(uuidString: song.id) ?? UUID()
                request.predicate = NSPredicate(format: "id == %@", songUUID as CVarArg)
                
                guard let songEntity = try context.fetch(request).first else {
                    print("❌ Could not find SongEntity for song: \(song.title)")
                    return
                }
                
                // Get file path before deleting the entity
                guard let filePath = songEntity.filePath else {
                    // No file path, just delete the Core Data entity
                    context.delete(songEntity)
                    try context.save()
                    print("✅ Deleted song metadata: \(song.title)")
                    return
                }
                
                // Determine if this is an internal or external file
                let fileManager = FileManager.default
                let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
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
                    if let lrcPath = songEntity.lrcFilePath, fileManager.fileExists(atPath: lrcPath) {
                        try fileManager.removeItem(atPath: lrcPath)
                        print("✅ Deleted LRC file: \(URL(fileURLWithPath: lrcPath).lastPathComponent)")
                    }
                } else {
                    print("📁 External file detected: \(fileName) - only deleting metadata")
                    
                    // Clean up bookmark for external file
                    let bookmarkKey = "fileBookmark_\(fileName)"
                    UserDefaults.standard.removeObject(forKey: bookmarkKey)
                    print("🧹 Cleaned up bookmark: \(bookmarkKey)")
                }
                
                // Delete the Core Data entity
                context.delete(songEntity)
                try context.save()
                
                print("✅ Successfully deleted song: \(song.title) by \(song.artist)")
                
            } catch {
                print("❌ Error deleting song: \(error)")
            }
        }
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
