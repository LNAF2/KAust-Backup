import SwiftUI
import CoreData

// MARK: - Song List Display View

/// Main view for displaying songs from Core Data with search and filtering
struct SongListDisplayView: View {
    @StateObject private var viewModel = SongListViewModel()
    @State private var showingFilterSheet = false
    @State private var showingSortSheet = false
    @State private var selectedSong: SongEntity?
    
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
                await viewModel.refresh()
            }
        }
        .refreshable {
            await viewModel.refresh()
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterSheet(viewModel: viewModel)
        }
        .actionSheet(isPresented: $showingSortSheet) {
            sortActionSheet
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
                        await viewModel.refresh()
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
                    
                    if viewModel.totalSongCount > 0 {
                        Text("\(viewModel.songCount) of \(viewModel.totalSongCount) songs")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    // Filter button
                    Button(action: { showingFilterSheet.toggle() }) {
                        Image(systemName: hasActiveFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .font(.title2)
                            .foregroundColor(hasActiveFilters ? AppTheme.accent : AppTheme.secondaryText)
                    }
                    
                    // Sort button
                    Button(action: { showingSortSheet.toggle() }) {
                        Image(systemName: "arrow.up.arrow.down.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                    
                    // Refresh button
                    Button(action: { Task { await viewModel.refresh() } }) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.title2)
                            .foregroundColor(AppTheme.secondaryText)
                    }
                }
            }
            
            // Search bar
            SearchBarView(text: $viewModel.searchText)
            
            // Active filters
            if hasActiveFilters {
                ActiveFiltersView(viewModel: viewModel)
            }
        }
        .padding(.horizontal, AppConstants.Layout.defaultPadding)
        .padding(.top, AppConstants.Layout.defaultPadding)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if viewModel.isEmpty && viewModel.totalSongCount == 0 {
                EmptyLibraryView()
            } else if viewModel.isEmpty {
                NoResultsView(searchText: viewModel.searchText)
            } else {
                songList
            }
        }
    }
    
    // MARK: - Song List
    
    private var songList: some View {
        List(viewModel.filteredSongs, id: \.id) { song in
            SongRowView(song: song) {
                Task {
                    await viewModel.playedSong(song)
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .swipeActions(edge: .trailing) {
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteSong(song)
                    }
                }
            }
        }
        .listStyle(.plain)
        .background(Color.clear)
        .padding(.horizontal, AppConstants.Layout.defaultPadding)
    }
    
    // MARK: - Computed Properties
    
    private var hasActiveFilters: Bool {
        !viewModel.searchText.isEmpty ||
        !viewModel.selectedGenres.isEmpty ||
        viewModel.selectedLanguage != nil ||
        viewModel.selectedEvent != nil
    }
    
    private var sortActionSheet: ActionSheet {
        ActionSheet(
            title: Text("Sort Songs"),
            buttons: SortOption.allCases.map { option in
                .default(Text(option.rawValue)) {
                    viewModel.sortOption = option
                }
            } + [.cancel()]
        )
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
    let song: SongEntity
    let onPlay: () -> Void
    
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
                    Text(song.title ?? "Unknown Title")
                        .font(.headline)
                        .foregroundColor(AppTheme.primaryText)
                        .lineLimit(1)
                    
                    Text(song.artist ?? "Unknown Artist")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.secondaryText)
                        .lineLimit(1)
                    
                    HStack {
                        Text(song.formattedDuration)
                            .font(.caption)
                            .foregroundColor(AppTheme.secondaryText)
                        
                        if !song.genreNames.isEmpty {
                            Text("•")
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Text(song.genreNames.first ?? "")
                                .font(.caption)
                                .foregroundColor(AppTheme.accent)
                        }
                        
                        if song.playCount > 0 {
                            Text("•")
                                .foregroundColor(AppTheme.secondaryText)
                            
                            Text("Played \(song.playCount) times")
                                .font(.caption)
                                .foregroundColor(AppTheme.secondaryText)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
                
                // Play button
                Button(action: onPlay) {
                    Image(systemName: "play.circle.fill")
                        .font(.title)
                        .foregroundColor(AppTheme.accent)
                }
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

// MARK: - Active Filters View

struct ActiveFiltersView: View {
    @ObservedObject var viewModel: SongListViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Clear all filters
                Button("Clear All") {
                    viewModel.clearFilters()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppTheme.accent)
                .foregroundColor(.white)
                .font(.caption)
                .cornerRadius(AppConstants.UI.cornerRadius)
                
                // Genre filters
                ForEach(Array(viewModel.selectedGenres), id: \.self) { genre in
                    Button(action: { viewModel.removeGenreFilter(genre) }) {
                        HStack(spacing: 4) {
                            Text(genre)
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackground)
                    .foregroundColor(AppTheme.primaryText)
                    .font(.caption)
                    .cornerRadius(AppConstants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                            .stroke(AppTheme.borderColor, lineWidth: 1)
                    )
                }
                
                // Language filter
                if let language = viewModel.selectedLanguage {
                    Button(action: { viewModel.selectedLanguage = nil }) {
                        HStack(spacing: 4) {
                            Text("Language: \(language)")
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackground)
                    .foregroundColor(AppTheme.primaryText)
                    .font(.caption)
                    .cornerRadius(AppConstants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                            .stroke(AppTheme.borderColor, lineWidth: 1)
                    )
                }
                
                // Event filter
                if let event = viewModel.selectedEvent {
                    Button(action: { viewModel.selectedEvent = nil }) {
                        HStack(spacing: 4) {
                            Text("Event: \(event)")
                            Image(systemName: "xmark")
                                .font(.caption2)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(AppTheme.cardBackground)
                    .foregroundColor(AppTheme.primaryText)
                    .font(.caption)
                    .cornerRadius(AppConstants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.UI.cornerRadius)
                            .stroke(AppTheme.borderColor, lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal, AppConstants.Layout.defaultPadding)
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @ObservedObject var viewModel: SongListViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                // Genres section
                if !viewModel.availableGenres.isEmpty {
                    Section("Genres") {
                        ForEach(viewModel.availableGenres, id: \.id) { genre in
                            HStack {
                                Text(genre.name ?? "Unknown")
                                Spacer()
                                if viewModel.selectedGenres.contains(genre.name ?? "") {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.toggleGenreFilter(genre.name ?? "")
                            }
                        }
                    }
                }
                
                // Languages section
                if !viewModel.availableLanguages.isEmpty {
                    Section("Languages") {
                        ForEach(viewModel.availableLanguages, id: \.self) { language in
                            HStack {
                                Text(language)
                                Spacer()
                                if viewModel.selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedLanguage = viewModel.selectedLanguage == language ? nil : language
                            }
                        }
                    }
                }
                
                // Events section
                if !viewModel.availableEvents.isEmpty {
                    Section("Events") {
                        ForEach(viewModel.availableEvents, id: \.self) { event in
                            HStack {
                                Text(event)
                                Spacer()
                                if viewModel.selectedEvent == event {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(AppTheme.accent)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                viewModel.selectedEvent = viewModel.selectedEvent == event ? nil : event
                            }
                        }
                    }
                }
            }
            .navigationTitle("Filter Songs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
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