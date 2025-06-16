//
//  SonglistItemView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//


import SwiftUI

struct SongListItemView: View {
    let song: Song
    let isInPlaylist: Bool
    let isCurrentlyPlaying: Bool
    
    init(song: Song, isInPlaylist: Bool = false, isCurrentlyPlaying: Bool = false) {
        self.song = song
        self.isInPlaylist = isInPlaylist
        self.isCurrentlyPlaying = isCurrentlyPlaying
    }

    var body: some View {
        ZStack {
            // Background color changes based on playlist state
            if isInPlaylist || isCurrentlyPlaying {
                // Purple background when song is in playlist or playing
                Color("LeftPanelListBg").opacity(0.5)
            } else {
                // Normal light purple background
                Color.purple.opacity(0.1)
            }
            
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelAccent.opacity(0.5), lineWidth: 1)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                if isCurrentlyPlaying {
                    // Show "currently playing" message
                    Text("SONG CURRENTLY PLAYING")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.8))
                        .padding(.bottom, 2)
                } else if isInPlaylist {
                    // Show "already in playlist" message
                    Text("SONG ALREADY IN PLAY LIST")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.bottom, 2)
                }
                
                Text(song.cleanTitle.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor((isInPlaylist || isCurrentlyPlaying) ? AppTheme.leftPanelAccent.opacity(0.6) : AppTheme.leftPanelAccent)
                
                HStack(alignment: .firstTextBaseline) {
                    Text(song.cleanArtist.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor((isInPlaylist || isCurrentlyPlaying) ? AppTheme.leftPanelAccent.opacity(0.5) : AppTheme.leftPanelAccent.opacity(0.7))
                    Spacer()
                    Text(song.duration.uppercased())
                        .font(.headline)
                        .fontWeight(.regular)
                        .foregroundColor((isInPlaylist || isCurrentlyPlaying) ? AppTheme.leftPanelAccent.opacity(0.6) : AppTheme.leftPanelAccent)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .opacity((isInPlaylist || isCurrentlyPlaying) ? 0.8 : 1.0) // Slightly dimmed when in playlist or playing
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
