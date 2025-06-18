//
//  SonglistEmptyState.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SonglistEmptyState: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            // Music note icon - bigger than Songs Played table design
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.8))
            
            // Main heading
            Text("No Songs Yet")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.8))
                .padding(.top, 16)
            
            // Explanation text
            Text("Download Songs from Settings")
                .font(.subheadline)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, -50441
        ) // Compensate for search bar pushing content down
    }
}
