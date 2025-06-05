//
//  SonglistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import Foundation

class SonglistViewModel: ObservableObject {
    @Published var songs: [AppSong] = [
        AppSong(title: "Bohemian Rhapsody", artist: "Queen", duration: "5:55"),
        AppSong(title: "Imagine", artist: "John Lennon", duration: "3:12"),
        AppSong(title: "Hey Jude", artist: "The Beatles", duration: "7:11")
    ]
}
