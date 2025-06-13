//
//  Song.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation

struct Song: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let duration: String
    let filePath: String
    
    /// Clean title with supplier information in brackets removed
    var cleanTitle: String {
        return title.removingBracketedText()
    }
    
    /// Clean artist with supplier information in brackets removed
    var cleanArtist: String {
        return artist.removingBracketedText()
    }
    
    var videoURL: URL? {
        print("🔍 Song.videoURL - Checking file path: '\(filePath)'")
        
        // First try as a file path
        let fileURL = URL(fileURLWithPath: filePath)
        let fileExists = FileManager.default.fileExists(atPath: filePath)
        print("📁 File exists check: \(fileExists) for path: \(filePath)")
        
        if fileExists {
            print("✅ Using file URL: \(fileURL)")
            return fileURL
        }
        
        // Fallback to bundle resource - try multiple variations
        print("📦 Searching bundle resources...")
        
        // Try exact path
        var bundleURL = Bundle.main.url(forResource: filePath, withExtension: nil)
        print("📦 Bundle check (exact): \(bundleURL?.absoluteString ?? "nil")")
        
        if bundleURL == nil {
            // Try with .mp4 extension
            bundleURL = Bundle.main.url(forResource: filePath, withExtension: "mp4")
            print("📦 Bundle check (.mp4): \(bundleURL?.absoluteString ?? "nil")")
        }
        
        if bundleURL == nil {
            // Try without any path components, just the filename
            let filename = URL(fileURLWithPath: filePath).lastPathComponent
            let nameWithoutExtension = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
            
            bundleURL = Bundle.main.url(forResource: nameWithoutExtension, withExtension: "mp4")
            print("📦 Bundle check (filename only): \(bundleURL?.absoluteString ?? "nil")")
        }
        
        if bundleURL == nil {
            // List all bundle resources for debugging
            if let resourcePath = Bundle.main.resourcePath {
                do {
                    let resources = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    let videoFiles = resources.filter { $0.lowercased().hasSuffix(".mp4") }
                    print("📦 Available MP4 files in bundle: \(videoFiles)")
                    
                    // Look for a match
                    let searchTerm = filePath.lowercased()
                    for videoFile in videoFiles {
                        if videoFile.lowercased().contains(searchTerm) || searchTerm.contains(videoFile.lowercased().replacingOccurrences(of: ".mp4", with: "")) {
                            bundleURL = Bundle.main.url(forResource: videoFile, withExtension: nil)
                            print("📦 Found bundle match: \(videoFile)")
                            break
                        }
                    }
                } catch {
                    print("📦 Error listing bundle contents: \(error)")
                }
            }
        }
        
        if let bundleURL = bundleURL {
            print("✅ Using bundle URL: \(bundleURL)")
            return bundleURL
        }
        
        // Final fallback: return the file URL anyway and let AVPlayer handle the error
        print("⚠️ File doesn't exist but returning URL anyway: \(fileURL)")
        return fileURL
    }
    
    // MARK: - Equatable
    static func == (lhs: Song, rhs: Song) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Conversion Extensions

extension Song {
    /// Create a Song from a SongEntity
    init?(from entity: SongEntity) {
        guard let id = entity.id?.uuidString,
              let title = entity.title else {
            return nil
        }
        
        let artist = entity.artist ?? "Unknown Artist"
        let minutes = Int(entity.duration) / 60
        let seconds = Int(entity.duration) % 60
        let duration = String(format: "%02d:%02d", minutes, seconds)
        let filePath = entity.filePath ?? ""
        
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
