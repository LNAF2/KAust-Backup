//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI
import AVKit
import Foundation
import UIKit



struct ContentView: View {
    @StateObject private var playlistViewModel: PlaylistViewModel
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var settingsViewModel: SettingsViewModel  // Global settings view model
    @EnvironmentObject var kioskModeService: KioskModeService  // Add Kiosk Mode service
    @State private var showSettings = false
    @State private var showingDownloadProgressWindow = false  // Global download progress state
    @State private var showingCustomResults = false  // For showing download results
    
    // Layout constants
    private let outerPadding: CGFloat = 16
    private let centerGap: CGFloat = 16
    private let topPanelHeight: CGFloat = 60
    private let middlePanelHeight: CGFloat = 36
    
    init() {
        let videoPlayerVM = VideoPlayerViewModel()
        _videoPlayerViewModel = StateObject(wrappedValue: videoPlayerVM)
        
        let playlist = PlaylistViewModel(videoPlayerViewModel: videoPlayerVM)
        _playlistViewModel = StateObject(wrappedValue: playlist)
        
        // Initialize SettingsViewModel with UserPreferencesService
        let preferencesService = UserPreferencesService()
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(userPreferencesService: preferencesService))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let totalWidth = geometry.size.width
            let totalPadding = outerPadding * 2 + centerGap
            let columnWidth = (totalWidth - totalPadding) / 2
            
            ZStack {
                // BACKGROUND UI - Always visible
                HStack(spacing: centerGap) {
                    leftColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                    rightColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                }
                .padding(.horizontal, outerPadding)
                .padding(.vertical, outerPadding)
                .allowsHitTesting(!showingDownloadProgressWindow)  // Block ALL touches during download
                .opacity(showingDownloadProgressWindow ? 0.3 : 1.0)  // Gray out during download
                
                // DRAGGABLE VIDEO OVERLAY - Only when minimized, positioned over UI
                if videoPlayerViewModel.currentVideo != nil && videoPlayerViewModel.isMinimized {
                    VideoPlayerContainerView(viewModel: videoPlayerViewModel)
                        .allowsHitTesting(!showingDownloadProgressWindow)  // Block video player touches during download
                }
                
                // FULLSCREEN VIDEO - Only when maximized, covers everything
                if videoPlayerViewModel.currentVideo != nil && !videoPlayerViewModel.isMinimized {
                    VideoPlayerContainerView(viewModel: videoPlayerViewModel)
                        .ignoresSafeArea()
                        .allowsHitTesting(!showingDownloadProgressWindow)  // Block video player touches during download
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
        }

        .onChange(of: settingsViewModel.filePickerService.processingState) { _, newState in
            switch newState {
            case .processing, .paused:
                // Immediately show progress window and dismiss settings
                showingDownloadProgressWindow = true
                showSettings = false  // Close settings window
            case .completed, .cancelled:
                showingDownloadProgressWindow = true  // Keep showing until manually closed
            case .idle:
                showingDownloadProgressWindow = false
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(kioskModeService: kioskModeService)
                .environmentObject(settingsViewModel)  // Pass shared settings view model
        }
        .sheet(isPresented: $settingsViewModel.isShowingFolderPicker) {
            FolderPickerView(
                isPresented: $settingsViewModel.isShowingFolderPicker,
                onFolderSelected: settingsViewModel.handleFolderSelected,
                onError: settingsViewModel.handleFilePickerError
            )
        }
        .sheet(isPresented: $showingCustomResults) {
            DownloadResultsView(
                results: settingsViewModel.filePickerService.results,
                onDismiss: {
                    showingCustomResults = false
                }
            )
        }
        .fullScreenCover(isPresented: $showingDownloadProgressWindow) {
            // GLOBAL DOWNLOAD PROGRESS WINDOW - Appears above EVERYTHING including sheets
            DownloadProgressWindow(
                progress: settingsViewModel.filePickerService.batchProgress,
                filePickerService: settingsViewModel.filePickerService,
                onDismiss: {
                    showingDownloadProgressWindow = false
                },
                onShowResults: {
                    showingCustomResults = true
                }
            )
            .background(Color.clear) // Transparent background since the window has its own
        }
        .environmentObject(videoPlayerViewModel)
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .deleteSongFromPlaylist,
                object: nil,
                queue: .main
            ) { notification in
                Task { @MainActor in
                    if let song = notification.object as? Song {
                        print("🗑️ ContentView - Removing song from playlist: \(song.title)")
                        await playlistViewModel.removeFromPlaylist(song)
                    }
                }
            }
            
            // Handle folder picker requests from Settings
            NotificationCenter.default.addObserver(
                forName: .requestFolderPicker,
                object: nil,
                queue: .main
            ) { _ in
                print("📁 ContentView - Folder picker requested - dismissing Settings and showing folder picker")
                showSettings = false  // Dismiss Settings first
                
                // Small delay to ensure Settings dismisses before presenting folder picker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    settingsViewModel.isShowingFolderPicker = true
                }
            }
            
            // Handle next song requests from video player
            NotificationCenter.default.addObserver(
                forName: .playNextSongFromPlaylist,
                object: nil,
                queue: .main
            ) { _ in
                Task { @MainActor in
                    print("⏭️ ContentView - Next song requested from video player")
                    if let nextSong = playlistViewModel.playlistItems.first {
                        print("🎵 ContentView - Playing next song: '\(nextSong.title)'")
                        playlistViewModel.playSong(nextSong)
                    } else {
                        print("📭 ContentView - No songs in playlist to play next")
                    }
                }
            }
        }
    }
    
    private func leftColumn(totalHeight: CGFloat, columnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top Left Panel - TITLE
            TitlePanelView()
                .frame(height: topPanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelBorderColor, lineWidth: 1)
                )
            
            // Bottom Left Panel - SONG LIST (now takes remaining space)
            SongListView(playlistViewModel: playlistViewModel)
                .frame(maxHeight: CGFloat.infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
        }
        .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
    }
    
    private func rightColumn(totalHeight: CGFloat, columnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top Right Panel - EMPTY with COG icon
            EmptyPanelView(onSettingsTapped: { showSettings = true })
                .frame(height: topPanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.rightPanelBorderColor, lineWidth: 1)
                )
            
            // Bottom Right Panel - PLAYLIST (now takes remaining space)
            PlaylistView(
                viewModel: playlistViewModel,
                onSongSelected: { song in
                    print("🎬 ContentView.onSongSelected - Song tapped: '\(song.title)'")
                    playlistViewModel.playSong(song)
                }
            )
            .onTapGesture {
                // Center video when playlist area is tapped
                NotificationCenter.default.post(name: .centerVideoPlayer, object: nil)
                print("🎯 Playlist tapped - centering video")
            }
            .frame(maxHeight: CGFloat.infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: 1)
            )
        }
        .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
    }
    
    private func startPlayback(_ song: Song) {
        Task {
            await videoPlayerViewModel.play(song: song)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}


