//
//  SonglistViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import Foundation
import Combine

@MainActor
class SonglistViewModel: ObservableObject {
    @Published var songs: [AppSong] = AppSong.mockSongs

    // For tap action
    func selectSong(_ song: SongEntity) {
        print("Selected song: \(song.title) by \(song.artist)")
    }
}
