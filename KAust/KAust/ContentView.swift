//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI

// MARK: - Main Content View
struct ContentView: View {
    @State private var showSettings = false
    @StateObject private var playlistViewModel = PlaylistViewModel()
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            // Main Content
            MainContentView(
                showSettings: $showSettings,
                playlistViewModel: playlistViewModel
            )
            
            // Video Player Overlay
            if videoPlayerViewModel.currentVideo != nil {
                VideoPlayerOverlayView(viewModel: videoPlayerViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .environmentObject(videoPlayerViewModel)
    }
}

// MARK: - Main Content View
private struct MainContentView: View {
    @Binding var showSettings: Bool
    let playlistViewModel: PlaylistViewModel
    
    var body: some View {
        GeometryReader { geometry in
            let layout = LayoutMetrics(geometry: geometry)
            
            HStack(spacing: AppConstants.Layout.defaultSpacing) {
                // LEFT COLUMN
                LeftColumnView(
                    playlistViewModel: playlistViewModel,
                    layout: layout
                )
                
                // RIGHT COLUMN
                RightColumnView(
                    showSettings: $showSettings,
                    playlistViewModel: playlistViewModel,
                    layout: layout
                )
            }
            .padding(.horizontal, AppConstants.Layout.outerUIPadding)
            .padding(.vertical, AppConstants.Layout.outerUIPadding)
        }
        .background(AppTheme.appBackground.ignoresSafeArea())
    }
}

// MARK: - Layout Metrics
private struct LayoutMetrics {
    let totalWidth: CGFloat
    let totalHeight: CGFloat
    let columnWidth: CGFloat
    
    init(geometry: GeometryProxy) {
        self.totalWidth = geometry.size.width
        self.totalHeight = geometry.size.height
        let outerPadding = AppConstants.Layout.outerUIPadding
        let centerGap = AppConstants.Layout.defaultSpacing
        self.columnWidth = (totalWidth - outerPadding * 2 - centerGap) / 2
    }
}

// MARK: - Left Column View
private struct LeftColumnView: View {
    let playlistViewModel: PlaylistViewModel
    let layout: LayoutMetrics
    
    var body: some View {
        VStack(spacing: 0) {
            TitlePanelView()
                .frame(height: AppConstants.Layout.titlePanelHeight)
            ControlsPanelView()
                .frame(height: AppConstants.Layout.controlsPanelHeight)
            SongListView(playlistViewModel: playlistViewModel)
                .frame(maxHeight: .infinity)
        }
        .frame(width: layout.columnWidth, height: layout.totalHeight - AppConstants.Layout.outerUIPadding * 2)
    }
}

private struct RightColumnView: View {
    @Binding var showSettings: Bool
    let playlistViewModel: PlaylistViewModel
    let layout: LayoutMetrics
    @EnvironmentObject var videoPlayerViewModel: VideoPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            EmptyPanelView()
                .frame(height: AppConstants.Layout.titlePanelHeight)
            SettingsAccessPanelView {
                showSettings = true
            }
            .frame(height: AppConstants.Layout.controlsPanelHeight)
            PlaylistView(
                viewModel: playlistViewModel,
                onSongSelected: { song in
                    videoPlayerViewModel.play(song: song)
                    if let index = playlistViewModel.playlistItems.firstIndex(where: { $0.id == song.id }) {
                        playlistViewModel.removeFromPlaylist(at: IndexSet(integer: index))
                    }
                }
            )
            .frame(maxHeight: .infinity)
        }
        .frame(width: layout.columnWidth, height: layout.totalHeight - AppConstants.Layout.outerUIPadding * 2)
    }
}

// MARK: - Preview
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
