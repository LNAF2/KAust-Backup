//
//  Song.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation

struct Song: Identifiable, Equatable {
    let id: String
    let title: String
    let artist: String
    let duration: String
    let filePath: String
    
    /// Clean title with supplier information in brackets removed
    var cleanTitle: String {
        title.removingBracketedText()
    }
    
    /// Clean artist with supplier information in brackets removed
    var cleanArtist: String {
        artist.removingBracketedText()
    }
    
    var videoURL: URL? {
        URL(fileURLWithPath: filePath)
    }
    
    init(id: String, title: String, artist: String, duration: String, filePath: String) {
        self.id = id
        self.title = title
        self.artist = artist
        self.duration = duration
        self.filePath = filePath
    }
    
    /// Create a Song from a SongEntity
    init?(from entity: SongEntity) {
        guard let id = entity.id?.uuidString,
              let title = entity.title,
              let filePath = entity.filePath else {
            return nil
        }
        
        let artist = entity.artist ?? "Unknown Artist"
        let minutes = Int(entity.duration) / 60
        let seconds = Int(entity.duration) % 60
        let duration = String(format: "%02d:%02d", minutes, seconds)
        
        self.init(
            id: id,
            title: title,
            artist: artist,
            duration: duration,
            filePath: filePath
        )
    }
}

// MARK: - String Extension for Bracket Removal

extension String {
    /// Removes text enclosed in brackets, including the brackets themselves
    /// This is used to remove supplier information like "[Karaoke Version]" or "[CDG]"
    func removingBracketedText() -> String {
        // Remove both square brackets [text] and parentheses (text)
        return self.replacingOccurrences(of: "\\s*[\\[\\(].*?[\\]\\)]\\s*", with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
