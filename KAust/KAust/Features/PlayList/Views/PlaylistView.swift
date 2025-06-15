//
//  PlaylistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistView.swift

import SwiftUI
import Combine

struct PlaylistView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    @State private var isEditing = false
    @State private var cancellables = Set<AnyCancellable>()
    @State private var swipeState: [String: CGFloat] = [:]
    @State private var draggedSongId: String? = nil
    var onSongSelected: ((Song) -> Void)? = nil

    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8
    private let swipeThreshold: CGFloat = -80

    var body: some View {
        VStack(spacing: 0) {
            playlistHeader
            playlistContent
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
        )
        .alert("Error", isPresented: $viewModel.isShowingError) {
            Button("OK") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage)
        }
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
            .onReceive(viewModel.scrollToBottomPublisher) {
                // Scroll to the last item with animation
                if let lastSong = viewModel.playlistItems.last {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(lastSong.id, anchor: .bottom)
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
                // Drag handle on the left when editing
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
                
                // Song content
                PlaylistItemView(song: song)
                    .opacity(videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0)
                    .offset(x: swipeState[song.id] ?? 0)
                    .scaleEffect(draggedSongId == song.id ? 1.05 : 1.0)
                    .opacity(draggedSongId == song.id ? 0.8 : (videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0))
                    .shadow(
                        color: draggedSongId == song.id ? AppTheme.rightPanelAccent.opacity(0.3) : .clear,
                        radius: draggedSongId == song.id ? 8 : 0,
                        x: 0,
                        y: draggedSongId == song.id ? 4 : 0
                    )
                    .animation(.easeInOut(duration: 0.2), value: draggedSongId)
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
            .if(isEditing) { view in
                view                        .onDrop(of: [.text], delegate: PlaylistDropDelegate(
                            item: song,
                            listData: $viewModel.playlistItems,
                            current: $viewModel.draggedItem,
                            draggedSongId: $draggedSongId
                        ))
            }
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
        
        // First, try to verify file exists
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: song.filePath) {
            print("❌ DEBUG: MP4 file not found at: \(song.filePath)")
            
            // Try to restore folder access if this looks like a folder-based file
            if song.filePath.contains("File Provider Storage") {
                print("🔄 DEBUG: Attempting to restore folder access for File Provider Storage file")
                
                // Try to restore folder access using the settings view model
                let settingsViewModel = SettingsViewModel.shared
                if settingsViewModel.filePickerService.restoreFolderAccess() {
                    print("✅ DEBUG: Folder access restored, retrying file access")
                    
                    // Retry file access after restoring folder access
                    if fileManager.fileExists(atPath: song.filePath) {
                        print("✅ DEBUG: File now accessible after folder access restoration")
                        // Try to access the file data
                        if (try? Data(contentsOf: URL(fileURLWithPath: song.filePath), options: .alwaysMapped)) != nil {
                            print("✅ DEBUG: File verified after folder restoration, starting playback")
                            onSongSelected?(song)
                            return
                        }
                    }
                }
                
                print("❌ DEBUG: Could not restore access to file even after folder restoration")
            }
            
            // Remove the song from the playlist since it can't be played
            Task {
                if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                    await viewModel.removeFromPlaylist(at: IndexSet(integer: index))
                }
            }
            // Show error alert
            viewModel.showError("Cannot play '\(song.cleanTitle)' - MP4 file is missing")
            return
        }
        
        // Try to access the file data
        if (try? Data(contentsOf: URL(fileURLWithPath: song.filePath), options: .alwaysMapped)) == nil {
            print("❌ DEBUG: MP4 file exists but is not accessible: \(song.filePath)")
            
            // Try to restore folder access if this looks like a folder-based file
            if song.filePath.contains("File Provider Storage") {
                print("🔄 DEBUG: File not accessible, attempting to restore folder access")
                
                let settingsViewModel = SettingsViewModel.shared
                if settingsViewModel.filePickerService.restoreFolderAccess() {
                    print("✅ DEBUG: Folder access restored, retrying file access")
                    
                    // Retry file access after restoring folder access
                    if (try? Data(contentsOf: URL(fileURLWithPath: song.filePath), options: .alwaysMapped)) != nil {
                        print("✅ DEBUG: File now accessible after folder access restoration")
                        onSongSelected?(song)
                        return
                    }
                }
                
                print("❌ DEBUG: Could not restore access to file even after folder restoration")
            }
            
            // Remove the song from the playlist since it can't be played
            Task {
                if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                    await viewModel.removeFromPlaylist(at: IndexSet(integer: index))
                }
            }
            // Show error alert
            viewModel.showError("Cannot play '\(song.cleanTitle)' - MP4 file is not accessible")
            return
        }
        
        print("✅ DEBUG: File verified, starting playback")
        onSongSelected?(song)
    }
    
    private func deleteSong(_ song: Song) {
        Task {
            if let index = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                await viewModel.removeFromPlaylist(at: IndexSet(integer: index))
            }
        }
    }

    private var playlistHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAY LIST")
                    .font(.headline)
                    .foregroundColor(AppTheme.rightPanelAccent)
                
                // Show status when video is playing or in edit mode
                if videoPlayerViewModel.currentVideo != nil {
                    Text("Selection disabled while video playing")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else if isEditing {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Song selection disabled in edit mode")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("Drag ≡ to reorder • Tap ⊖ to delete • Swipe left for quick delete")
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
                    draggedSongId = nil // Clear drag feedback when exiting edit mode
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

// MARK: - Drag Handle Component

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

// MARK: - Drag and Drop Support

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
