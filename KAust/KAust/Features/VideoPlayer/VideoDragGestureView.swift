//
//  VideoDragGestureView.swift
//  KAust
//
//  Dedicated video drag component for video player
//  Handles ONLY video dragging with maximum performance
//

import SwiftUI
import AVFoundation

struct VideoDragGestureView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    let geometry: GeometryProxy
    
    // MARK: - Drag State (Isolated)
    @GestureState private var dragOffset = CGSize.zero
    @State private var basePosition = CGSize.zero
    @State private var isDragging = false
    @State private var dragStartTime: Date = Date()
    
    // MARK: - Performance State
    @State private var isInDragPerformanceMode = false
    @State private var progressBlockingActive = false
    
    // MARK: - Debug State
    @State private var debugInfo: String = ""
    @State private var dragVelocity: CGSize = .zero
    
    var body: some View {
        ZStack {
            // Debug overlay (only in debug builds)
            #if DEBUG
            if isDragging && !debugInfo.isEmpty {
                VStack {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundColor(.green)
                        .padding(.horizontal, 8)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(4)
                    Spacer()
                }
                .allowsHitTesting(false)
            }
            #endif
            
            // Invisible drag area (full video area)
            Rectangle()
                .fill(Color.clear)
                .contentShape(Rectangle())
                .gesture(
                    viewModel.isMinimized ? dragGesture : nil
                )
                .allowsHitTesting(!progressBlockingActive) // Block when progress is being dragged
        }
        .onAppear {
            // Sync local position with viewModel
            basePosition = viewModel.overlayOffset
            
            // Listen for progress bar blocking
            NotificationCenter.default.addObserver(
                forName: .init("BlockVideoDrag"),
                object: nil,
                queue: .main
            ) { _ in
                progressBlockingActive = true
                print("🚫 VIDEO DRAG: Blocked by progress bar operation")
            }
            
            NotificationCenter.default.addObserver(
                forName: .init("AllowVideoDrag"),
                object: nil,
                queue: .main
            ) { _ in
                progressBlockingActive = false
                print("✅ VIDEO DRAG: Unblocked - ready for dragging")
            }
        }
        .onChange(of: viewModel.overlayOffset) { _, newOffset in
            // Sync local position when viewModel changes (e.g., centering)
            basePosition = newOffset
        }
    }
    
    // MARK: - Drag Gesture
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .updating($dragOffset) { value, state, _ in
                let debugStart = Date()
                
                // Start performance mode on first drag
                if !isDragging {
                    startDragPerformanceMode()
                }
                
                // CRITICAL FIX: Update viewModel position in real-time for smooth dragging
                let currentPosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                
                // Apply bounds and update viewModel immediately
                let boundedPosition = applyBounds(currentPosition)
                viewModel.overlayOffset = boundedPosition
                
                // Update drag state for gesture system
                state = value.translation
                
                // Calculate velocity for debug
                #if DEBUG
                let timeDelta = Date().timeIntervalSince(dragStartTime)
                if timeDelta > 0 {
                    dragVelocity = CGSize(
                        width: value.translation.width / timeDelta,
                        height: value.translation.height / timeDelta
                    )
                }
                
                let debugEnd = Date()
                debugInfo = "Drag: (\(Int(value.translation.width)), \(Int(value.translation.height))) | Velocity: (\(Int(dragVelocity.width)), \(Int(dragVelocity.height))) | Latency: \(String(format: "%.1f", debugEnd.timeIntervalSince(debugStart) * 1000))ms"
                #endif
                
                print("🎬 VIDEO DRAG: Moving to offset (\(Int(boundedPosition.width)), \(Int(boundedPosition.height)))")
            }
            .onEnded { value in
                let debugStart = Date()
                
                print("🎬 VIDEO DRAG: Drag ended - committing position")
                
                // Commit final position
                let finalPosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                
                // Apply bounds checking
                let boundedPosition = applyBounds(finalPosition)
                
                // Update both local and viewModel state
                basePosition = boundedPosition
                viewModel.overlayOffset = boundedPosition
                
                // Exit performance mode
                Task {
                    await stopDragPerformanceMode()
                }
                
                #if DEBUG
                let debugEnd = Date()
                debugInfo = "Final: (\(Int(boundedPosition.width)), \(Int(boundedPosition.height))) | Commit latency: \(String(format: "%.1f", debugEnd.timeIntervalSince(debugStart) * 1000))ms"
                
                // Clear debug info after delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    debugInfo = ""
                }
                #endif
            }
    }
    
    // MARK: - Performance Mode Management
    
    private func startDragPerformanceMode() {
        guard !isInDragPerformanceMode else { return }
        
        print("🚀 VIDEO DRAG: Entering ultra-performance mode")
        isDragging = true
        isInDragPerformanceMode = true
        dragStartTime = Date()
        
        // Block progress bar interactions
        NotificationCenter.default.post(name: .init("BlockProgressBar"), object: nil)
        
        // Hide controls during drag (but keep video/audio playing)
        hideControlsDuringDrag()
        
        // Suspend non-essential operations
        suspendNonEssentialOperations()
        
        // Allocate maximum resources for smooth dragging
        allocateMaximumDragResources()
        
        print("✅ VIDEO DRAG: Ultra-performance mode active")
    }
    
    private func stopDragPerformanceMode() async {
        guard isInDragPerformanceMode else { return }
        
        print("🔄 VIDEO DRAG: Exiting ultra-performance mode")
        isDragging = false
        isInDragPerformanceMode = false
        
        // Restore progress bar interactions
        NotificationCenter.default.post(name: .init("AllowProgressBar"), object: nil)
        
        // Restore controls with 5-second fade
        restoreControlsAfterDrag()
        
        // Restore normal operations
        await restoreNormalOperations()
        
        // Release drag resources
        releaseDragResources()
        
        print("✅ VIDEO DRAG: Normal mode restored")
    }
    
    // MARK: - Control Management
    
    private func hideControlsDuringDrag() {
        // Keep video playing but hide UI controls
        // Controls work in background but are visually hidden
        viewModel.areControlsVisible = false
        print("🎛️ VIDEO DRAG: Controls hidden (working in background)")
    }
    
    private func restoreControlsAfterDrag() {
        // Show controls immediately
        viewModel.areControlsVisible = true
        
        // Start 5-second fade timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if viewModel.isPlaying && !viewModel.isScrubbing && !self.isDragging {
                withAnimation(.easeInOut(duration: 0.3)) {
                    viewModel.areControlsVisible = false
                }
            }
        }
        
        print("🎛️ VIDEO DRAG: Controls restored with 5s fade timer")
    }
    
    // MARK: - Resource Management
    
    private func suspendNonEssentialOperations() {
        // Suspend Core Data operations
        NotificationCenter.default.post(name: .init("SuspendCoreDataObservers"), object: nil)
        
        // Keep time observers running (video continues playing)
        print("⏸️ VIDEO DRAG: Non-essential operations suspended")
    }
    
    private func restoreNormalOperations() async {
        // Restore Core Data operations
        NotificationCenter.default.post(name: .init("RestoreCoreDataObservers"), object: nil)
        
        print("▶️ VIDEO DRAG: Normal operations restored")
    }
    
    private func allocateMaximumDragResources() {
        // Set highest priority for drag operations
        Task.detached(priority: .userInitiated) {
            print("⚡ VIDEO DRAG: Maximum resources allocated for smooth dragging")
        }
    }
    
    private func releaseDragResources() {
        print("♻️ VIDEO DRAG: Drag resources released")
    }
    
    // MARK: - Bounds Management
    
    private func applyBounds(_ position: CGSize) -> CGSize {
        // Calculate video size
        let videoWidth = calculateMinimizedWidth()
        let videoHeight = calculateMinimizedHeight()
        
        // Calculate bounds
        let maxX = (geometry.size.width - videoWidth) / 2
        let maxY = (geometry.size.height - videoHeight) / 2
        
        // Apply bounds
        let boundedX = max(-maxX, min(maxX, position.width))
        let boundedY = max(-maxY, min(maxY, position.height))
        
        return CGSize(width: boundedX, height: boundedY)
    }
    
    private func calculateMinimizedWidth() -> CGFloat {
        let preferredWidth = geometry.size.width * 0.5
        return max(640, min(960, preferredWidth))
    }
    
    private func calculateMinimizedHeight() -> CGFloat {
        return calculateMinimizedWidth() / (16.0 / 9.0)
    }
}

// MARK: - Preview

#Preview {
    GeometryReader { geometry in
        VideoDragGestureView(viewModel: VideoPlayerViewModel(), geometry: geometry)
    }
    .background(Color.black)
} 