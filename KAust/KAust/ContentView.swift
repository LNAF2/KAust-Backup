//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var showSettings = false
    @StateObject private var playlistViewModel = PlaylistViewModel()
    @State private var currentlyPlaying: Song? = nil
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let totalHeight = geometry.size.height
                let outerPadding = AppConstants.Layout.outerUIPadding
                let centerGap = AppConstants.Layout.defaultSpacing
                let columnWidth = (totalWidth - outerPadding * 2 - centerGap) / 2
                let topPanelHeight = AppConstants.Layout.titlePanelHeight
                let middlePanelHeight = AppConstants.Layout.controlsPanelHeight

                HStack(spacing: centerGap) {
                    // LEFT COLUMN
                    VStack(spacing: 0) {
                        TitlePanelView()
                            .frame(height: topPanelHeight)
                        ControlsPanelView()
                            .frame(height: middlePanelHeight)
                        SongListView(playlistViewModel: playlistViewModel)
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: columnWidth, height: totalHeight - outerPadding * 2)

                    // RIGHT COLUMN
                    VStack(spacing: 0) {
                        EmptyPanelView()
                            .frame(height: topPanelHeight)
                        SettingsAccessPanelView {
                            showSettings = true
                        }
                        .frame(height: middlePanelHeight)
                        PlaylistView(
                            viewModel: playlistViewModel,
                            onSongSelected: { song in
                                currentlyPlaying = song
                            }
                        )
                        .frame(maxHeight: .infinity)
                    }
                    .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
                }
                .padding(.horizontal, outerPadding)
                .padding(.vertical, outerPadding)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())

            // Video Player Overlay (centered)
            if let song = currentlyPlaying {
                VideoPlayerOverlayView(song: song)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .environmentObject(videoPlayerViewModel)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

/*
import SwiftUI

struct ContentView: View {
    @State private var showSettings = false

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let totalHeight = geometry.size.height
                let outerPadding = AppConstants.Layout.outerUIPadding
                let centerGap = AppConstants.Layout.defaultSpacing
                let columnWidth = (totalWidth - outerPadding * 2 - centerGap) / 2
                let topPanelHeight = AppConstants.Layout.titlePanelHeight
                let middlePanelHeight = AppConstants.Layout.controlsPanelHeight

                HStack(spacing: centerGap) {
                    // LEFT COLUMN
                    VStack(spacing: 0) {
                        TitlePanelView()
                            .frame(height: topPanelHeight)
                        ControlsPanelView()
                            .frame(height: middlePanelHeight)
                        SongListView()
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: columnWidth, height: totalHeight - outerPadding * 2)

                    // RIGHT COLUMN
                    VStack(spacing: 0) {
                        EmptyPanelView()
                            .frame(height: topPanelHeight)
                        SettingsAccessPanelView {
                            showSettings = true
                        }
                        .frame(height: middlePanelHeight)
                        PlaylistView() // <--- Use your working PlaylistView here!
                            .frame(maxHeight: .infinity)
                    }
                    .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
                }
                .padding(.horizontal, outerPadding)
                .padding(.vertical, outerPadding)
            }
            .background(AppTheme.appBackground.ignoresSafeArea())

            // Video Player Overlay (centered)
            VideoPlayerOverlayView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}
*/
