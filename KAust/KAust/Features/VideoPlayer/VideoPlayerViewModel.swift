import SwiftUI
import AVKit
import Combine

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
    
    // MARK: - Private Properties
    private var player: AVPlayer?
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var controlsFadeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {
        setupBindings()
    }
    
    // MARK: - Public Methods
    func play(song: Song) {
        guard let url = song.videoURL else { return }
        
        // Stop any existing playback
        stop()
        
        // Create new player item and player
        playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        
        // Set current video and start playback
        currentVideo = song
        isPlaying = true
        isMinimized = true
        showControls()
        
        // Start playback
        player?.play()
        
        // Setup time observer
        setupTimeObserver()
    }
    
    func stop() {
        player?.pause()
        player = nil
        playerItem = nil
        currentVideo = nil
        isPlaying = false
        removeTimeObserver()
    }
    
    func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
        showControls()
    }
    
    func toggleSize() {
        isMinimized.toggle()
        showControls()
    }
    
    func showControls() {
        areControlsVisible = true
        startControlsFadeTimer()
    }
    
    func seek(to time: Double) {
        player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        showControls()
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        // Observe player item status
        $playerItem
            .compactMap { $0 }
            .sink { [weak self] item in
                self?.duration = item.duration.seconds
            }
            .store(in: &cancellables)
    }
    
    private func setupTimeObserver() {
        timeObserver = player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.currentTime = time.seconds
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func startControlsFadeTimer() {
        controlsFadeTimer?.invalidate()
        controlsFadeTimer = Timer.scheduledTimer(withTimeInterval: 8, repeats: false) { [weak self] _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                self?.areControlsVisible = false
            }
        }
    }
    
    deinit {
        stop()
        controlsFadeTimer?.invalidate()
    }
} 