//
//  AppSong.swift
//  KAust
//
//  Created by Erling Breaden on 5/6/2025.
//

import Foundation

struct AppSong: Identifiable, Equatable {
    let id: UUID
    let title: String
    let artist: String
    let duration: TimeInterval // in seconds

    static let mockSongs: [AppSong] = [
        AppSong(id: UUID(), title: "Bohemian Rhapsody", artist: "Queen", duration: 354),
        AppSong(id: UUID(), title: "Dancing Queen", artist: "ABBA", duration: 230),
        AppSong(id: UUID(), title: "Wonderwall", artist: "Oasis", duration: 258)
    ]
}
