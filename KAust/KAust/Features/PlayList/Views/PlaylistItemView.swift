//
//  PlaylistItemView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistItemView.swift
import SwiftUI

struct PlaylistItemView: View {
    let song: Song
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title.uppercased())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.rightPanelTextPrimary)
                    .lineLimit(1)
                
                Text(song.artist.uppercased())
                    .font(.system(size: 14))
                    .foregroundColor(AppTheme.rightPanelTextSecondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Text(song.duration)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.rightPanelTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.rightPanelBackground)
        .cornerRadius(8)
        .onAppear {
            print("📱 PlaylistItemView appeared - \(song.title)")
        }
    }
}

#Preview {
    Group {
        PlaylistItemView(
            song: Song(
                id: "1",
                title: "Test Song",
                artist: "Test Artist",
                duration: "3:30",
                filePath: "/path/to/song.mp4"
            )
        )
        PlaylistItemView(
            song: Song(
                id: "2",
                title: "Another Song With a Very Long Title That Should Be Truncated",
                artist: "Artist With a Very Long Name That Should Also Be Truncated",
                duration: "4:15",
                filePath: "/path/to/song.mp4"
            )
        )
    }
    .padding()
    .background(AppTheme.rightPanelBackground)
}
