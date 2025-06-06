//
//  VideoPlayerOverlayView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI
import AVKit

struct VideoPlayerOverlayView: View {
    let song: Song
    private let overlayWidthRatio: CGFloat = 0.7
    private let overlayAspectRatio: CGFloat = 16.0 / 9.0
    private let cornerRadius: CGFloat = 16
    private let controlSize: CGFloat = 36
    private let progressBarHeight: CGFloat = 6

    @State private var player: AVPlayer? = nil
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1

    var body: some View {
        GeometryReader { geometry in
            let overlayWidth = geometry.size.width * overlayWidthRatio
            let overlayHeight = overlayWidth / overlayAspectRatio

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.3)) // More transparent

                if let player = player {
                    VideoPlayer(player: player)
                        .frame(width: overlayWidth, height: overlayHeight)
                        .cornerRadius(cornerRadius)
                        .allowsHitTesting(false)
                } else {
                    Text("Video not found")
                        .foregroundColor(.white)
                        .frame(width: overlayWidth, height: overlayHeight)
                }

                VStack(spacing: 0) {
                    // Top row: Trash icon (delete/close) in top right
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: controlSize, height: controlSize)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Center row: Video controls
                    HStack(spacing: 32) {
                        Button(action: { skip(seconds: -10) }) {
                            Image(systemName: "gobackward.10")
                        }
                        Button(action: { playPause() }) {
                            Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        }
                        Button(action: { skip(seconds: 10) }) {
                            Image(systemName: "goforward.10")
                        }
                    }
                    .font(.system(size: controlSize, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)

                    // Progress bar
                    VStack(spacing: 4) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: progressBarHeight)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: overlayWidth * CGFloat(currentTime / duration), height: progressBarHeight)
                        }
                        HStack {
                            Text(formatTime(currentTime))
                            Spacer()
                            Text(formatTime(duration))
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .shadow(radius: 12)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onAppear {
                if let url = Bundle.main.url(forResource: song.filePath, withExtension: nil) {
                    let avPlayer = AVPlayer(url: url)
                    player = avPlayer
                    isPlaying = true
                    avPlayer.play()
                    avPlayer.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
                        currentTime = time.seconds
                        if let item = avPlayer.currentItem {
                            duration = item.duration.seconds.isFinite ? item.duration.seconds : 1
                        }
                    }
                }
            }
        }
    }

    private func playPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    private func skip(seconds: Double) {
        guard let player = player else { return }
        let current = player.currentTime().seconds
        let newTime = max(0, min(current + seconds, duration))
        player.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

/*
import SwiftUI
import AVKit

struct VideoPlayerOverlayView: View {
    let song: Song
    private let overlayWidthRatio: CGFloat = 0.7
    private let overlayAspectRatio: CGFloat = 16.0 / 9.0
    private let cornerRadius: CGFloat = 16

    // Retain the player!
    @State private var player: AVPlayer? = nil

    var body: some View {
        GeometryReader { geometry in
            let overlayWidth = geometry.size.width * overlayWidthRatio
            let overlayHeight = overlayWidth / overlayAspectRatio

            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.7))

                if let player = player {
                    VideoPlayer(player: player)
                        .frame(width: overlayWidth, height: overlayHeight)
                        .cornerRadius(cornerRadius)
                        .onAppear {
                            player.seek(to: .zero)
                            player.play()
                        }
                } else {
                    Text("Video not found")
                        .foregroundColor(.white)
                        .frame(width: overlayWidth, height: overlayHeight)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .shadow(radius: 12)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            .onAppear {
                if let url = Bundle.main.url(forResource: song.filePath, withExtension: nil) {
                    print("Found video at: \(url)")
                    player = AVPlayer(url: url)
                } else {
                    print("Video not found for: \(song.filePath)")
                }
            }
        }
    }
}

*/

/*
import SwiftUI

struct VideoPlayerOverlayView: View {
    // Sizing constants
    private let overlayWidthRatio: CGFloat = 0.7 // 70% of parent width
    private let overlayAspectRatio: CGFloat = 16.0 / 9.0 // Standard video aspect ratio
    private let cornerRadius: CGFloat = 16
    private let controlSize: CGFloat = 36
    private let progressBarHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let overlayWidth = geometry.size.width * overlayWidthRatio
            let overlayHeight = overlayWidth / overlayAspectRatio

            ZStack {
                // Background (semi-transparent for now)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.7))

                VStack(spacing: 0) {
                    // Top row: Trash icon (delete/close) in top right
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: controlSize, height: controlSize)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Center row: Video controls
                    HStack(spacing: 32) {
                        Image(systemName: "gobackward.10")
                        Image(systemName: "play.fill")
                        Image(systemName: "goforward.10")
                    }
                    .font(.system(size: controlSize, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)

                    // Progress bar
                    VStack(spacing: 4) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: progressBarHeight)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: overlayWidth * 0.3, height: progressBarHeight) // 30% progress for demo
                        }
                        // Time indicators (optional for maximized view)
                        HStack {
                            Text("00:42")
                            Spacer()
                            Text("03:15")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .shadow(radius: 12)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false) // Overlay is static for Phase 1
    }
}

struct VideoPlayerOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VideoPlayerOverlayView()
        }
        .ignoresSafeArea()
    }
}
*/
