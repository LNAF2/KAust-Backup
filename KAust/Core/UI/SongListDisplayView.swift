import SwiftUI
import CoreData

// MARK: - Song List Display View

/// Main view for displaying songs from Core Data with fuzzy search
struct SongListDisplayView: View {
    @StateObject private var viewModel = SonglistViewModel()
    @State private var selectedSong: Song?
    @AppStorage("swipeToDeleteEnabled") private var swipeToDeleteEnabled = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with search and controls
            headerSection
            
            // Main content
            mainContent
        }
        .background(AppTheme.appBackground)
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
                        .foregroundColor(.blue)
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
                    Text("Song Library")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.primaryText)
                    
                    if viewModel.displayCount > 0 {
                        Text("\(viewModel.displayCount) songs")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // Refresh button
                    Button(action: { Task { await viewModel.loadSongs() } }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            
            // Search bar
            SearchBarView(text: $viewModel.searchText)
        }
        .padding(.horizontal, AppConstants.Layout.defaultPadding)
        .padding(.top, AppConstants.Layout.defaultPadding)
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
            .if(swipeToDeleteEnabled) { view in
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
        .padding(.horizontal, AppConstants.Layout.defaultPadding)
    }
    

}

// MARK: - Search Bar View

struct SearchBarView: View {
    @Binding var text: String
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppTheme.secondaryText)
            
            TextField("Search songs...", text: $text)
                .textFieldStyle(.plain)
                .focused($isSearchFocused)
                .onSubmit {
                    isSearchFocused = false
                }
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppTheme.secondaryText)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                .fill(AppTheme.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                        .stroke(AppTheme.borderColor, lineWidth: 1)
                )
        )
    }
}

// MARK: - Song Row View

struct SongRowView: View {
    let song: Song
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Artwork placeholder
                RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                    .fill(AppTheme.accent.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.title2)
                            .foregroundColor(AppTheme.accent)
                    )
                
                // Song info
                VStack(alignment: .leading, spacing: 4) {
                    Text(song.cleanTitle)
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                    
                    Text(song.cleanArtist)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text(song.duration)
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Play icon (non-interactive for display)
                Image(systemName: "play.circle.fill")
                    .font(.title)
                    .foregroundColor(AppTheme.accent.opacity(0.6))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            
            // Divider
            Divider()
                .background(AppTheme.borderColor)
        }
        .background(Color.clear)
    }
}



// MARK: - Empty States

struct EmptyLibraryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondaryText)
            
            Text("No Songs Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)
            
            Text("Import some MP4 files from the Settings menu to get started!")
                .font(.body)
                .foregroundColor(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
    }
}

struct NoResultsView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(AppTheme.secondaryText)
            
            Text("No Results")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.primaryText)
            
            if !searchText.isEmpty {
                Text("No songs found for '\(searchText)'")
                    .font(.body)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            } else {
                Text("No songs match your current filters")
                    .font(.body)
                    .foregroundColor(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading Songs...")
                .font(.headline)
                .foregroundColor(AppTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
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