//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI
import AVKit

struct ContentView: View {
    @State private var showSettings = false
    @StateObject private var playlistViewModel = PlaylistViewModel()
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
                                print("🎬 ContentView.onSongSelected - Song tapped: '\(song.title)'")
                                Task {
                                    await videoPlayerViewModel.play(song: song)
                                    // Remove song from playlist when it starts playing
                                    playlistViewModel.removeFromPlaylist(song)
                                }
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

            // Video Player Overlay
            if videoPlayerViewModel.currentVideo != nil {
                CustomVideoPlayerView(viewModel: videoPlayerViewModel)
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .environmentObject(videoPlayerViewModel)
        .onAppear {
            // Add a test song with a bundle resource path
            let bundleTestSong = Song(
                id: "bundle-test-456",
                title: "Bundle Test Video",
                artist: "Bundle Test Artist", 
                duration: "02:00",
                filePath: "SampleVideo" // This will look for SampleVideo.mp4 in the app bundle
            )
            playlistViewModel.addToPlaylist(bundleTestSong)
            print("🧪 Bundle test song added to playlist for debugging")
            
            // Set up notification observer for delete song
            NotificationCenter.default.addObserver(
                forName: .deleteSongFromPlaylist,
                object: nil,
                queue: .main
            ) { notification in
                if let song = notification.object as? Song {
                    print("🗑️ ContentView - Removing song from playlist: \(song.title)")
                    playlistViewModel.removeFromPlaylist(song)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var isDragging = false
    @State private var dragStartOffset: CGSize = .zero
    
    // Constants following app patterns
    private let cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius
    private let minWidth: CGFloat = 640  // Doubled from 320
    private let maxWidth: CGFloat = 960  // Doubled from 480
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    var body: some View {
        if viewModel.currentVideo != nil {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // SINGLE video player container - NO DUPLICATES
                        videoPlayerContainer(geometry)
                            .frame(
                                width: viewModel.isMinimized ? calculateMinimizedWidth(geometry) : geometry.size.width,
                                height: viewModel.isMinimized ? calculateMinimizedHeight(geometry) : geometry.size.height
                            )
                            .cornerRadius(viewModel.isMinimized ? cornerRadius : 0)
                            .offset(viewModel.isMinimized ? viewModel.overlayOffset : .zero)
                            .animation(isDragging ? .none : .easeInOut(duration: 0.3), value: viewModel.isMinimized)
                            .animation(isDragging ? .none : .easeInOut(duration: 0.3), value: viewModel.areControlsVisible)
                            .gesture(
                                viewModel.isMinimized ? dragGesture(in: geometry) : nil
                            )
                            
                        
                        Spacer()
                    }
                    Spacer()
                }
                .background(viewModel.isMinimized ? AnyView(Color.clear) : AnyView(Color.black.ignoresSafeArea()))
            }
        }
    }
    
    @ViewBuilder
    private func videoPlayerContainer(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // ONLY ONE VideoPlayer instance
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(true) // Always disable native controls to prevent interference
            }
            
            // Invisible overlay to capture all touches (especially for full screen double-tap)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .onTapGesture(count: 1) {
                    if !isDragging {
                        print("👆 SINGLE TAP detected - showing controls")
                        viewModel.showControls()
                    }
                }
                .onTapGesture(count: 2) {
                    if !isDragging {
                        print("👆👆 DOUBLE TAP detected - toggling size")
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        viewModel.toggleSize()
                    }
                }
            
            // Custom controls overlay - ALWAYS in the same container
            if viewModel.areControlsVisible {
                customControlsOverlay()
            }
            
            // Screen Size Message
            if viewModel.showScreenSizeMessage {
                screenSizeMessage()
            }
        }
    }
    
    @ViewBuilder
    private func customControlsOverlay() -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Play/Pause and Skip Controls
                HStack(spacing: 30) {
                    Button(action: { 
                        Task { await viewModel.skipBackward() }
                        viewModel.showControls()
                    }) {
                        Image(systemName: "gobackward.10")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                    
                    Button(action: { 
                        viewModel.togglePlayPause()
                        viewModel.showControls()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                    
                    Button(action: { 
                        Task { await viewModel.skipForward() }
                        viewModel.showControls()
                    }) {
                        Image(systemName: "goforward.10")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                }
                
                // Progress bar with times and delete button
                HStack(spacing: 12) {
                    Text(viewModel.formattedCurrentTime)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Slider(value: Binding(
                        get: { viewModel.currentTime },
                        set: { newValue in
                            Task { await viewModel.seek(to: newValue) }
                            viewModel.showControls()
                        }
                    ), in: 0...max(viewModel.duration, 1))
                    .accentColor(.white)
                    
                    Text(viewModel.formattedDuration)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Button(action: { 
                        viewModel.deleteSong()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                }
            }
            .padding(20)
            .background(Color.black.opacity(0.1))
        }
        .allowsHitTesting(true) // CRITICAL: Ensure controls are always tappable
    }
    
    @ViewBuilder
    private func screenSizeMessage() -> some View {
        VStack {
            Text("DOUBLE TAP TO CHANGE SCREEN SIZE")
                .font(.headline)
                .foregroundColor(.white)
                .padding(12)
                .background(Color.black.opacity(0.7))
                .cornerRadius(AppConstants.Layout.panelCornerRadius)
            Spacer()
        }
        .padding(.top, 50)
        .allowsHitTesting(false)
    }
    
    // FIXED drag gesture - properly tracks starting position
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if !isDragging {
                    // First touch - store the starting position
                    isDragging = true
                    dragStartOffset = viewModel.overlayOffset
                }
                
                // Calculate bounds to keep video on screen
                let videoSize = CGSize(
                    width: calculateMinimizedWidth(geometry),
                    height: calculateMinimizedHeight(geometry)
                )
                let maxX = (geometry.size.width - videoSize.width) / 2
                let maxY = (geometry.size.height - videoSize.height) / 2
                
                // Add translation to the starting position
                let newX = max(-maxX, min(maxX, dragStartOffset.width + value.translation.width))
                let newY = max(-maxY, min(maxY, dragStartOffset.height + value.translation.height))
                
                // Update position immediately - stays under finger
                viewModel.overlayOffset = CGSize(width: newX, height: newY)
            }
            .onEnded { _ in
                isDragging = false
                // Position is already set in viewModel.overlayOffset
            }
    }
    
    // Helper methods
    private func calculateMinimizedWidth(_ geometry: GeometryProxy) -> CGFloat {
        let preferredWidth = geometry.size.width * 0.5  // Doubled from 0.25 to 0.5
        return max(minWidth, min(maxWidth, preferredWidth))
    }
    
    private func calculateMinimizedHeight(_ geometry: GeometryProxy) -> CGFloat {
        return calculateMinimizedWidth(geometry) / aspectRatio
    }
}

// MARK: - Custom button style to prevent gesture interference
struct VideoControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .allowsHitTesting(true)
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
