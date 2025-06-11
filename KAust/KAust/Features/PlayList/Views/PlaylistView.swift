//
//  PlaylistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistView.swift

import SwiftUI

struct PlaylistView: View {
    @ObservedObject var viewModel: PlaylistViewModel
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel
    @State private var isEditing = false
    var onSongSelected: ((Song) -> Void)? = nil

    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            playlistHeader
            ZStack {
                // Set the intended background color for the whole panel
                AppTheme.rightPanelListBackground
                    .cornerRadius(cornerRadius)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
                List {
                    ForEach(viewModel.playlistItems) { song in
                        PlaylistItemView(song: song)
                            .onTapGesture {
                                if videoPlayerViewModel.currentVideo == nil {
                                    onSongSelected?(song)
                                }
                            }
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(Color.clear) // Let the panel color show through
                            .disabled(videoPlayerViewModel.currentVideo != nil)
                            .opacity(videoPlayerViewModel.currentVideo != nil ? 0.5 : 1.0)
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
                .scrollContentBackground(.hidden) // <-- THIS IS CRITICAL
                .background(Color.clear)
                .padding(.vertical, 4)
                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
            }
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 0)
        }
        .background(AppTheme.rightPanelListBackground) // Match the panel color
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
        )
    }

    private var playlistHeader: some View {
        HStack {
            Text("PLAY LIST")
                .font(.headline)
                .foregroundColor(AppTheme.rightPanelAccent)
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
