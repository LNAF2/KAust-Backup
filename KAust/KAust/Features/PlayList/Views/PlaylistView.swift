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
                    .fill(AppTheme.rightPanelListBackground)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
                List {
                    ForEach(viewModel.playlistItems) { song in
                        PlaylistItemRow(song: song)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .background(AppTheme.rightPanelListBackground)
                    }
                    .onMove { from, to in
                        if isEditing {
                            viewModel.moveSong(from: from, to: to)
                        }
                    }
                    .onDelete { indexSet in
                        if isEditing {
                            viewModel.deleteSongs(at: indexSet)
                        }
                    }
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, .constant(isEditing ? EditMode.active : EditMode.inactive))
                .background(Color.clear)
                .padding(.vertical, 4)
            }
            .padding(.horizontal, panelGap)
            .padding(.bottom, panelGap)
            .padding(.top, 0) // <-- aligns top with song list
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

struct PlaylistItemRow: View {
    let song: AppSong

    var body: some View {
        ZStack {
            AppTheme.rightPanelListBackground
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.rightPanelAccent.opacity(0.5), lineWidth: 1)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title.uppercased())
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.rightPanelAccent)
                HStack(alignment: .firstTextBaseline) {
                    Text(song.artist)
                        .font(.caption)
                        .fontWeight(.regular)
                        .foregroundColor(AppTheme.rightPanelAccent.opacity(0.7))
                    Spacer()
                    Text(song.duration)
                        .font(.caption)
                        .foregroundColor(AppTheme.rightPanelAccent)
                        .alignmentGuide(.firstTextBaseline) { d in d[.firstTextBaseline] }
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
