//
//  SonglistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI
import Combine

struct SonglistView: View {
    @StateObject private var viewModel = SonglistViewModel()
    @EnvironmentObject private var playlistViewModel: PlaylistViewModel
    @State private var searchText = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.leftPanelAccent)
                TextField("Search songs...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(AppTheme.leftPanelTextPrimary)
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.leftPanelAccent)
                    }
                }
            }
            .padding(8)
            .background(AppTheme.leftPanelBackground)
            .cornerRadius(8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            
            // Song list
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(viewModel.filteredSongs(matching: searchText)) { song in
                        SongListItemView(
                            song: song,
                            isInPlaylist: playlistViewModel.isSongInPlaylist(song),
                            isCurrentlyPlaying: playlistViewModel.isSongCurrentlyPlaying(song)
                        )
                        .onTapGesture {
                            if !playlistViewModel.isSongInPlaylist(song) {
                                playlistViewModel.playSong(song)
                            }
                        }
                    }
                }
                .padding(.horizontal, 8)
            }
            .background(AppTheme.leftPanelListBackground)
        }
        .background(AppTheme.leftPanelBackground)
    }
}

// MARK: - Song List Item View
struct SongListItemView: View {
    let song: Song
    let isInPlaylist: Bool
    let isCurrentlyPlaying: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(AppTheme.leftPanelTextPrimary)
                    .lineLimit(1)
                
                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.leftPanelTextSecondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(song.formattedDuration)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.leftPanelTextSecondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppTheme.leftPanelBackground)
        .cornerRadius(8)
        .opacity(isInPlaylist ? 0.5 : 1.0)
    }
}

/*
struct SongListView: View {
    @StateObject private var viewModel = SongListViewModel() // Use your real-data loader!
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.leftPanelListBackground)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
                List {
                    ForEach(viewModel.songs) { song in
                        SongListItemView(song: song)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(AppTheme.leftPanelListBackground)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 8)
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SONG LIST")
                .font(.headline)
                .foregroundColor(AppTheme.leftPanelAccent)
            Spacer()
            Text("\(viewModel.songs.count) Songs")
                .font(.subheadline)
                .foregroundColor(AppTheme.leftPanelAccent)
        }
        .padding(.horizontal, panelGap)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
*/

/* import SwiftUI

struct SongListView: View {
    @StateObject private var viewModel = SonglistViewModel()
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            header
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.leftPanelListBackground)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
                List {
                    ForEach(viewModel.songs) { song in
                        SongListItemView(song: song)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(AppTheme.leftPanelListBackground)
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .padding(.vertical, 4)
            }
            // Here is the fix: add extra top padding to the ZStack
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 8) // <--- Increase this value until the tops align
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("SONG LIST")
                .font(.headline)
                .foregroundColor(AppTheme.leftPanelAccent)
            Spacer()
            Text("\(viewModel.songs.count) Songs")
                .font(.subheadline)
                .foregroundColor(AppTheme.leftPanelAccent)
        }
        .padding(.horizontal, panelGap)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
}
*/
