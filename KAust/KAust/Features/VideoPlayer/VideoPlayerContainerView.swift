//
//  VideoPlayerContainerView.swift
//  KAust
//
//  Container view that orchestrates video player components
//  Provides clean separation between drag and progress operations
//

import SwiftUI
import AVKit

struct VideoPlayerContainerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    // MARK: - State Management
    @State private var isProgressBlocked = false
    @State private var isDragBlocked = false
    
    // MARK: - Drag State
    @GestureState private var dragOffset = CGSize.zero
    @State private var basePosition = CGSize.zero
    @State private var isDragging = false
    
    // Constants following app patterns
    private let cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius
    private let minWidth: CGFloat = 640  // Doubled from 320
    private let maxWidth: CGFloat = 960  // Doubled from 480
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    var body: some View {
        if viewModel.currentVideo != nil {
            if viewModel.isMinimized {
                // SMALL DRAGGABLE OVERLAY - No background, positioned over UI
                GeometryReader { geometry in
                    videoPlayerContainer(geometry)
                        .frame(
                            width: calculateWidth(geometry),
                            height: calculateHeight(geometry)
                        )
                        .cornerRadius(cornerRadius)
                        .position(
                            x: geometry.size.width / 2 + viewModel.overlayOffset.width,
                            y: geometry.size.height / 2 + viewModel.overlayOffset.height
                        )
                        .onAppear {
                            setupNotificationObservers()
                            // Initialize drag position
                            basePosition = viewModel.overlayOffset
                        }
                        .onChange(of: viewModel.overlayOffset) { _, newOffset in
                            // Sync local position when viewModel changes (e.g., centering)
                            basePosition = newOffset
                        }
                }
            } else {
                // FULLSCREEN MODE - Black background, centered
                GeometryReader { geometry in
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            
                            videoPlayerContainer(geometry)
                                .frame(
                                    width: geometry.size.width,
                                    height: geometry.size.height
                                )
                            
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Color.black.ignoresSafeArea())
                    .onAppear {
                        setupNotificationObservers()
                    }
                }
            }
        }
    }
    
    // MARK: - Video Player Container
    
    @ViewBuilder
    private func videoPlayerContainer(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // AVPlayerViewController layer - CRITICAL: This provides the actual video display
            if let player = viewModel.player {
                AVPlayerViewControllerRepresentable(player: player)
                    .disabled(!viewModel.isAirPlayActive)
                    .background(Color.black)
                    .allowsHitTesting(false) // Disable AVPlayer's built-in controls
            }
            
            // Tap gesture for controls (separate from drag)
            if !viewModel.isAirPlayActive {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        handleControlsTap()
                    }
                    .allowsHitTesting(!isDragBlocked && !isProgressBlocked)
            }
            
            // Controls overlay - CRITICAL: Restore original positioning
            if (viewModel.areControlsVisible || viewModel.isScrubbing) && !viewModel.isAirPlayActive {
                controlsOverlay(geometry)
                    .allowsHitTesting(true)
                    .opacity(1.0)
            }
            
            // AirPlay indicator
            if viewModel.isAirPlayActive {
                airPlayIndicator()
            }
        }
        // CRITICAL FIX: Apply drag gesture to the entire container when minimized
        .gesture(
            viewModel.isMinimized && !viewModel.isAirPlayActive && !isDragBlocked ? dragGesture : nil
        )
    }
    
    // MARK: - Controls Overlay - Different layouts for minimized vs fullscreen
    
    @ViewBuilder
    private func controlsOverlay(_ geometry: GeometryProxy) -> some View {
        if viewModel.isMinimized {
            // MINIMIZED LAYOUT: Progress bar flush with bottom (YouTube style)
            ZStack {
                VStack(spacing: 0) { // Remove all spacing
                    Spacer()
                    
                    // TWO-ROW CONTROL LAYOUT - Controls elevated above progress bar
                    VStack(spacing: 12) {
                        // TOP ROW: Playback controls ONLY (centered) - Hidden during scrubbing
                        if !viewModel.isScrubbing {
                            HStack(spacing: 40) {
                            // Skip backward 10s
                            Button(action: {
                                Task {
                                    await viewModel.skipBackward()
                                }
                            }) {
                                Image(systemName: "gobackward.10")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(VideoControlButtonStyle())
                            
                            // Play/Pause - HOLLOW ARROW HEAD (see-through)
                            Button(action: {
                                viewModel.togglePlayPause()
                            }) {
                                Image(systemName: viewModel.isPlaying ? "pause" : "play")
                                    .font(.title)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(VideoControlButtonStyle())
                            
                            // Skip forward 10s
                            Button(action: {
                                Task {
                                    await viewModel.skipForward()
                                }
                            }) {
                                Image(systemName: "goforward.10")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(VideoControlButtonStyle())
                            }
                        }
                        
                        // BOTTOM ROW: Time display (left) + Utility controls (right) - SAME LEVEL - Hidden during scrubbing
                        if !viewModel.isScrubbing {
                        HStack {
                            // Time display - LEFT SIDE (elapsed / remaining) - DOUBLED SIZE
                            Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedTimeRemaining)")
                                .font(.title3) // Doubled from .caption to .title3
                                .foregroundColor(.white)
                                .monospaced() // Ensures consistent spacing for time digits
                            
                            Spacer() // Push utility controls to the right
                            
                            // Utility controls - RIGHT SIDE (same level as time)
                            HStack(spacing: 40) {
                                // Delete/Bin icon
                                Button(action: {
                                    Task {
                                        await viewModel.deleteCurrentSong()
                                    }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(VideoControlButtonStyle())
                                
                                // Next song icon (arrow with vertical line)
                                Button(action: {
                                    Task {
                                        await viewModel.playNextSong()
                                    }
                                }) {
                                    Image(systemName: "forward.end")
                                        .font(.title2)
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(VideoControlButtonStyle())
                            }
                        }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.7)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    
                    // Progress bar FLUSH with bottom - force with negative padding
                    VideoProgressBarView(viewModel: viewModel)
                        .allowsHitTesting(!isDragBlocked) // Blocked during drag operations
                        .background(Color.black.opacity(0.3))
                        .padding(.bottom, -8) // Force flush - negative padding to overcome internal spacing
                }
                
                // Size toggle button in top-right corner
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.toggleSize()
                            }
                        }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(VideoControlButtonStyle())
                        .padding(.trailing, 12)
                        .padding(.top, 12)
                    }
                    Spacer()
                }
            }
        } else {
            // FULLSCREEN LAYOUT: Progress bar flush with bottom + controls above
            ZStack {
                // Minimize button - LOWERED by one line
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                viewModel.toggleSize()
                            }
                        }) {
                            Image(systemName: "arrow.down.right.and.arrow.up.left")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                        .buttonStyle(VideoControlButtonStyle())
                        .padding(.trailing, 20)
                        .padding(.top, 64) // Increased from 20 to lower by one line
                    }
                    Spacer()
                }
                
                // CENTER PLAYBACK CONTROLS - In middle of video screen - Hidden during scrubbing
                if !viewModel.isScrubbing {
                    HStack(spacing: 60) {
                        // Skip backward 10s
                        Button(action: {
                            Task {
                                await viewModel.skipBackward()
                            }
                        }) {
                            Image(systemName: "gobackward.10")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(VideoControlButtonStyle())
                        
                        // Play/Pause - HOLLOW ARROW HEAD (see-through)
                        Button(action: {
                            viewModel.togglePlayPause()
                        }) {
                            Image(systemName: viewModel.isPlaying ? "pause" : "play")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(VideoControlButtonStyle())
                        
                        // Skip forward 10s
                        Button(action: {
                            Task {
                                await viewModel.skipForward()
                            }
                        }) {
                            Image(systemName: "goforward.10")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .padding(16)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .buttonStyle(VideoControlButtonStyle())
                    }
                }
                
                // BOTTOM LAYOUT: Progress bar above Time/Utility controls
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Progress bar - 80 points above time/utility controls
                    VideoProgressBarView(viewModel: viewModel)
                        .allowsHitTesting(!isDragBlocked) // Blocked during drag operations
                        .padding(.horizontal, 20)
                        .background(Color.black.opacity(0.3))
                        .padding(.bottom, 80) // 80 points above time/utility controls
                    
                    // Time display + Utility controls - at bottom - Split conditional to preserve layout
                    HStack {
                        // Time display - LEFT SIDE - HIDDEN during scrubbing to prevent layout collapse
                        if !viewModel.isScrubbing {
                            Text("\(viewModel.formattedCurrentTime) / \(viewModel.formattedTimeRemaining)")
                                .font(.title3) // Doubled from .caption to .title3
                                .foregroundColor(.white)
                                .monospaced() // Ensures consistent spacing for time digits
                        }
                        
                        Spacer()
                        
                        // Utility controls - RIGHT SIDE - ALWAYS VISIBLE as placeholders
                        HStack(spacing: 40) {
                            // Delete/Bin button - ALWAYS VISIBLE
                            Button(action: {
                                Task {
                                    await viewModel.deleteCurrentSong()
                                }
                            }) {
                                Image(systemName: "trash")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(VideoControlButtonStyle())
                            
                            // Next song button - ALWAYS VISIBLE
                            Button(action: {
                                Task {
                                    await viewModel.playNextSong()
                                }
                            }) {
                                Image(systemName: "forward.end")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                            .buttonStyle(VideoControlButtonStyle())
                        }
                    }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 64) // RAISED by one line - increased from 20 to raise up
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.4)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            }
        }
    }
    
    @ViewBuilder
    private func airPlayIndicator() -> some View {
        VStack {
            Image(systemName: "airplay")
                .font(.largeTitle)
                .foregroundColor(.white)
            Text("Streaming to AirPlay")
                .font(.headline)
                .foregroundColor(.white)
        }
        .padding()
        .background(Color.black.opacity(0.7))
        .cornerRadius(12)
    }
    
    // MARK: - Event Handling
    
    private func handleControlsTap() {
        print("👆 Controls tap detected")
        if viewModel.isPlaying {
            viewModel.showControls()
        } else {
            viewModel.showControlsWithoutFade()
        }
    }
    
    // MARK: - Notification Observers
    
    private func setupNotificationObservers() {
        // Listen for blocking notifications
        NotificationCenter.default.addObserver(
            forName: .init("BlockProgressBar"),
            object: nil,
            queue: .main
        ) { _ in
            isProgressBlocked = true
            print("🚫 CONTAINER: Progress bar blocked")
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("AllowProgressBar"),
            object: nil,
            queue: .main
        ) { _ in
            isProgressBlocked = false
            print("✅ CONTAINER: Progress bar unblocked")
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("BlockVideoDrag"),
            object: nil,
            queue: .main
        ) { _ in
            isDragBlocked = true
            print("🚫 CONTAINER: Video drag blocked")
        }
        
        NotificationCenter.default.addObserver(
            forName: .init("AllowVideoDrag"),
            object: nil,
            queue: .main
        ) { _ in
            isDragBlocked = false
            print("✅ CONTAINER: Video drag unblocked")
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragOffset) { value, state, _ in
                // Start performance mode on first drag
                if !isDragging {
                    startDragPerformanceMode()
                }
                
                // CRITICAL: Update viewModel position in real-time for smooth dragging
                let currentPosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                
                // Update viewModel immediately for smooth dragging
                viewModel.overlayOffset = currentPosition
                
                // Update drag state for gesture system
                state = value.translation
                
                print("🎬 VIDEO DRAG: Moving to offset (\(Int(currentPosition.width)), \(Int(currentPosition.height)))")
            }
            .onEnded { value in
                print("🎬 VIDEO DRAG: Drag ended - committing position")
                
                // Commit final position
                let finalPosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                
                // Update both local and viewModel state
                basePosition = finalPosition
                viewModel.overlayOffset = finalPosition
                
                // Exit performance mode
                stopDragPerformanceMode()
                
                print("✅ VIDEO DRAG: Final position (\(Int(finalPosition.width)), \(Int(finalPosition.height)))")
            }
    }
    
    // MARK: - Performance Mode Management
    
    private func startDragPerformanceMode() {
        guard !isDragging else { return }
        
        print("🚀 VIDEO DRAG: Entering ultra-performance mode via ViewModel")
        isDragging = true
        
        // CRITICAL: Use ViewModel's optimized drag performance methods
        viewModel.startDragging()
        
        // Block progress bar interactions
        NotificationCenter.default.post(name: .init("BlockProgressBar"), object: nil)
        
        // Hide controls during drag
        viewModel.areControlsVisible = false
        
        print("✅ VIDEO DRAG: Ultra-performance mode active via ViewModel")
    }
    
    private func stopDragPerformanceMode() {
        guard isDragging else { return }
        
        print("🔄 VIDEO DRAG: Exiting ultra-performance mode via ViewModel")
        isDragging = false
        
        // CRITICAL: Use ViewModel's optimized drag performance methods
        viewModel.stopDragging()
        
        // Restore progress bar interactions
        NotificationCenter.default.post(name: .init("AllowProgressBar"), object: nil)
        
        // Restore controls with 5-second fade
        viewModel.areControlsVisible = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if viewModel.isPlaying && !viewModel.isScrubbing && !self.isDragging {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.areControlsVisible = false
                }
            }
        }
        
        print("✅ VIDEO DRAG: Normal mode restored via ViewModel")
    }
    
    // MARK: - Helper Methods
    
    private func calculateWidth(_ geometry: GeometryProxy) -> CGFloat {
        let availableWidth = geometry.size.width - 40 // Account for padding
        let calculatedWidth = max(minWidth, min(maxWidth, availableWidth * 0.6))
        return calculatedWidth
    }
    
    private func calculateHeight(_ geometry: GeometryProxy) -> CGFloat {
        return calculateWidth(geometry) / aspectRatio
    }
}

// MARK: - AVPlayerViewController Representable

struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        
        // NUCLEAR OPTION: Disable EVERYTHING
        controller.showsPlaybackControls = false
        controller.allowsPictureInPicturePlayback = false
        controller.canStartPictureInPictureAutomaticallyFromInline = false
        controller.updatesNowPlayingInfoCenter = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = UIColor.black
        
        // Disable all iOS 16+ features
        if #available(iOS 16.0, *) {
            controller.speeds = []
            controller.allowsVideoFrameAnalysis = false
        }
        
        // CRITICAL: Keep user interaction enabled for drag gestures, but controls are already disabled
        controller.view.isUserInteractionEnabled = true
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
}

// MARK: - Custom Button Style

struct VideoControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .allowsHitTesting(true)
    }
}

// MARK: - Preview

#Preview {
    VideoPlayerContainerView(viewModel: VideoPlayerViewModel())
        .background(Color.black)
} 