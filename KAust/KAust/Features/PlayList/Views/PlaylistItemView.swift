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
    private let cornerRadius: CGFloat = 8

    var body: some View {
        ZStack {
            AppTheme.rightPanelListBackground
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.rightPanelAccent.opacity(0.5), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.rightPanelAccent)
                HStack(alignment: .firstTextBaseline) {
                    Text(song.artist.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.rightPanelAccent.opacity(0.7))
                    Spacer()
                    Text(song.duration.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.rightPanelAccent)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}
