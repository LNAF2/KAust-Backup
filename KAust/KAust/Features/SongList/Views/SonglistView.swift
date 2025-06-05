//
//  SonglistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

import SwiftUI

struct SongListView: View {
    @StateObject private var viewModel = SonglistViewModel()
    private let cornerRadius: CGFloat = 8
    private let panelGap: CGFloat = 8

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.purple.opacity(0.08))
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.purple, lineWidth: 1)

                if viewModel.songs.isEmpty {
                    SonglistEmptyState()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, panelGap)
                } else {
                    songList
                }
            }
            .padding(panelGap)
        }
        .background(Color.white)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(Color.purple, lineWidth: 1)
        )
    }

    private var header: some View {
        HStack {
            Text("SONG LIST")
                .font(.headline)
                .foregroundColor(.purple)
            Spacer()
            Image(systemName: "pencil.circle.fill")
                .font(.title2)
                .opacity(0)
            Text("\(viewModel.songs.count) Songs")
                .font(.subheadline)
                .foregroundColor(.purple)
        }
        .padding(.horizontal, panelGap)
        .padding(.vertical, 8)
    }

    private var songList: some View {
        List {
            ForEach(viewModel.songs) { song in
                SongListItemView(song: song)
            }
        }
        .listStyle(PlainListStyle())
        .background(Color.clear)
    }
}
