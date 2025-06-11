//
//  VideoPlayerViewModel.swift
//  KAust
//
//  Created by Erling Breaden on 7/6/2025.
//

import Foundation
import AVFoundation
import Combine
import SwiftUI

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentVideo: Song?
    @Published var isPlaying: Bool = false
    @Published var isMinimized: Bool = true
    @Published var areControlsVisible: Bool = true
    @Published var overlayOffset: CGSize = .zero
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isDragging: Bool = false

    // MARK: - Private Properties
    private var _player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var controlsFadeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Computed Property
    var player: AVPlayer? { _player }

    // MARK: - Init/Deinit
    init() {
        setupBindings()
    }

    deinit {
        // Store local references before deinit
        let player = _player
        let observer = timeObserver
        let timer = controlsFadeTimer
        
        // Clean up timer
        timer?.invalidate()
        
        // Clean up observer if we have both player and observer
        if let player = player, let observer = observer {
            player.removeTimeObserver(observer)
        }
    }

    // MARK: - Public Methods
    func play(song: Song) {
        stop() // Clean up old player and observer

        currentVideo = song

        guard let url = Bundle.main.url(forResource: song.filePath.replacingOccurrences(of: ".mp4", with: ""), withExtension: "mp4") else {
            print("Video file not found: \(song.filePath)")
            return
        }

        playerItem = AVPlayerItem(url: url)
        _player = AVPlayer(playerItem: playerItem)
        isPlaying = true
        isMinimized = true
        areControlsVisible = true
        overlayOffset = .zero
        _player?.play()
        setupTimeObserver()
        setupPlayerItemObservers()
        startControlsFadeTimer()
    }

    func stop() {
        _player?.pause()
        Task { @MainActor in
            await removeTimeObserver()
        }
        _player = nil
        playerItem = nil
        currentVideo = nil
        isPlaying = false
        areControlsVisible = false
        controlsFadeTimer?.invalidate()
    }

    func togglePlayPause() {
        guard let player = _player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
            areControlsVisible = true
            controlsFadeTimer?.invalidate()
        } else {
            player.play()
            isPlaying = true
            startControlsFadeTimer()
        }
    }

    func toggleSize() {
        isMinimized.toggle()
    }

    func showControls() {
        areControlsVisible = true
        if isPlaying {
            startControlsFadeTimer()
        }
    }

    func seek(to time: Double) {
        guard let player = _player else { return }
        let clampedTime = max(0, min(time, duration))
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600))
        currentTime = clampedTime
        areControlsVisible = true
        if isPlaying {
            startControlsFadeTimer()
        }
    }

    func skip(seconds: Double) {
        let newTime = max(0, min(currentTime + seconds, duration))
        seek(to: newTime)
    }

    // MARK: - Drag Handling
    func beginDrag() {
        isDragging = true
        _player?.pause()
    }

    func endDrag() {
        isDragging = false
        seek(to: currentTime)
        if isPlaying {
            _player?.play()
        }
    }

    // MARK: - Private Methods
    private func setupBindings() {
        // Add Combine bindings if needed
    }

    private func setupTimeObserver() {
        Task { @MainActor in
            await removeTimeObserver()
        }
        guard let player = _player else { return }
        timeObserver = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.2, preferredTimescale: 600), queue: .main) { [weak self] time in
            guard let self = self else { return }
            Task { @MainActor in
                if !self.isDragging {
                    self.currentTime = time.seconds
                }
                if let duration = player.currentItem?.duration.seconds, duration.isFinite {
                    self.duration = duration
                }
            }
        }
    }

    private func removeTimeObserver() async {
        if let player = _player, let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func setupPlayerItemObservers() {
        guard let playerItem = playerItem else { return }
        NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime, object: playerItem)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.stop()
                }
            }
            .store(in: &cancellables)
    }

    private func startControlsFadeTimer() {
        controlsFadeTimer?.invalidate()
        controlsFadeTimer = Timer.scheduledTimer(withTimeInterval: AppConstants.Animation.videoControlsFadeDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if self.isPlaying {
                    self.areControlsVisible = false
                }
            }
        }
    }
}
