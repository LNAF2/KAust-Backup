//
//  FuzzySearchService.swift
//  KAust
//
//  Created by Modularization on 26/6/2025.
//

import Foundation

// MARK: - Search Suggestion Model

/// Represents a search suggestion with type information
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

// MARK: - Fuzzy Search Service Protocol

/// Protocol defining fuzzy search capabilities
protocol FuzzySearchServiceProtocol {
    func performSearch(query: String, in songs: [Song], useSimpleMode: Bool) async -> (songs: [Song], suggestions: [SearchSuggestion])
    func generateSuggestions(for song: Song, query: String) -> Set<String>
    func calculateScore(for song: Song, query: String, queryWords: [String]) -> Double
}

// MARK: - Fuzzy Search Service Implementation

/// Service providing advanced fuzzy search functionality with typo tolerance and intelligent scoring
final class FuzzySearchService: FuzzySearchServiceProtocol {
    
    // MARK: - Public Search Methods
    
    /// Perform optimized fuzzy search with scoring and suggestions
    /// - Parameters:
    ///   - query: The search query string
    ///   - songs: Array of songs to search through
    ///   - useSimpleMode: Whether to use simplified search for performance
    /// - Returns: Tuple containing matching songs and search suggestions
    func performSearch(query: String, in songs: [Song], useSimpleMode: Bool = false) async -> (songs: [Song], suggestions: [SearchSuggestion]) {
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let queryWords = normalizedQuery.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        
        print("🔍 FuzzySearchService: Searching through \(songs.count) songs for query: '\(normalizedQuery)'")
        
        var scoredSongs: [(song: Song, score: Double)] = []
        var suggestionSet: Set<String> = []
        
        // Performance optimization based on mode
        let maxResults = useSimpleMode ? 50 : 100
        let chunkSize = useSimpleMode ? 50 : 100
        let songChunks = songs.chunked(into: chunkSize)
        
        for chunk in songChunks {
            for song in chunk {
                let artist = song.cleanArtist.lowercased()
                let title = song.cleanTitle.lowercased()
                
                var score: Double = 0
                
                // 1. Exact matches (fastest and highest priority)
                if artist.contains(normalizedQuery) || title.contains(normalizedQuery) {
                    score += 100
                }
                
                // 2. Word-by-word matching
                for word in queryWords {
                    if artist.contains(word) { score += 50 }
                    if title.contains(word) { score += 50 }
                }
                
                // 3. Prefix matching
                for word in queryWords {
                    if artist.hasPrefix(word) { score += 25 }
                    if title.hasPrefix(word) { score += 25 }
                }
                
                // 4. Fuzzy matching (skip in simple mode or for low-scoring results)
                if !useSimpleMode && score < 50 && scoredSongs.count < maxResults && normalizedQuery.count > 2 {
                    score += calculateLimitedFuzzyScore(song: song, query: normalizedQuery)
                }
                
                // 5. Acronym matching
                if matchesAcronym(query: normalizedQuery, text: artist) || matchesAcronym(query: normalizedQuery, text: title) {
                    score += 20
                }
                
                if score > 0 {
                    scoredSongs.append((song: song, score: score))
                    
                    // Generate suggestions for high-scoring matches
                    if score > 50 {
                        let newSuggestions = generateSuggestions(for: song, query: normalizedQuery)
                        suggestionSet.formUnion(newSuggestions)
                    }
                }
            }
            
            // Yield control periodically for performance
            let yieldInterval = useSimpleMode ? 25 : 50
            if songChunks.firstIndex(of: chunk)?.isMultiple(of: yieldInterval) == true {
                await Task.yield()
            }
        }
        
        // Sort by score and limit results
        scoredSongs.sort { $0.score > $1.score }
        let topSongs = Array(scoredSongs.prefix(maxResults))
        
        // Create suggestions with appropriate limits
        let suggestionLimit = useSimpleMode ? 3 : 5
        let suggestions = Array(suggestionSet.prefix(suggestionLimit)).map { 
            SearchSuggestion(text: $0, type: .completion) 
        }
        
        print("🎯 FuzzySearchService: Found \(topSongs.count) matches (from \(scoredSongs.count) total) - mode: \(useSimpleMode ? "simple" : "full")")
        
        return (songs: topSongs.map { $0.song }, suggestions: suggestions)
    }
    
