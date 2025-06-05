//
//  PlaylistEmptyState.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct PlaylistEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.red).opacity(0.5)
            Text("Please select songs from the Song List")
                .font(.title2)
                .foregroundColor(.red).opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
