//
//  SonglistEmptyState.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SonglistEmptyState: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
                .foregroundColor(.purple).opacity(0.5)
            Text("Please download songs")
                .font(.title2)
                .foregroundColor(.purple).opacity(0.5)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}
