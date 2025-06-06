import SwiftUI
import AVKit

struct VideoPlayerOverlayView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var dragOffset: CGSize = .zero
    @State private var isDragging = false
    
    // Constants for layout
    private let minimizedWidth: CGFloat = 320
    private let minimizedHeight: CGFloat = 180
    private let controlsHeight: CGFloat = 44
    private let cornerRadius: CGFloat = 12
    
    var body: some View {
        if let video = viewModel.currentVideo {
            GeometryReader { geometry in
                ZStack {
                    // Video Player
                    VideoPlayer(player: viewModel.player)
                        .cornerRadius(cornerRadius)
                    
                    // Controls Overlay
                    if viewModel.areControlsVisible {
                        VStack {
                            Spacer()
                            
                            // Controls
                            HStack(spacing: 20) {
                                // Play/Pause Button
                                Button(action: viewModel.togglePlayPause) {
                                    Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                                
                                // Progress Bar
                                ProgressBarView(
                                    currentTime: viewModel.currentTime,
                                    duration: viewModel.duration,
                                    onSeek: viewModel.seek
                                )
                                
                                // Volume Control
                                Button(action: { /* TODO: Implement volume control */ }) {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                                
                                // Delete Button
                                Button(action: viewModel.stop) {
                                    Image(systemName: "trash.fill")
                                        .foregroundColor(.white)
                                        .font(.title2)
                                }
                            }
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(cornerRadius)
                        }
                        .padding(.bottom, 8)
                    }
                }
                .frame(
                    width: viewModel.isMinimized ? minimizedWidth : geometry.size.width,
                    height: viewModel.isMinimized ? minimizedHeight : geometry.size.height
                )
                .offset(viewModel.isMinimized ? viewModel.overlayOffset : .zero)
                .gesture(
                    viewModel.isMinimized ?
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            dragOffset = value.translation
                        }
                        .onEnded { value in
                            isDragging = false
                            let maxOffset = geometry.size.width * 0.75
                            let newOffset = CGSize(
                                width: min(max(value.translation.width, -maxOffset), maxOffset),
                                height: min(max(value.translation.height, -maxOffset), maxOffset)
                            )
                            withAnimation(.spring()) {
                                viewModel.overlayOffset = newOffset
                            }
                        }
                    : nil
                )
                .onTapGesture {
                    viewModel.showControls()
                }
                .onTapGesture(count: 2) {
                    viewModel.toggleSize()
                }
            }
            .animation(.easeInOut(duration: 0.3), value: viewModel.isMinimized)
            .animation(.easeInOut(duration: 0.3), value: viewModel.areControlsVisible)
        }
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