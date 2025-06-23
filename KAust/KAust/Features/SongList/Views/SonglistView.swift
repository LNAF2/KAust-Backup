//
//  SonglistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SongListView: View {
    @StateObject private var viewModel = SonglistViewModel()
    @ObservedObject var playlistViewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    @EnvironmentObject var focusManager: FocusManager
    @EnvironmentObject var userPreferences: UserPreferencesService
    @FocusState private var isSearchFocused: Bool
    @State private var songToDelete: Song?
    @State private var showDeleteConfirmation = false
    @State private var isLoading = false
    
    // MARK: - Scroll Performance State
    @State private var isScrolling = false
    @State private var scrollPosition: CGFloat = 0
    @State private var lastScrollTime = Date()
    
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        Rectangle()
            .fill(Color.white)
            .frame(maxWidth: .infinity)
            .overlay(
                Rectangle()
                    .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
            )
            .overlay(
                VStack(spacing: 0) {
                    header
                    searchSection
                    ZStack {
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(AppTheme.leftPanelListBackground)
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.leftPanelListBackground, lineWidth: 1)
                        VStack(spacing: 0) {
                            if viewModel.showingSuggestions {
                                searchSuggestionsView
                            }
                            optimizedSongListView
                        }
                    }
                    .padding(.horizontal, panelGap)
                    .padding(.bottom, panelGap)
                    .padding(.top, 0)
                }
            )
            .alert("Delete Song?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) {
                    print("🚫 DEBUG: Delete cancelled")
                    print("  - Song: \(songToDelete?.cleanTitle ?? "nil")")
                    songToDelete = nil
                    showDeleteConfirmation = false
                }
                Button("Delete", role: .destructive) {
                    print("🗑️ DEBUG: Delete confirmed")
                    if let song = songToDelete {
                        print("  - Song: '\(song.cleanTitle)' by '\(song.cleanArtist)'")
                        print("  - ID: \(song.id)")
                        print("  - File: \(song.filePath)")
                        Task {
                            print("📝 DEBUG: Starting deletion task")
                            isLoading = true
                            await viewModel.deleteSong(song)
                            print("🔄 DEBUG: Reloading songs")
                            await viewModel.loadSongs()
                            isLoading = false
                            print("✅ DEBUG: Deletion task complete")
                        }
                    } else {
                        print("⚠️ DEBUG: songToDelete is nil when delete was confirmed!")
                    }
                    songToDelete = nil
                    showDeleteConfirmation = false
                }
            } message: {
                if let song = songToDelete {
                    Text(deletionMessage(for: song))
                }
            }
            .overlay {
                if isLoading {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .onAppear {
                print("👁️ DEBUG: SongListView appeared")
                print("  - Swipe to delete enabled: \(userPreferences.swipeToDeleteEnabled)")
                print("  - Number of songs: \(viewModel.displaySongs.count)")
                
                // Enable scroll performance mode
                enableScrollPerformanceMode()
                
                // Use only native SwiftUI focus - no competing FocusManager
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isSearchFocused = true
                }
            }
            .onDisappear {
                // Simple focus dismissal - no competing systems
                isSearchFocused = false
                
                // Disable scroll performance mode
                disableScrollPerformanceMode()
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
            if userPreferences.swipeToDeleteEnabled {
                Text("Swipe left on songs to delete")
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
                    .disableAutocorrection(true)
                    .keyboardType(.default)
                    .submitLabel(.search)
                    .onSubmit {
                        viewModel.showingSuggestions = false
                        isSearchFocused = false
                    }
                    .onChange(of: viewModel.searchText) {
                        if !viewModel.searchText.isEmpty {
                            viewModel.showingSuggestions = true
                        }
                    }
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.clearSearch()
                        isSearchFocused = true
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
    
    // MARK: - OPTIMIZED SCROLL VIEW FOR MAXIMUM PERFORMANCE
    
    private var optimizedSongListView: some View {
        Group {
            if viewModel.displaySongs.isEmpty && viewModel.searchText.isEmpty {
                // No songs at all - show empty state
                SonglistEmptyState()
            } else if viewModel.displaySongs.isEmpty && !viewModel.searchText.isEmpty {
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
                        // Maintain focus on search bar after clearing
                        isSearchFocused = true
                    }
                    .foregroundColor(AppTheme.leftPanelAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
            } else {
                // OPTIMIZED SCROLL VIEW - Maximum performance - FIXED: Now in correct branch with songs
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.displaySongs) { song in
                                optimizedSongRow(for: song)
                                    .id(song.id)
                            }
                        }
                        .background(
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        scrollPosition = geometry.frame(in: .global).minY
                                    }
                                    .onChange(of: geometry.frame(in: .global).minY) { _, newValue in
                                        // ULTRA-FAST scroll tracking
                                        let now = Date()
                                        if now.timeIntervalSince(lastScrollTime) > 0.016 { // 60 FPS throttle
                                            scrollPosition = newValue
                                            lastScrollTime = now
                                            
                                            // Enter/exit scroll performance mode based on movement
                                            let scrollSpeed = abs(newValue - scrollPosition)
                                            if scrollSpeed > 10 && !isScrolling {
                                                startScrollOptimization()
                                            } else if scrollSpeed < 1 && isScrolling {
                                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                    if !isScrolling { return }
                                                    stopScrollOptimization()
                                                }
                                            }
                                        }
                                    }
                            }
                        )
                    }
                    .scrollDisabled(false)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                }
            }
        }
    }
    
    // MARK: - OPTIMIZED SONG ROW - Minimal overhead
    
    @ViewBuilder
    private func optimizedSongRow(for song: Song) -> some View {
        SongListItemView(
            song: song, 
            isInPlaylist: playlistViewModel.playlistItems.contains { $0.id == song.id },
            isCurrentlyPlaying: videoPlayerViewModel.currentVideo?.id == song.id
        )
        .contentShape(Rectangle())
        .background(Color.clear) // Explicit clear background for performance
        .onTapGesture {
            // INSTANT feedback - no print statements during scroll
            if isInPlaylist(song) {
                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                impactFeedback.impactOccurred()
            } else {
                playlistViewModel.addToPlaylist(song)
                viewModel.showingSuggestions = false
            }
        }
        .if(userPreferences.swipeToDeleteEnabled) { view in
            view.swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    songToDelete = song
                    showDeleteConfirmation = true
                }
            }
        }
    }
    
    // MARK: - SCROLL PERFORMANCE OPTIMIZATION
    
    private func enableScrollPerformanceMode() {
        print("🚀 SCROLL: Enabling scroll performance mode")
        
        // Reduce search debounce for responsive search during scroll
        viewModel.setScrollOptimizedSearchDelay()
        
        // Notify other systems to reduce CPU usage
        NotificationCenter.default.post(name: .init("ScrollOptimizationEnabled"), object: nil)
    }
    
    private func disableScrollPerformanceMode() {
        print("🔄 SCROLL: Disabling scroll performance mode")
        
        // Restore normal search debounce
        viewModel.restoreNormalSearchDelay()
        
        // Notify other systems to restore normal operation
        NotificationCenter.default.post(name: .init("ScrollOptimizationDisabled"), object: nil)
    }
    
    private func startScrollOptimization() {
        guard !isScrolling else { return }
        
        print("⚡ SCROLL: Starting scroll optimization")
        isScrolling = true
        
        // Suspend non-essential operations during active scrolling
        NotificationCenter.default.post(name: .init("ActiveScrollingStarted"), object: nil)
    }
    
    private func stopScrollOptimization() {
        guard isScrolling else { return }
        
        print("✅ SCROLL: Stopping scroll optimization")
        isScrolling = false
        
        // Restore normal operations
        NotificationCenter.default.post(name: .init("ActiveScrollingStopped"), object: nil)
    }
    
    // MARK: - Helper Functions
    
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
    
    private func isInPlaylist(_ song: Song) -> Bool {
        // Check if song is in the playlist OR currently playing
        let inPlaylist = playlistViewModel.playlistItems.contains { $0.id == song.id }
        let isCurrentlyPlaying = videoPlayerViewModel.currentVideo?.id == song.id
        
        return inPlaylist || isCurrentlyPlaying
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
