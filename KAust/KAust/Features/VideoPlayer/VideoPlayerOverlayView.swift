import SwiftUI
import AVKit

struct VideoPlayerOverlayView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var isDragging = false
    
    // Constants following app patterns
    private let cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius
    private let minWidth: CGFloat = 320
    private let maxWidth: CGFloat = 480
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    var body: some View {
        if let video = viewModel.currentVideo {
            GeometryReader { geometry in
                ZStack {
                    // Full-screen black background when not minimized
                    if !viewModel.isMinimized {
                        Color.black
                            .ignoresSafeArea()
                    }
                    
                    // Video Player
                    VideoPlayer(player: viewModel.player)
                        .cornerRadius(viewModel.isMinimized ? cornerRadius : 0)
                    
                    // Screen Size Message
                    if viewModel.showScreenSizeMessage {
                        VStack {
                            ScreenSizeMessageView()
                            Spacer()
                        }
                        .padding(.top, 20)
                    }
                    
                    // Controls Overlay
                    if viewModel.areControlsVisible {
                        VStack {
                            Spacer()
                            
                            // Main Controls Container
                            VStack(spacing: 16) {
                                // Play/Pause and Skip Controls
                                HStack(spacing: 30) {
                                    SkipButtonsView(
                                        onSkipBackward: viewModel.skipBackward,
                                        onSkipForward: viewModel.skipForward
                                    )
                                    
                                    Button(action: viewModel.togglePlayPause) {
                                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                            .foregroundColor(.white)
                                            .font(.title)
                                    }
                                }
                                
                                // Progress Bar with Time Display
                                HStack(spacing: 12) {
                                    TimeDisplayView(time: viewModel.formattedCurrentTime)
                                    
                                    ProgressBarView(
                                        currentTime: viewModel.currentTime,
                                        duration: viewModel.duration,
                                        onSeek: viewModel.seek
                                    )
                                    
                                    TimeDisplayView(time: viewModel.formattedDuration)
                                }
                                
                                // Delete Button (right-aligned)
                                HStack {
                                    Spacer()
                                    Button(action: { Task { await viewModel.stop() } }) {
                                        Image(systemName: "trash.fill")
                                            .foregroundColor(.white)
                                            .font(.title2)
                                    }
                                }
                            }
                            .padding(20)
                            .background(Color.black.opacity(0.1)) // Minimal opacity as requested
                            .cornerRadius(cornerRadius)
                        }
                        .padding(.bottom, 20)
                    }
                }
                .frame(
                    width: viewModel.isMinimized ? minimizedSize(in: geometry).width : geometry.size.width,
                    height: viewModel.isMinimized ? minimizedSize(in: geometry).height : geometry.size.height
                )
                .offset(viewModel.isMinimized ? viewModel.overlayOffset : .zero)
                .animation(
                    // Only animate when NOT dragging and NOT minimized
                    isDragging ? .none : .easeInOut(duration: 0.3),
                    value: viewModel.isMinimized
                )
                .animation(
                    // Only animate controls when NOT dragging
                    isDragging ? .none : .easeInOut(duration: 0.3),
                    value: viewModel.areControlsVisible
                )
                .gesture(
                    viewModel.isMinimized ? dragGesture(in: geometry) : nil
                )
                .onTapGesture {
                    if !isDragging {
                        viewModel.showControls()
                    }
                }
                .onTapGesture(count: 2) {
                    if !isDragging {
                        viewModel.toggleSize()
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func minimizedSize(in geometry: GeometryProxy) -> CGSize {
        let width = min(max(geometry.size.width * 0.25, minWidth), maxWidth)
        let height = width / aspectRatio
        return CGSize(width: width, height: height)
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                
                // Calculate the safe bounds to keep video on screen
                let videoSize = minimizedSize(in: geometry)
                let maxX = (geometry.size.width - videoSize.width) / 2
                let maxY = (geometry.size.height - videoSize.height) / 2
                
                // Apply the translation directly with bounds checking
                let newX = max(-maxX, min(maxX, value.translation.x))
                let newY = max(-maxY, min(maxY, value.translation.y))
                
                // Update position immediately - no animation, no delay
                viewModel.overlayOffset = CGSize(width: newX, height: newY)
            }
            .onEnded { _ in
                isDragging = false
                // Position is already set, no need for spring animation
            }
    }
}

// MARK: - Component Views

struct TimeDisplayView: View {
    let time: String
    
    var body: some View {
        Text(time)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
    }
}

struct SkipButtonsView: View {
    let onSkipBackward: () -> Void
    let onSkipForward: () -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: onSkipBackward) {
                Image(systemName: "gobackward.10")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            Button(action: onSkipForward) {
                Image(systemName: "goforward.10")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
    }
}

struct ScreenSizeMessageView: View {
    var body: some View {
        Text("DOUBLE TAP TO CHANGE SCREEN SIZE")
            .font(.headline)
            .foregroundColor(.white)
            .padding(12)
            .background(Color.black.opacity(0.7))
            .cornerRadius(AppConstants.Layout.panelCornerRadius)
    }
}

// MARK: - Progress Bar View
struct ProgressBarView: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    
    @State private var isDragging = false
    @State private var dragLocation: CGFloat = 0
    
    private var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                
                // Progress
                Rectangle()
                    .fill(Color.white)
                    .frame(width: geometry.size.width * CGFloat(progress))
                
                // Handle
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: geometry.size.width * CGFloat(progress) - 6)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                isDragging = true
                                let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                dragLocation = newProgress
                            }
                            .onEnded { value in
                                isDragging = false
                                let newProgress = min(max(0, value.location.x / geometry.size.width), 1)
                                onSeek(newProgress * duration)
                            }
                    )
            }
        }
        .frame(height: 4)
    }
}

#Preview {
    VideoPlayerOverlayView(viewModel: VideoPlayerViewModel())
} 