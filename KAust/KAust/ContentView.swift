//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI
import AVKit
import Foundation

struct ContentView: View {
    @StateObject private var playlistViewModel: PlaylistViewModel
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()  // Global settings view model
    @State private var showSettings = false
    @State private var showingDownloadProgressWindow = false  // Global download progress state
    
    // Layout constants
    private let outerPadding: CGFloat = 16
    private let centerGap: CGFloat = 16
    private let topPanelHeight: CGFloat = 60
    private let middlePanelHeight: CGFloat = 36
    
    init() {
        let videoPlayerVM = VideoPlayerViewModel()
        _videoPlayerViewModel = StateObject(wrappedValue: videoPlayerVM)
        _playlistViewModel = StateObject(wrappedValue: PlaylistViewModel(videoPlayerViewModel: videoPlayerVM))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let columnWidth = (geometry.size.width - (outerPadding * 2 + centerGap)) / 2
            
            ZStack {
                HStack(spacing: centerGap) {
                    leftColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                    rightColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                }
                .padding(.horizontal, outerPadding)
                .padding(.vertical, outerPadding)
                .allowsHitTesting(!showingDownloadProgressWindow)  // Block ALL touches during download
                .opacity(showingDownloadProgressWindow ? 0.3 : 1.0)  // Gray out during download
                
                if videoPlayerViewModel.currentVideo != nil {
                    CustomVideoPlayerView(viewModel: videoPlayerViewModel)
                        .ignoresSafeArea()
                        .allowsHitTesting(!showingDownloadProgressWindow)  // Block video player touches too
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
            SettingsView()
                .environmentObject(settingsViewModel)  // Pass shared settings view model
        }
        .fullScreenCover(isPresented: $showingDownloadProgressWindow) {
            // GLOBAL DOWNLOAD PROGRESS WINDOW - Appears above EVERYTHING including sheets
            DownloadProgressWindow(
                progress: settingsViewModel.filePickerService.batchProgress,
                filePickerService: settingsViewModel.filePickerService,
                onDismiss: {
                    showingDownloadProgressWindow = false
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
                if let song = notification.object as? Song {
                    print("🗑️ ContentView - Removing song from playlist: \(song.title)")
                    Task {
                        await playlistViewModel.removeFromPlaylist(song)
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
                        .stroke(Color.purple, lineWidth: 1)
                )
            
            // Middle Left Panel - CONTROLS  
            ControlsPanelView()
                .frame(height: middlePanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
            
            // Bottom Left Panel - SONG LIST
            SongListView(playlistViewModel: playlistViewModel)
                .frame(maxHeight: .infinity)
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
            // Top Right Panel - EMPTY
            EmptyPanelView()
                .frame(height: topPanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.red, lineWidth: 1)
                )
            
            // Middle Right Panel - SETTINGS ACCESS
            SettingsAccessPanelView {
                showSettings = true
            }
            .frame(height: middlePanelHeight)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: 1)
            )
            
            // Bottom Right Panel - PLAYLIST
            PlaylistView(
                viewModel: playlistViewModel,
                onSongSelected: { song in
                    print("🎬 ContentView.onSongSelected - Song tapped: '\(song.title)'")
                    playlistViewModel.playSong(song)
                }
            )
            .frame(maxHeight: .infinity)
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
            .onChanged { _ in
                // PERFORMANCE: Enter ultra-performance mode on first drag movement
                Task {
                    await viewModel.startDragging()
                }
            }
            .onEnded { value in
                // PERFORMANCE: Exit ultra-performance mode when drag ends
                Task {
                    await viewModel.stopDragging()
                }
                
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
