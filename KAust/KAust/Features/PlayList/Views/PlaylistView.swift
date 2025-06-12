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
    var onSongSelected: ((Song) -> Void)? = nil

    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            playlistHeader
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.rightPanelListBackground)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.rightPanelListBackground, lineWidth: 1)
                
                ScrollViewReader { proxy in
                    List {
                        ForEach(viewModel.playlistItems) { song in
                            PlaylistItemView(song: song)
                                .opacity(videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0) // Dim when video playing
                                .onTapGesture {
                                    // CRITICAL: Prevent song selection while video is playing
                                    if videoPlayerViewModel.currentVideo != nil {
                                        print("🚫 Song selection blocked - Video currently playing: '\(videoPlayerViewModel.currentVideo?.title ?? "Unknown")'")
                                        // Optional: Add haptic feedback to indicate blocked action
                                        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                        impactFeedback.impactOccurred()
                                        return
                                    }
                                    print("✅ Song selection allowed - No video currently playing")
                                    onSongSelected?(song)
                                }
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .background(AppTheme.rightPanelListBackground)
                                .id(song.id) // Important: Add ID for scrolling
                        }
                        .onMove { indices, newOffset in
                            if isEditing {
                                viewModel.playlistItems.move(fromOffsets: indices, toOffset: newOffset)
                            }
                        }
                        .onDelete { indices in
                            if isEditing {
                                viewModel.removeFromPlaylist(at: indices)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(Color.clear)
                    .padding(.vertical, 4)
                    .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
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
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 0)
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
        )
    }

    private var playlistHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("PLAY LIST")
                    .font(.headline)
                    .foregroundColor(AppTheme.rightPanelAccent)
                
                // Show status when video is playing
                if videoPlayerViewModel.currentVideo != nil {
                    Text("Selection disabled while video playing")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            
            Spacer()
            Button(action: { isEditing.toggle() }) {
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
