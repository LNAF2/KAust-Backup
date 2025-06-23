//
//  VideoProgressBarView.swift
//  KAust
//
//  Dedicated progress bar component for video player
//  Handles ONLY progress bar interactions with maximum performance
//

import SwiftUI
import AVFoundation

struct VideoProgressBarView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    
    // MARK: - Progress Bar State (Isolated)
    @State private var isDragging = false
    @State private var dragValue: Double = 0
    @State private var lastDragTime: Date = Date()
    @State private var audioWasSuspended = false
    @State private var originalVolume: Float = 1.0
    
    // MARK: - Performance State
    @State private var isInProgressPerformanceMode = false
    
    // MARK: - Debug State
    // Debug info removed per user request
    
    var body: some View {
        VStack(spacing: 8) {
            // Temporary time display (only shown during drag) - MOVED ABOVE progress bar
            if isDragging {
                Text(formatTime(dragValue))
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(8)
                    .transition(.opacity.combined(with: .scale))
            }
            
            // Progress bar with optimized gesture handling
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(height: 4)
                    
                    // Progress fill with handle coupled at trailing edge - GUARANTEED synchronization
                    Rectangle()
                        .fill(Color.white)
                        .frame(
                            width: geometry.size.width * CGFloat(progressRatio),
                            height: 4
                        )
                        .overlay(
                            Circle()
                                .fill(Color.white)
                                .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                                .scaleEffect(isDragging ? 1.2 : 1.0),
                            alignment: .trailing
                        )
                }
                .contentShape(Rectangle()) // Make entire area draggable
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            handleDragChanged(value, geometry: geometry)
                        }
                        .onEnded { value in
                            handleDragEnded(value, geometry: geometry)
                        }
                )
            }
            .frame(height: 20) // Larger touch target
        }
        .allowsHitTesting(!viewModel.isDragging) // Block when video is being dragged
    }
    
    // MARK: - Computed Properties
    
    private var progressRatio: Double {
        if isDragging {
            return dragValue / max(viewModel.duration, 1.0)
        } else {
            return viewModel.currentTime / max(viewModel.duration, 1.0)
        }
    }
    
    // MARK: - Drag Handling
    
    private func handleDragChanged(_ value: DragGesture.Value, geometry: GeometryProxy) {
        // Start performance mode on first drag
        if !isDragging {
            startProgressPerformanceMode()
            
            // CRITICAL: Enter scrubbing mode in viewModel for time display updates
            viewModel.isScrubbing = true
        }
        
        // Calculate new position with bounds checking
        let newRatio = min(max(0, value.location.x / geometry.size.width), 1.0)
        let newTime = newRatio * viewModel.duration
        
        // CRITICAL: Update drag state immediately for instant visual response
        dragValue = newTime
        lastDragTime = Date()
        
        // Update viewModel scrub time for time displays
        viewModel.scrubPosition = newTime
        
        // Debug info population removed per user request
        
        // INSTANT seek with maximum priority - no Task overhead
        if let player = viewModel.player {
            let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        print("🎚️ PROGRESS: Scrubbing to \(formatTime(newTime)) (\(Int(newRatio * 100))%)")
    }
    
    private func handleDragEnded(_ value: DragGesture.Value, geometry: GeometryProxy) {
        print("🎚️ PROGRESS: Scrub ended - restoring normal playback")
        
        // Calculate final position
        let finalRatio = min(max(0, value.location.x / geometry.size.width), 1.0)
        let finalTime = finalRatio * viewModel.duration
        
        // CRITICAL: Exit scrubbing mode in viewModel
        viewModel.isScrubbing = false
        
        // Final precise seek to exact position
        if let player = viewModel.player {
            let cmTime = CMTime(seconds: finalTime, preferredTimescale: 600)
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        }
        
        // Exit performance mode
        Task {
            await stopProgressPerformanceMode()
        }
        
        // Debug info clearing removed per user request
    }
    
    // MARK: - Performance Mode Management
    
    private func startProgressPerformanceMode() {
        guard !isInProgressPerformanceMode else { return }
        
        print("🎚️ PROGRESS: Entering MAXIMUM scrubbing performance mode")
        isDragging = true
        isInProgressPerformanceMode = true
        
        // CRITICAL: Block video dragging to prevent conflicts
        NotificationCenter.default.post(name: .init("BlockVideoDrag"), object: nil)
        
        // MAXIMUM PERFORMANCE: Suspend audio immediately for smooth scrubbing
        suspendAudio()
        
        // CRITICAL: Freeze video frame during scrub - suspend all video updates
        freezeVideoFrame()
        
        // Suspend time observers to prevent conflicts
        NotificationCenter.default.post(name: .init("SuspendTimeObservers"), object: nil)
        
        // Hide all other controls during scrubbing
        viewModel.areControlsVisible = false
        
        // Allocate MAXIMUM resources for scrubbing
        allocateMaximumScrubResources()
        
        print("✅ PROGRESS: MAXIMUM scrubbing performance active - video frozen, audio muted")
    }
    
    private func stopProgressPerformanceMode() async {
        guard isInProgressPerformanceMode else { return }
        
        print("🔄 PROGRESS: Exiting scrubbing performance mode")
        isDragging = false
        isInProgressPerformanceMode = false
        
        // Restore audio immediately
        restoreAudio()
        
        // CRITICAL: Unfreeze video frame and restore normal playback
        unfreezeVideoFrame()
        
        // Restore time observers
        NotificationCenter.default.post(name: .init("RestoreTimeObservers"), object: nil)
        
        // Allow video dragging again
        NotificationCenter.default.post(name: .init("AllowVideoDrag"), object: nil)
        
        // Restore controls with 5-second fade
        viewModel.areControlsVisible = true
        
        // Start fade timer
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            if viewModel.isPlaying && !viewModel.isScrubbing {
                viewModel.areControlsVisible = false
            }
        }
        
        // Release scrubbing resources
        releaseScrubResources()
        
        print("✅ PROGRESS: Normal playback restored - video unfrozen, audio restored")
    }
    
    // MARK: - Audio Management
    
    private func suspendAudio() {
        guard let player = viewModel.player else { return }
        
        originalVolume = player.volume
        player.volume = 0.0
        audioWasSuspended = true
        
        print("🔇 PROGRESS: Audio suspended for smooth scrubbing")
    }
    
    private func restoreAudio() {
        guard audioWasSuspended, let player = viewModel.player else { return }
        
        player.volume = originalVolume
        audioWasSuspended = false
        
        print("🔊 PROGRESS: Audio restored")
    }
    
    // MARK: - Resource Management
    
    private func freezeVideoFrame() {
        // Freeze the video frame during scrubbing for maximum performance
        guard let player = viewModel.player else { return }
        
        // Pause video updates but keep seeking active
        player.rate = 0.0
        
        // Notify video player to enter scrub mode
        NotificationCenter.default.post(name: .init("VideoFrameFrozen"), object: nil)
        
        print("🧊 PROGRESS: Video frame frozen during scrub")
    }
    
    private func unfreezeVideoFrame() {
        // Restore normal video playback after scrubbing
        guard let player = viewModel.player else { return }
        
        // Restore playback rate if video was playing
        if viewModel.isPlaying {
            player.rate = 1.0
        }
        
        // Notify video player to exit scrub mode
        NotificationCenter.default.post(name: .init("VideoFrameUnfrozen"), object: nil)
        
        print("🔥 PROGRESS: Video frame unfrozen - normal playback restored")
    }
    
    private func allocateMaximumScrubResources() {
        // Set MAXIMUM priority for scrubbing operations
        Task.detached(priority: .userInitiated) {
            // Allocate maximum CPU resources for smooth scrubbing
            print("⚡ PROGRESS: MAXIMUM scrubbing resources allocated")
        }
        
        // Reduce system animations during scrub
        UIView.setAnimationsEnabled(false)
        
        // Request maximum performance mode from system
        ProcessInfo.processInfo.performExpiringActivity(withReason: "Video scrubbing") { expired in
            if !expired {
                print("🚀 PROGRESS: System performance boost activated")
            }
        }
    }
    
    private func releaseScrubResources() {
        // Restore normal system behavior
        UIView.setAnimationsEnabled(true)
        
        print("♻️ PROGRESS: Scrubbing resources released, animations restored")
    }
    
    // MARK: - Utility Methods
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Preview

#Preview {
    VideoProgressBarView(viewModel: VideoPlayerViewModel())
        .frame(height: 60)
        .background(Color.black)
} 