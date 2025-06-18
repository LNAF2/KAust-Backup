//
//  PlaylistEmptyState.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct PlaylistEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Music note icon - bigger than Songs Played table design
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(.red.opacity(0.8))
            
            // Main heading
            Text("No Songs Selected")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(.red.opacity(0.8))
                .padding(.top, 16)
            
            // Explanation text
            Text("Select songs from the SONG LIST")
                .font(.subheadline)
                .foregroundColor(.red.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
