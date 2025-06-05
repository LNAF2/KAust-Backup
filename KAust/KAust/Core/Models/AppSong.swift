//
//  AppSong.swift
//  KAust
//
//  Created by Erling Breaden on 5/6/2025.
//

import Foundation

struct AppSong: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: String
}

extension AppSong {
    var durationSeconds: TimeInterval {
        let parts = duration.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }
}
