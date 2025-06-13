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
    @AppStorage("swipeToDeleteEnabled") private var swipeToDeleteEnabled = false
    @State private var swipeState: [String: CGFloat] = [:]
    @State private var songToDelete: Song?
    @State private var showDeleteConfirmation = false
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8
    private let swipeThreshold: CGFloat = -80

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
        .alert("Delete Song", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {
                songToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let song = songToDelete {
                    deleteSong(song)
                }
                songToDelete = nil
            }
        } message: {
            if let song = songToDelete {
                Text(deletionMessage(for: song))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text("SONG LIST")
                    .font(.headline)
                    .foregroundColor(AppTheme.leftPanelAccent)
                Spacer()
                Text("\(viewModel.displayCount) Songs")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.leftPanelAccent)
            }
            
            // Show swipe-to-delete status
            if swipeToDeleteEnabled {
                Text("Swipe left to delete songs")
                    .font(.caption)
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
            }
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
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.default)
                    .onSubmit {
                        isSearchFocused = false
                        viewModel.showingSuggestions = false
                    }
                    .onChange(of: viewModel.searchText) {
                        if !viewModel.searchText.isEmpty {
                            viewModel.showingSuggestions = true
                        }
                        // Reset all swipe states when search changes
                        resetAllSwipes()
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
                .background(Color.clear)
            } else {
                // Replace List with ScrollView to fix background issues
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.displaySongs) { song in
                            songListItemRow(for: song)
                        }
                    }
                }
                .background(Color.clear)
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Song List Item Row
    
    @ViewBuilder
    private func songListItemRow(for song: Song) -> some View {
        ZStack {
            // Delete button revealed when swiping (only if swipe-to-delete is enabled)
            if swipeToDeleteEnabled {
                HStack {
                    Spacer()
                    Button(action: {
                        showDeleteConfirmation(for: song)
                        resetSwipe(for: song.id)
                    }) {
                        Image(systemName: "trash.fill")
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.red)
                            .cornerRadius(8)
                    }
                    .frame(width: 60)
                }
                .padding(.trailing, 8)
                .opacity(abs(swipeState[song.id] ?? 0) > 20 ? 1 : 0)
            }
            
            // Main song item
            SongListItemView(song: song)
                .offset(x: swipeState[song.id] ?? 0)
                .contentShape(Rectangle())
                .onTapGesture {
                    if abs(swipeState[song.id] ?? 0) > 10 {
                        // Reset swipe if item was swiped
                        resetSwipe(for: song.id)
                    } else {
                        // Add to playlist and hide suggestions
                        playlistViewModel.addToPlaylist(song)
                        viewModel.showingSuggestions = false
                    }
                }
                .simultaneousGesture(
                    swipeToDeleteEnabled ? 
                    DragGesture()
                        .onChanged { value in
                            // Only allow left swipe (negative translation)
                            let translation = min(0, value.translation.width)
                            swipeState[song.id] = translation
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            let velocity = value.velocity.width
                            
                            if translation < swipeThreshold || velocity < -500 {
                                // Snap to delete position
                                withAnimation(.spring()) {
                                    swipeState[song.id] = swipeThreshold
                                }
                            } else {
                                // Snap back to original position
                                resetSwipe(for: song.id)
                            }
                        } : nil
                )
        }
        .clipped()
    }
    
    // MARK: - Helper Functions
    
    private func resetSwipe(for songId: String) {
        withAnimation(.spring()) {
            swipeState[songId] = 0
        }
    }
    
    private func resetAllSwipes() {
        withAnimation(.spring()) {
            swipeState.removeAll()
        }
    }
    
    private func showDeleteConfirmation(for song: Song) {
        songToDelete = song
        showDeleteConfirmation = true
    }
    
    private func deleteSong(_ song: Song) {
        Task {
            await viewModel.deleteSong(song)
        }
    }
    
    private func deletionMessage(for song: Song) -> String {
        let fileManager = FileManager.default
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        let mediaPath = mediaDirectory.path
        
        // Check if this is an internal file (in app's Media directory) or external (bookmarked)
        if song.filePath.hasPrefix(mediaPath) {
            return """
            This will permanently delete both the song metadata and the MP4 file from your device.
            
            Song: "\(song.cleanTitle)" by \(song.cleanArtist)
            
            This action cannot be undone.
            """
        } else {
            return """
            This will remove the song from your library but keep the original file in its location.
            
            Song: "\(song.cleanTitle)" by \(song.cleanArtist)
            
            Only the song metadata will be deleted.
            """
        }
    }
}

// MARK: - View Extensions

extension View {
    /// Conditionally applies a view modifier
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
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
