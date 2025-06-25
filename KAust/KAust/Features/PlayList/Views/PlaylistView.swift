//
//  PlaylistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistView.swift

import SwiftUI
import Combine
import CoreData

struct PlaylistView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @EnvironmentObject private var videoPlayerViewModel: VideoPlayerViewModel
    @State private var isEditing = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var swipeState: [String: CGFloat] = [:]
    // COMMENTED OUT: Drag and drop functionality 
    // @State private var draggedSongId: String? = nil
    var onSongSelected: ((Song) -> Void)? = nil

    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8
    private let swipeThreshold: CGFloat = -80

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if viewModel.playlistItems.isEmpty {
                    emptyPlaylistView
                } else {
                    ForEach(viewModel.playlistItems) { song in
                        PlaylistItemView(song: song)
                            .onTapGesture {
                                print("👆 Tapped song in playlist: \(song.title)")
                                viewModel.playSong(song)
                            }
                            .opacity(viewModel.isSongCurrentlyPlaying(song) ? 0.5 : 1.0)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .background(AppTheme.rightPanelBackground)
        .onAppear {
            print("📱 PlaylistView appeared - \(viewModel.playlistItems.count) songs")
        }
    }
    
    private var emptyPlaylistView: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundColor(AppTheme.rightPanelAccent)
            Text("No songs in playlist")
                .font(.headline)
                .foregroundColor(AppTheme.rightPanelTextPrimary)
            Text("Add songs from the song list")
                .font(.subheadline)
                .foregroundColor(AppTheme.rightPanelTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
    
    private var playlistContent: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppTheme.rightPanelListBackground)
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.rightPanelListBackground, lineWidth: 1)
            
            scrollableContent
        }
        .padding(.horizontal, panelGap)
        .padding(.bottom, panelGap)
        .padding(.top, 0)
    }
    
    private var scrollableContent: some View {
        VStack {
            if viewModel.playlistItems.isEmpty {
                // Empty state - show PlaylistEmptyState
                PlaylistEmptyState()
            } else {
                // Show playlist content
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.playlistItems) { song in
                                playlistItemRow(for: song)
                            }
                        }
                    }
                    .background(Color.clear)
                    .padding(.vertical, 4)
                    .onReceive(viewModel.scrollToBottomPublisher) { _ in
                        // Scroll to the last item with animation
                        if let lastSong = viewModel.playlistItems.last {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                proxy.scrollTo(lastSong.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func playlistItemRow(for song: Song) -> some View {
        ZStack {
            // Delete button revealed when swiping
            if isEditing {
                HStack {
                    Spacer()
                    Button(action: {
                        deleteSong(song)
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
            
            // Main playlist item with edit mode overlays
            HStack(spacing: 0) {
                // COMMENTED OUT: Drag handle on the left when editing
                /*
                if isEditing {
                    DragHandleView(
                        song: song, 
                        viewModel: viewModel, 
                        draggedSongId: $draggedSongId
                    ) {
                        resetSwipe(for: song.id)
                    }
                    .frame(width: 30)
                }
                */
                
                // Song content
                PlaylistItemView(song: song)
                    .opacity(videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0)
                    .offset(x: swipeState[song.id] ?? 0)
                    // COMMENTED OUT: Drag-related visual effects
                    // .scaleEffect(draggedSongId == song.id ? 1.05 : 1.0)
                    // .opacity(draggedSongId == song.id ? 0.8 : (videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0))
                    // .shadow(
                    //     color: draggedSongId == song.id ? AppTheme.rightPanelAccent.opacity(0.3) : .clear,
                    //     radius: draggedSongId == song.id ? 8 : 0,
                    //     x: 0,
                    //     y: draggedSongId == song.id ? 4 : 0
                    // )
                    // .animation(.easeInOut(duration: 0.2), value: draggedSongId)
                    .contentShape(Rectangle()) // Ensure the entire area is tappable
                    .onTapGesture {
                    if abs(swipeState[song.id] ?? 0) > 10 {
                        // Reset swipe if item was swiped
                        resetSwipe(for: song.id)
                    } else if isEditing {
                        // In edit mode, tapping does nothing (show feedback)
                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                        impactFeedback.impactOccurred()
                    } else {
                        // Only allow song selection when not in edit mode
                        handleSongTap(song)
                    }
                }
                    .simultaneousGesture(
                        isEditing ? 
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
                
                // Visible delete button on the right when editing
                if isEditing {
                    Button(action: {
                        deleteSong(song)
                        resetSwipe(for: song.id)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 20))
                    }
                    .frame(width: 30)
                    .buttonStyle(.plain)
                }
            }
            .id(song.id)
            // COMMENTED OUT: Drop delegate for drag and drop reordering
            /*
            .if(isEditing) { view in
                view.onDrop(of: [.text], delegate: PlaylistDropDelegate(
                            item: song,
                            listData: $viewModel.playlistItems,
                            current: $viewModel.draggedItem,
                            draggedSongId: $draggedSongId
                        ))
            }
            */
        }
        .clipped()
    }
    

    
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
    
    private func handleSongTap(_ song: Song) {
        print("\n🎵 DEBUG: Song tapped in playlist")
        print("  - Song: '\(song.cleanTitle)' by '\(song.cleanArtist)'")
        print("  - File: \(song.filePath)")
        
        if videoPlayerViewModel.currentVideo != nil {
            print("🚫 DEBUG: Video currently playing, ignoring tap")
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            return
        }
        
        // Use advanced file resolution like VideoPlayerViewModel
        Task {
            let resolvedURL = await findVideoURL(for: song)
            
            guard let url = resolvedURL else {
                print("❌ DEBUG: Could not resolve file location for: \(song.cleanTitle)")
                
                // Remove the song from the playlist since it can't be played
                if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                    await viewModel.removeSong(at: index)
                }
                
                print("❌ Cannot play '\(song.cleanTitle)' - MP4 file is missing")
                return
            }
            
            print("✅ DEBUG: File resolved at: \(url.path)")
            
            // If we found the file at a different location, update the song object for this session
            var updatedSong = song
            if url.path != song.filePath {
                print("📝 DEBUG: File path changed from \(song.filePath) to \(url.path)")
                updatedSong = Song(
                    id: song.id,
                    title: song.title,
                    artist: song.artist,
                    duration: song.duration,
                    filePath: url.path
                )
                
                // Update the database with the new path
                await updateSongFilePath(songId: song.id, newPath: url.path)
            }
            
            await MainActor.run {
                print("✅ DEBUG: Starting playback with resolved file")
                onSongSelected?(updatedSong)
            }
        }
    }
    
    private func deleteSong(_ song: Song) {
        Task {
            if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                await viewModel.removeSong(at: index)
            }
        }
    }
    
    // MARK: - File Resolution Methods
    
    private func findVideoURL(for song: Song) async -> URL? {
        // CRITICAL: For external folder files, restore security access before attempting playback
        await restoreSecurityAccessIfNeeded(for: song)
        
        if let url = song.videoURL, FileManager.default.fileExists(atPath: url.path) {
            print("📁 PlaylistView.find - Found video at original path: \(url.path)")
            return url
        } else {
            print("⚠️ PlaylistView.find - Video not at original path. Attempting migration/search...")
            return await attemptFileMigration(for: song)
        }
    }
    
    /// Restore security-scoped access to external folders when needed for playback
    private func restoreSecurityAccessIfNeeded(for song: Song) async {
        // Check if this song is from an external folder (not in our Documents/Media directory)
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        
        // If the file path is NOT in our media directory, it's likely from external folder access
        if !song.filePath.hasPrefix(mediaDirectory.path) {
            print("🔐 Playlist: Video file appears to be from external folder: \(song.filePath)")
            
            // Try to restore security access to the parent folder
            let folderPath = URL(fileURLWithPath: song.filePath).deletingLastPathComponent()
            await restoreSecurityAccessToFolder(folderPath)
        }
    }
    
    /// Restore security-scoped access to a specific folder using saved bookmarks
    private func restoreSecurityAccessToFolder(_ folderURL: URL) async {
        print("🔍 Playlist: Attempting to restore security access to: \(folderURL.path)")
        
        // Look for saved bookmarks in UserDefaults
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix("mp4FolderBookmark") {
                if let bookmarkData = userDefaults.data(forKey: key) {
                    do {
                        var isStale = false
                        let bookmarkedURL = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withoutUI,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )
                        
                        // Check if this bookmark matches the folder we need
                        if bookmarkedURL.path == folderURL.path || folderURL.path.hasPrefix(bookmarkedURL.path) {
                            if bookmarkedURL.startAccessingSecurityScopedResource() {
                                print("✅ Playlist: Successfully restored security access to: \(bookmarkedURL.path)")
                                
                                // Store reference for cleanup later (optional)
                                // Note: We intentionally don't call stopAccessingSecurityScopedResource() 
                                // immediately as we want to maintain access for playback
                                return
                            } else {
                                print("❌ Playlist: Failed to restore security access to bookmark: \(bookmarkedURL.path)")
                            }
                        }
                    } catch {
                        print("❌ Playlist: Failed to resolve bookmark \(key): \(error)")
                    }
                }
            }
        }
        
        print("⚠️ Playlist: No valid bookmark found for folder: \(folderURL.path)")
    }
    
    private func attemptFileMigration(for song: Song) async -> URL? {
        let fileName = URL(fileURLWithPath: song.filePath).lastPathComponent
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        
        // Primary search locations - check Media directory first
        let searchDirectories = [
            mediaDirectory, // Check our permanent storage first
            documentsDirectory,
            documentsDirectory.appendingPathComponent("Inbox"),
            documentsDirectory.appendingPathComponent("tmp"),
            FileManager.default.temporaryDirectory,
            FileManager.default.temporaryDirectory.appendingPathComponent("com.erlingbreaden.KAust-Inbox")
        ]
        
        print("🔍 PlaylistView: Searching for file: \(fileName)")
        
        for dir in searchDirectories {
            let potentialPath = dir.appendingPathComponent(fileName)
            print("🔍 Checking: \(potentialPath.path)")
            
            if FileManager.default.fileExists(atPath: potentialPath.path) {
                print("🎯 Found match at: \(potentialPath.path)")
                
                // If file is already in Media directory, use it directly
                if potentialPath.path.contains("/Media/") {
                    print("✅ File already in permanent storage: \(potentialPath.path)")
                    return potentialPath
                }
                
                // Otherwise, move it to Media directory
                let destinationURL = mediaDirectory.appendingPathComponent(fileName)
                
                do {
                    try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
                    
                    // If a file already exists at the destination, it might be the correct one
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                       print("✅ File already exists at destination, using it. No move needed.")
                       return destinationURL
                    }
                    
                    // Move file to permanent storage
                    try FileManager.default.moveItem(at: potentialPath, to: destinationURL)
                    print("✅ Successfully moved file to permanent storage: \(destinationURL.path)")
                    return destinationURL
                } catch {
                    print("❌ Failed to move file from \(potentialPath.path) to \(destinationURL.path): \(error)")
                    // If move fails, maybe we can still play from the found location
                    return potentialPath
                }
            }
        }
        
        print("❌ File '\(fileName)' not found in any standard location.")
        return nil
    }
    
    private func updateSongFilePath(songId: String, newPath: String) async {
        print("🗄️ PlaylistView - Updating database file path for song: \(songId)")
        let context = PersistenceController.shared.container.viewContext
        
        guard let uuid = UUID(uuidString: songId) else {
             print("❌ Invalid UUID string: \(songId)")
             return
        }
        
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let songs = try context.fetch(request)
            if let songEntity = songs.first {
                songEntity.filePath = newPath
                if context.hasChanges {
                    try context.save()
                    print("✅ Updated song file path in database: \(newPath)")
                }
            } else {
                print("❌ Song not found in database for UUID: \(songId)")
            }
        } catch {
            print("❌ Failed to update song file path: \(error)")
        }
    }

    private var playlistHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAY LIST")
                    .font(.headline)
                    .foregroundColor(AppTheme.rightPanelAccent)
                    .contentShape(Rectangle()) // Make entire text area tappable
                    .onTapGesture {
                        // Center video when playlist header is tapped and video is playing
                        if videoPlayerViewModel.currentVideo != nil && videoPlayerViewModel.isMinimized {
                            print("🎯 PLAYLIST TAP: Centering off-screen video")
                            
                            // Provide haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Center the video
                            videoPlayerViewModel.centerVideo()
                        }
                    }
                
                // Show status when video is playing or in edit mode
                if videoPlayerViewModel.currentVideo != nil {
                    if videoPlayerViewModel.isMinimized {
                        Text("Tap ↑ to center video if off-screen")
                            .font(.caption)
                            .foregroundColor(AppTheme.rightPanelAccent.opacity(0.7))
                    } else {
                        Text("Selection disabled while video playing")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                } else if isEditing {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Song selection disabled in edit mode")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Tap ⊖ to delete • Swipe left for quick delete")
                            .font(.caption)
                            .foregroundColor(AppTheme.rightPanelAccent.opacity(0.7))
                    }
                }
            }
            
            Spacer()
            Button(action: { 
                isEditing.toggle()
                if !isEditing {
                    resetAllSwipes()
                    // COMMENTED OUT: Clear drag feedback when exiting edit mode
                    // draggedSongId = nil
                }
            }) {
                Text(isEditing ? "DONE" : "EDIT")
                    .font(.body)
                    .foregroundColor(isEditing ? .green : AppTheme.rightPanelAccent)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isEditing ? Color.green.opacity(0.15) : AppTheme.rightPanelListBackground)
                    )
            }
            .buttonStyle(.plain)
            Text("\(viewModel.playlistItems.count) Songs")
                .font(.subheadline)
                .foregroundColor(AppTheme.rightPanelAccent)
        }
        .padding(.horizontal, panelGap)
        .padding(.vertical, 8)
    }
}

