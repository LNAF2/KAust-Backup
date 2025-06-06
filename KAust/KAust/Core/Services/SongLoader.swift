//
//  SongLoader.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation

class SongLoader {
    static func loadSongs() -> [Song] {
        guard let url = Bundle.main.url(forResource: "songs", withExtension: "json") else {
            print("songs.json not found")
            return []
        }
        do {
            let data = try Data(contentsOf: url)
            let songs = try JSONDecoder().decode([Song].self, from: data)
            return songs
        } catch {
            print("Failed to load songs: \(error)")
            return []
        }
    }
}