    /// Generate search suggestions for a given song and query
    func generateSuggestions(for song: Song, query: String) -> Set<String> {
        var suggestionSet: Set<String> = []
        let artist = song.artist.lowercased()
        let title = song.title.lowercased()
        let normalizedQuery = query.lowercased()
        
        // Add artist name if it partially matches
        if artist.contains(normalizedQuery) && artist != normalizedQuery {
            suggestionSet.insert(song.artist)
        }
        
        // Add song title if it partially matches
        if title.contains(normalizedQuery) && title != normalizedQuery {
            suggestionSet.insert(song.title)
        }
        
        // Add combined suggestion for strong matches
        if artist.contains(normalizedQuery) || title.contains(normalizedQuery) {
            suggestionSet.insert("\(song.artist) - \(song.title)")
        }
        
        return suggestionSet
    }
    
    /// Calculate comprehensive fuzzy score for a song
    func calculateScore(for song: Song, query: String, queryWords: [String]) -> Double {
        let artist = song.artist.lowercased()
        let title = song.title.lowercased()
        let fullText = "\(artist) \(title)"
        let normalizedQuery = query.lowercased()
        
        var totalScore: Double = 0
        
        // 1. Exact matches (highest priority)
        if artist.contains(normalizedQuery) || title.contains(normalizedQuery) {
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
        let artistDistance = levenshteinDistance(artist, normalizedQuery)
        let titleDistance = levenshteinDistance(title, normalizedQuery)
        let fullTextDistance = levenshteinDistance(fullText, normalizedQuery)
        
        // Convert distance to score (lower distance = higher score)
        let maxLength = max(artist.count, title.count, fullText.count)
        if maxLength > 0 {
            let artistFuzzyScore = max(0, Double(maxLength - artistDistance) / Double(maxLength)) * 30
            let titleFuzzyScore = max(0, Double(maxLength - titleDistance) / Double(maxLength)) * 30
            let fullTextFuzzyScore = max(0, Double(maxLength - fullTextDistance) / Double(maxLength)) * 20
            
            totalScore += max(artistFuzzyScore, titleFuzzyScore, fullTextFuzzyScore)
        }
        
        // 4. Prefix matching bonus
        if artist.hasPrefix(normalizedQuery) || title.hasPrefix(normalizedQuery) {
            totalScore += 25
        }
        
        // 5. Word prefix bonus
        for word in queryWords {
            if artist.hasPrefix(word) || title.hasPrefix(word) {
                totalScore += 15
            }
        }
        
        // 6. Acronym matching bonus
        if matchesAcronym(query: normalizedQuery, text: artist) || matchesAcronym(query: normalizedQuery, text: title) {
            totalScore += 20
        }
        
        return totalScore
    }
    
    // MARK: - Private Helper Methods
    
    /// Calculate limited fuzzy score for performance optimization
    private func calculateLimitedFuzzyScore(song: Song, query: String) -> Double {
        let artist = song.cleanArtist.lowercased()
        let title = song.cleanTitle.lowercased()
        
        // Limit string length for performance
        let maxLength = 30
        let truncatedArtist = String(artist.prefix(maxLength))
        let truncatedTitle = String(title.prefix(maxLength))
        
        let artistDistance = levenshteinDistance(truncatedArtist, query)
        let titleDistance = levenshteinDistance(truncatedTitle, query)
        
        let artistScore = max(0, Double(truncatedArtist.count - artistDistance) / Double(max(truncatedArtist.count, 1))) * 20
        let titleScore = max(0, Double(truncatedTitle.count - titleDistance) / Double(max(truncatedTitle.count, 1))) * 20
        
        return max(artistScore, titleScore)
    }
    
    /// Check if query matches acronym of text (e.g., "ac" matches "Alan Jackson")
    private func matchesAcronym(query: String, text: String) -> Bool {
        let words = text.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).filter { !$0.isEmpty }
        let acronym = words.compactMap { $0.first?.lowercased() }.joined()
        return acronym.hasPrefix(query.lowercased())
    }
    
    // MARK: - Levenshtein Distance Algorithm
    
    /// Calculate Levenshtein distance between two strings for fuzzy matching
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
        
        // Fill the matrix using dynamic programming
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
}

// MARK: - Array Extension for Chunking

extension Array {
    /// Split array into chunks of specified size for batch processing
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
} 