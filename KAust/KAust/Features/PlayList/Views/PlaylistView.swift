//
//  PlaylistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/Playlist/Views/PlaylistView.swift
import SwiftUI

struct PlaylistView: View {
    @StateObject private var viewModel = PlaylistViewModel()
    @State private var isEditing = false

    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            playlistHeader

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.red.opacity(0.1))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.red, lineWidth: 1)

                if viewModel.playlistItems.isEmpty {
                    PlaylistEmptyState()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, panelGap)
                } else {
                    playlistList
                }
            }
            .padding(panelGap)
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.red, lineWidth: 1)
        )
    }

    private var playlistHeader: some View {
        HStack {
            Text("PLAY LIST")
                .font(.headline)
                .foregroundColor(.red)
            Spacer()
            Button(action: { isEditing.toggle() }) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(isEditing ? .green : .red)
                    .font(.title2)
                    .accessibilityLabel(isEditing ? "Done Editing" : "Edit Playlist")
            }
            .buttonStyle(.plain)
            Text("\(viewModel.playlistItems.count) Songs")
                .font(.subheadline)
                .foregroundColor(.red)
        }
        .padding(.horizontal, panelGap)
        .padding(.vertical, 8)
    }

    private var playlistList: some View {
        List {
            ForEach(viewModel.playlistItems) { song in
                PlaylistItemRow(
                    song: song,
                    isEditing: isEditing,
                    onDelete: {
                        if let idx = viewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                            viewModel.playlistItems.remove(at: idx)
                        }
                    }
                )
            }
            .onMove { from, to in
                if isEditing {
                    viewModel.moveSong(from: from, to: to)
                }
            }
        }
        .listStyle(PlainListStyle())
        .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
        .background(Color.clear)
    }
}

struct PlaylistItemRow: View {
    let song: AppSong
    let isEditing: Bool
    let onDelete: () -> Void

    var body: some View {
        PlaylistItemView(song: song)
            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
            .listRowBackground(Color.clear)
            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                if isEditing {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
    }
}
