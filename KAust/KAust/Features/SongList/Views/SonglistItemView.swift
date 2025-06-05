//
//  SonglistItemView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SongListItemView: View {
    let song: AppSong

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.purple)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.purple.opacity(0.7))
            }
            Spacer()
            Text(formatDuration(song.duration))
                .font(.caption)
                .foregroundColor(.purple.opacity(0.7))
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.purple.opacity(0.05))
        .cornerRadius(6)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