// MARK: - COMMENTED OUT: Drag Handle Component
/*
struct DragHandleView: View {
    let song: Song
    let viewModel: PlaylistViewModel
    @Binding var draggedSongId: String?
    let onDragStart: () -> Void
    
    var body: some View {
        Image(systemName: "line.3.horizontal")
            .foregroundColor(AppTheme.rightPanelAccent.opacity(0.6))
            .font(.system(size: 16, weight: .medium))
            .contentShape(Rectangle())
            .onDrag {
                onDragStart()
                viewModel.draggedItem = song
                draggedSongId = song.id // Set visual feedback
                return NSItemProvider(object: song.id as NSString)
            }
    }
}
*/

// MARK: - COMMENTED OUT: Drag and Drop Support
/*
struct PlaylistDropDelegate: DropDelegate {
    let item: Song
    @Binding var listData: [Song]
    @Binding var current: Song?
    @Binding var draggedSongId: String?

    func dropEntered(info: DropInfo) {
        if item != current {
            let from = listData.firstIndex(of: current!)!
            let to = listData.firstIndex(of: item)!
            if listData[to] != current {
                listData.move(fromOffsets: IndexSet(integer: from),
                            toOffset: to > from ? to + 1 : to)
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        current = nil
        draggedSongId = nil // Clear visual feedback
        return true
    }
}
*/
