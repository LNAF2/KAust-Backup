import SwiftUI
import AVKit
import Foundation
import CoreData

struct VideoPlayerOverlayView: View {
    // Commented out since this file isn't used in the app
    // @ObservedObject var viewModel: VideoPlayerViewModel
    @State private var isDragging = false
    
    // Constants following app patterns
    private let cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius
    private let minWidth: CGFloat = 320
    private let maxWidth: CGFloat = 480
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    var body: some View {
        // This file is not used in the app - placeholder to fix compilation
        Text("VideoPlayerOverlayView - Not Used")
            .foregroundColor(.white)
            .background(Color.black)
    }
    
    // MARK: - Helper Methods (commented out since file not used)
    /*
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
                let newX = max(-maxX, min(maxX, value.translation.width))
                let newY = max(-maxY, min(maxY, value.translation.height))
                
                // Update position immediately - no animation, no delay
                viewModel.overlayOffset = CGSize(width: newX, height: newY)
            }
            .onEnded { _ in
                isDragging = false
                // Position is already set, no need for spring animation
            }
    }
    */
}

// MARK: - Component Views

/*
struct TimeDisplayView: View {
    let time: String
    
    var body: some View {
        Text(time)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
    }
}
*/

// Component views commented out since file not used
/*
struct SkipButtonsView: View {
    let onSkipBackward: () async -> Void
    let onSkipForward: () async -> Void
    
    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                Task {
                    await onSkipBackward()
                }
            }) {
                Image(systemName: "gobackward.10")
                    .foregroundColor(.white)
                    .font(.title2)
            }
            
            Button(action: {
                Task {
                    await onSkipForward()
                }
            }) {
                Image(systemName: "goforward.10")
                    .foregroundColor(.white)
                    .font(.title2)
            }
        }
    }
}
*/

/*
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
*/

#Preview {
    // Mock preview since this file isn't actually used in the app
    Text("VideoPlayerOverlayView Preview")
        .foregroundColor(.white)
        .background(Color.black)
} 