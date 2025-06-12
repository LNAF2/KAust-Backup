//
//  SonglistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SongListView: View {
    @StateObject private var viewModel = SongListViewModel()
    @ObservedObject var playlistViewModel: PlaylistViewModel
    @FocusState private var isSearchFocused: Bool
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            header
            searchSection
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.leftPanelListBackground)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.leftPanelListBackground, lineWidth: 1)
                
                VStack(spacing: 0) {
                    // Search suggestions
                    if viewModel.showingSuggestions {
                        searchSuggestionsView
                    }
                    
                    // Song list
                    songListView
                }
            }
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 0)
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
            Text("\(viewModel.displayCount) Songs")
                .font(.subheadline)
                .foregroundColor(AppTheme.leftPanelAccent)
        }
        .padding(.horizontal, panelGap)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
    
    private var searchSection: some View {
        VStack(spacing: 8) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                
                TextField("Try: artist name, song title, or \"artist song\"", text: $viewModel.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onSubmit {
                        isSearchFocused = false
                        viewModel.showingSuggestions = false
                    }
                    .onChange(of: viewModel.searchText) {
                        if !viewModel.searchText.isEmpty {
                            viewModel.showingSuggestions = true
                        }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                    }
                }
                
                if viewModel.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(AppTheme.leftPanelAccent.opacity(0.3), lineWidth: 1)
                    )
            )
            

        }
        .padding(.horizontal, panelGap)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }
    
    private var searchSuggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(viewModel.searchSuggestions.prefix(3)) { suggestion in
                Button(action: {
                    viewModel.selectSuggestion(suggestion)
                    isSearchFocused = false
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.5))
                            .font(.caption)
                        
                        Text(suggestion.text)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.leftPanelAccent)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.5))
                            .font(.caption)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                
                if suggestion.id != viewModel.searchSuggestions.prefix(3).last?.id {
                    Divider()
                        .background(AppTheme.leftPanelAccent.opacity(0.2))
                }
            }
        }
        .background(Color.white.opacity(0.9))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(AppTheme.leftPanelAccent.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
    
    private var songListView: some View {
        Group {
            if viewModel.displaySongs.isEmpty && !viewModel.searchText.isEmpty {
                // No search results
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.title)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.5))
                    
                    Text("No songs found")
                        .font(.headline)
                        .foregroundColor(AppTheme.leftPanelAccent)
                    
                    Text("Try a different search term")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    
                    Button("Clear Search") {
                        viewModel.clearSearch()
                    }
                    .foregroundColor(AppTheme.leftPanelAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppTheme.leftPanelListBackground)
            } else {
                List {
                    ForEach(viewModel.displaySongs) { song in
                        SongListItemView(song: song)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(AppTheme.leftPanelListBackground)
                            .onTapGesture {
                                playlistViewModel.addToPlaylist(song)
                                // Hide suggestions when song is selected
                                viewModel.showingSuggestions = false
                            }
                    }
                }
                .listStyle(PlainListStyle())
                .background(Color.clear)
                .padding(.vertical, 4)
            }
        }
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
