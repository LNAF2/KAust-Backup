//
//  Song.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation

struct Song: Identifiable, Codable {
    let id: String
    let title: String
    let artist: String
    let duration: String
    let filePath: String
}
