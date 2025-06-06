//
//  SonglistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import Foundation

class SongListViewModel: ObservableObject {
    @Published var songs: [Song] = []

    init() {
        self.songs = SongLoader.loadSongs()
    }
}
