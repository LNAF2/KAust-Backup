import SwiftUI
import CoreData

// MARK: - Song List Display View

struct SongListDisplayView: View {
    @StateObject private var viewModel = SonglistViewModel()
    @State private var selectedSong: Song?
    @EnvironmentObject var userPreferences: UserPreferencesService
    @EnvironmentObject var focusManager: FocusManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and controls
            headerSection
            
            // Main content
            mainContent
        }
        .background(AppTheme.leftPanelBackground)
        .task {
            await viewModel.loadSongs()
        }
        .onAppear {
            Task {
                await viewModel.loadSongs()
            }
        }
        .refreshable {
            await viewModel.loadSongs()
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                // Error handling
            }
        } message: {
            Text(viewModel.error?.localizedDescription ?? "Unknown error")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    Task {
                        await viewModel.loadSongs()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(AppTheme.leftPanelAccent)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            // Title and stats
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SONG LIST")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.leftPanelAccent)
                    
                    if viewModel.displayCount > 0 {
                        Text("\(viewModel.displayCount) Songs")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // Refresh button
                    Button(action: { Task { await viewModel.loadSongs() } }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.leftPanelAccent)
                    }
                }
            }
            
            // Search bar
            SearchBarView(text: $viewModel.searchText)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        Group {
            if viewModel.displaySongs.isEmpty && viewModel.songs.isEmpty {
                EmptyLibraryView()
            } else if viewModel.displaySongs.isEmpty {
                NoResultsView(searchText: viewModel.searchText)
            } else {
                songList
            }
        }
    }
    
    // MARK: - Song List
    
    private var songList: some View {
        List(viewModel.displaySongs, id: \.id) { song in
            SongRowView(song: song)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .if(userPreferences.swipeToDeleteEnabled) { view in
                    view.swipeActions(edge: .trailing) {
                        Button("Delete", role: .destructive) {
                            Task {
                                await viewModel.deleteSong(song)
                            }
                        }
                    }
                }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .padding(.horizontal, 8)
    }
}

// MARK: - Search Bar View

private struct SearchBarView: View {
    @Binding var text: String
    @EnvironmentObject var focusManager: FocusManager
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
            
            TextField("Search songs...", text: $text)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .autocorrectionDisabled()
                .disableAutocorrection(true)
                .textInputAutocapitalization(.never)
                .keyboardType(.default)
                .submitLabel(.search)
                .onSubmit {
                    isSearchFocused = false
                    focusManager.clearFocus()
                }
                .onChange(of: isSearchFocused) { _, focused in
                    if !focused {
                        focusManager.clearFocus()
                    }
                }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(AppTheme.leftPanelListBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelAccent.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Song Row View

private struct SongRowView: View {
    let song: Song
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Artwork placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.leftPanelAccent.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(AppTheme.leftPanelAccent)
                    )
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.cleanTitle.uppercased())
                        .font(.headline)
                        .foregroundColor(AppTheme.leftPanelAccent)
                        .lineLimit(1)
                    
                    Text(song.cleanArtist.uppercased())
                        .font(.subheadline)
                        .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                        .lineLimit(1)
                    
                    HStack {
                        Text(song.duration.uppercased())
                            .font(.caption)
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Play icon (non-interactive for display)
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            
            // Divider
            Divider()
                .background(AppTheme.leftPanelAccent.opacity(0.2))
        }
        .background(Color.clear)
    }
}

// MARK: - Empty States

private struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.5))
            
            Text("No Songs Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.leftPanelAccent)
            
            Text("Import some MP4 files from the Settings menu to get started!")
                .font(.body)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.leftPanelBackground)
    }
}

private struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.5))
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.leftPanelAccent)
            
            if !searchText.isEmpty {
                Text("No songs found for '\(searchText)'")
                    .font(.body)
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    .multilineTextAlignment(.center)
            } else {
                Text("No songs match your current filters")
                    .font(.body)
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.leftPanelBackground)
    }
}

private struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Songs...")
                .font(.headline)
                .foregroundColor(AppTheme.leftPanelAccent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.leftPanelBackground)
    }
}

// MARK: - View Extensions

// Extension moved to ViewExtensions.swift