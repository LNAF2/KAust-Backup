//
//  PlaylistItemView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistItemView.swift
import SwiftUI

struct PlaylistItemView: View {
    let song: AppSong

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(song.title)
                    .font(.headline)
                    .foregroundColor(.red)
                Text(song.artist)
                    .font(.subheadline)
                    .foregroundColor(.red.opacity(0.7))
            }
            Spacer()
            Image(systemName: "trash")
                .foregroundColor(.red)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.red.opacity(0.05))
        .cornerRadius(6)
    }
}
