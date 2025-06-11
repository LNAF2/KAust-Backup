//
//  SonglistItemView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//


import SwiftUI

struct SongListItemView: View {
    let song: Song // <-- Change from AppSong to Song

    var body: some View {
        ZStack {
            AppTheme.leftPanelListBackground
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelAccent.opacity(0.5), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(song.artist.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.leftPanelAccent)
                HStack(alignment: .firstTextBaseline) {
                    Text(song.title.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    Spacer()
                    Text(song.duration.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.leftPanelAccent)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


/*
import SwiftUI

struct SongListItemView: View {
    let song: AppSong

    var body: some View {
        ZStack {
            AppTheme.leftPanelListBackground
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelAccent.opacity(0.5), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(song.artist.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.leftPanelAccent)
                HStack(alignment: .firstTextBaseline) {
                    Text(song.title)
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    Spacer()
                    Text(song.duration)
                        .font(.caption)
                        .foregroundColor(AppTheme.leftPanelAccent)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
*/
