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
import Combine

struct ContentView: View {
    @StateObject private var playlistViewModel: PlaylistViewModel
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var settingsViewModel: SettingsViewModel
    @StateObject private var focusManager = FocusManager()
    @EnvironmentObject var userPreferences: UserPreferencesService
    @EnvironmentObject var roleManager: UserRoleManager
    @EnvironmentObject var kioskModeService: KioskModeService
    @State private var isSettingsPresented = false
    // COMMENTED OUT FOR NOW
    // @State private var showingDownloadProgressWindow = false  // Global download progress state
    // @State private var showingCustomResults = false  // For showing download results
    
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
        
        let preferences = UserPreferencesService()
        _settingsViewModel = StateObject(wrappedValue: SettingsViewModel(userPreferencesService: preferences))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let columnWidth = (geometry.size.width - centerGap - outerPadding * 2) / 2
            
            ZStack {
                // BACKGROUND UI - Always visible
                HStack(spacing: centerGap) {
                    // Left Column - SONG LIST
                    leftColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                    
                    // Right Column - PLAYLIST
                    rightColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                }
                .padding(outerPadding)
                
                // DRAGGABLE VIDEO OVERLAY - Only when minimized, positioned over UI
                if let _ = videoPlayerViewModel.currentVideo {
                    if videoPlayerViewModel.isMinimized {
                        VideoPlayerContainerView(viewModel: videoPlayerViewModel)
                    } else {
                        VideoPlayerContainerView(viewModel: videoPlayerViewModel)
                            .ignoresSafeArea()
                    }
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
        }
        .sheet(isPresented: $isSettingsPresented) {
            NavigationView {
                SettingsView(kioskModeService: kioskModeService)
                    .environmentObject(settingsViewModel)
                    .environmentObject(roleManager)
                    .environmentObject(userPreferences)
            }
        }
        .environmentObject(videoPlayerViewModel)
        .environmentObject(focusManager)
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
            SongListDisplayView()
                .frame(maxHeight: CGFloat.infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue, lineWidth: 1)
                )
        }
        .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
    }
    
    private func rightColumn(totalHeight: CGFloat, columnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Settings button panel
            HStack {
                Spacer()
                Button(action: {
                    isSettingsPresented = true
                }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundColor(AppTheme.rightPanelAccent)
                }
                .padding(.trailing, 16)
                .padding(.vertical, 12)
            }
            .frame(height: topPanelHeight)
            .background(AppTheme.rightPanelBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppTheme.rightPanelBorderColor, lineWidth: 1)
            )
            
            // Playlist panel
            PlaylistPanelView(videoPlayerViewModel: videoPlayerViewModel)
                .frame(maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.rightPanelBorderColor, lineWidth: 1)
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


