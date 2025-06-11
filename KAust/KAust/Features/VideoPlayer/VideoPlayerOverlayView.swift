//
//  PlaylistView.swift
//  KAust
//
//  Created by Erling Breaden on 4/6/2025.
//

// Features/VideoPlayer/VideoPlayerOverlayView.swift


import SwiftUI
import AVFoundation

struct VideoPlayerOverlayView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel

    private let aspectRatio: CGFloat = 16.0 / 9.0
    private let minimizedWidthRatio: CGFloat = 0.5
    private let cornerRadius: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if viewModel.isMinimized {
                    minimizedVideoView(in: geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    maximizedVideoView(in: geometry)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.isMinimized)
            .onTapGesture(count: 2) {
                withAnimation { viewModel.toggleSize() }
            }
            .onTapGesture {
                viewModel.showControls()
            }
        }
    }

    // MARK: - Minimized Video View
    private func minimizedVideoView(in geometry: GeometryProxy) -> some View {
        let width = geometry.size.width * minimizedWidthRatio
        let height = width / aspectRatio

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.black)
                .frame(width: width, height: height)
                .shadow(radius: 8)

            videoWithControls(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .frame(width: width, height: height)
        .offset(viewModel.overlayOffset)
        .gesture(
            DragGesture()
                .onChanged { value in
                    viewModel.overlayOffset = value.translation
                }
                .onEnded { value in
                    let maxOffsetX = width * 0.9
                    let maxOffsetY = height * 0.9
                    viewModel.overlayOffset = CGSize(
                        width: min(max(value.translation.width, -maxOffsetX), maxOffsetX),
                        height: min(max(value.translation.height, -maxOffsetY), maxOffsetY)
                    )
                }
        )
    }

    // MARK: - Maximized Video View
    private func maximizedVideoView(in geometry: GeometryProxy) -> some View {
        let maxWidth = geometry.size.width
        let maxHeight = geometry.size.height
        let width = min(maxWidth, maxHeight * aspectRatio)
        let height = width / aspectRatio

        return ZStack {
            Color.black.ignoresSafeArea() // Black background ONLY for maximized overlay
            videoWithControls(width: width, height: height)
                .frame(width: width, height: height)
                .clipped()
        }
        .frame(width: maxWidth, height: maxHeight, alignment: .center)
    }

    // MARK: - Video with Controls
    private func videoWithControls(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let player = viewModel.player {
                AVPlayerContainerView(player: player)
                    .frame(width: width, height: height)
            }
            if viewModel.areControlsVisible {
                controlsOverlay(width: width)
                    .frame(width: width, height: height, alignment: .bottom)
            }
        }
    }

    // MARK: - Controls Overlay
    private func controlsOverlay(width: CGFloat) -> some View {
        VStack {
            Spacer()
            VStack(spacing: 8) {
                // Playback controls
                HStack(spacing: 24) {
                    Button(action: { viewModel.skip(seconds: -10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    Button(action: viewModel.togglePlayPause) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 36))
                            .foregroundColor(.white)
                    }
                    Button(action: { viewModel.skip(seconds: 10) }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                }
                .padding(.bottom, 4)

                // Progress bar and bin
                ProgressBarWithTap(
                    currentTime: viewModel.currentTime,
                    duration: viewModel.duration,
                    onSeek: { viewModel.seek(to: $0) },
                    onBin: { viewModel.stop() }
                )
                .frame(width: width * 0.92, height: 32)
                .padding(.bottom, 12)
            }
            .background(Color.black.opacity(0.4))
            .cornerRadius(12)
        }
    }

    // MARK: - Helper
    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "00:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Custom Progress Bar with Tap-to-Seek
private struct ProgressBarWithTap: View {
    let currentTime: Double
    let duration: Double
    let onSeek: (Double) -> Void
    let onBin: () -> Void

    @State private var isDragging = false
    @State private var dragValue: Double = 0

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 8) {
                Text(formatTime(isDragging ? dragValue : currentTime))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 48)

                ZStack {
                    // Tap area
                    Rectangle()
                        .fill(Color.clear)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let percent = min(max(0, value.location.x / geo.size.width), 1)
                                    let newTime = percent * (duration > 0 ? duration : 1)
                                    isDragging = true
                                    dragValue = newTime
                                }
                                .onEnded { value in
                                    let percent = min(max(0, value.location.x / geo.size.width), 1)
                                    let newTime = percent * (duration > 0 ? duration : 1)
                                    isDragging = false
                                    onSeek(newTime)
                                }
                        )

                    // Slider
                    Slider(
                        value: Binding(
                            get: { isDragging ? dragValue : currentTime },
                            set: { newValue in
                                isDragging = true
                                dragValue = newValue
                            }
                        ),
                        in: 0...max(duration, 1),
                        onEditingChanged: { editing in
                            if !editing {
                                onSeek(dragValue)
                                isDragging = false
                            }
                        }
                    )
                    .accentColor(.white)
                }

                Text(formatTime(duration))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 48)

                Button(action: onBin) {
                    Image(systemName: "trash")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                        .padding(8)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }
            }
        }
    }

    private func formatTime(_ time: Double) -> String {
        guard !time.isNaN && !time.isInfinite else { return "00:00" }
        let totalSeconds = Int(time)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
