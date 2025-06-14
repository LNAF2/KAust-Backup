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
    @GestureState private var dragOffset = CGSize.zero
    @State private var basePosition = CGSize.zero
    
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
                            .offset(viewModel.isMinimized ? CGSize(width: basePosition.width + dragOffset.width, height: basePosition.height + dragOffset.height) : .zero)
                            .gesture(
                                viewModel.isMinimized ? dragGesture(in: geometry) : nil
                            )
                            
                        
                        Spacer()
                    }
                    Spacer()
                }
                .background(viewModel.isMinimized ? Color.clear : Color.black)
            }
            .onAppear {
                // Initialize local position from viewModel
                basePosition = viewModel.overlayOffset
            }
            .onChange(of: viewModel.overlayOffset) { _, newOffset in
                // Always sync local position with viewModel (especially when centering)
                basePosition = newOffset
                print("🔄 Synced basePosition to: \(newOffset)")
            }
        }
    }
    
    @ViewBuilder
    private func videoPlayerContainer(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // ONLY ONE VideoPlayer instance - immediate load
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(!viewModel.isAirPlayActive) // Enable during AirPlay, disabled otherwise
                    .background(Color.black) // Ensure consistent background
            }
            
            // Only add our gesture overlay when NOT in AirPlay mode
            if !viewModel.isAirPlayActive {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        if dragOffset == .zero {
                            print("👆 SINGLE TAP detected - showing controls")
                            viewModel.showControls()
                        }
                    }
                    .onTapGesture(count: 2) {
                        if dragOffset == .zero {
                            print("👆👆 DOUBLE TAP detected - toggling size")
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            viewModel.toggleSize()
                        }
                    }
                    .onTapGesture(count: 3) {
                        if dragOffset == .zero && viewModel.isMinimized {
                            print("👆👆👆 TRIPLE TAP detected - centering video")
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            viewModel.centerVideo()
                        }
                    }
            }
            
            // Custom controls overlay - ALWAYS in the same container
            // Hide custom controls when AirPlay is active, let native controls take over
            if viewModel.areControlsVisible && !viewModel.isAirPlayActive {
                customControlsOverlay()
            }
            
            // Show AirPlay indicator when streaming
            if viewModel.isAirPlayActive {
                airPlayIndicator()
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
    private func airPlayIndicator() -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "airplayvideo")
                    .foregroundColor(.white)
                    .font(.title2)
                
                Text("Streaming to AirPlay")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Delete button in AirPlay mode
                Button(action: { 
                    viewModel.deleteSong()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(20)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .padding(.bottom, 40)
            .padding(.horizontal, 20)
        }
    }
    
    // ZERO @Published access during drag - pure smooth performance
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                // Pure local state - zero @Published property access
                state = value.translation
            }
            .onEnded { value in
                // Commit final position - update both local and viewModel
                basePosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                viewModel.overlayOffset = basePosition
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
