import Foundation
import AVFoundation
import Combine
import CoreData
import SwiftUI

// MARK: - Notification Names
extension Notification.Name {
    static let deleteSongFromPlaylist = Notification.Name("deleteSongFromPlaylist")
    static let playbackFailed = Notification.Name("playbackFailed")
}

@MainActor
final class VideoPlayerViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var currentVideo: Song?
    @Published var isPlaying: Bool = false
    @Published var isMinimized: Bool = true
    @Published var areControlsVisible: Bool = true
    @Published var isAirPlayActive: Bool = false
    @Published var overlayOffset: CGSize = .zero
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var formattedCurrentTime: String = "00:00"
    @Published var formattedDuration: String = "00:00"
    
    // MARK: - Constants
    private let skipInterval: Double = 10.0
    private let controlsFadeDelay: TimeInterval = 5.0
    
    // MARK: - Private Properties
    private var _player: AVPlayer?
    var player: AVPlayer? { _player } // Public getter
    
    private var playerItem: AVPlayerItem?
    private var timeObserver: Any?
    private var controlsFadeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Public Methods
    
    func play(song: Song) async {
        print("🎵 VideoPlayerViewModel.play - Attempting to play: '\(song.title)'")

        // 1. Save current position before reset
        let savedOffset = overlayOffset
        
        // 2. Reset everything to a clean state
        reset()
        
        // 3. Restore the saved position
        overlayOffset = savedOffset

        // 4. Find the video file, with migration fallback
        let videoURL = await findVideoURL(for: song)

        guard let url = videoURL else {
            print("❌ VideoPlayerViewModel.play - CRITICAL FAILURE: No video URL found for song: \(song.title)")
            NotificationCenter.default.post(name: .playbackFailed, object: song)
            return
        }
        
        print("✅ VideoPlayerViewModel.play - Found video URL: \(url.path)")

        // If we migrated the file, update the database with the new path
        if url.path != song.filePath {
            await updateSongFilePath(songId: song.id, newPath: url.path)
        }
        
        // 3. Setup the new player and wait for it to be ready
        let newPlayerItem = AVPlayerItem(url: url)
        self.playerItem = newPlayerItem
        self._player = AVPlayer(playerItem: newPlayerItem)
        
        // 4. Wait for player to be ready to play, then show UI immediately
        await waitForPlayerReady(player: self._player!, playerItem: newPlayerItem)
        
        // 5. NOW set state - player is ready, video will appear immediately
        self.currentVideo = song
        self.isPlaying = true
        self.isMinimized = true
        
        // 6. Start playback and setup
        self._player?.play()
        setupTimeObserver()
        setupAirPlayMonitoring()
        showControls()
        
        // 7. Record song play in database for Songs Played Table
        await recordSongPlay(song: song)
        
        print("✅ VideoPlayerViewModel.play - Playback started for: '\(song.title)'")
    }

    func stop() {
        print("⏹️ VideoPlayerViewModel.stop - Stopping playback.")
        reset()
    }
    
    func deleteSong() {
        print("🗑️ VideoPlayerViewModel - Delete song requested for: '\(currentVideo?.title ?? "Unknown")'")
        let songToDelete = self.currentVideo
        stop()
        if let song = songToDelete {
            NotificationCenter.default.post(name: .deleteSongFromPlaylist, object: song)
        }
    }

    private func reset() {
        print("🔄 VideoPlayerViewModel.reset - Resetting player state to initial values.")

        _player?.pause()

        if let timeObserver = self.timeObserver {
            _player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()

        controlsFadeTimer?.invalidate()
        controlsFadeTimer = nil

        _player?.replaceCurrentItem(with: nil)
        _player = nil
        playerItem = nil
        
        // All state updates are now on the main actor
        currentVideo = nil
        isPlaying = false
        isMinimized = true
        areControlsVisible = true
        // CRITICAL: DO NOT reset overlayOffset - preserve user's dragged position
        // overlayOffset = .zero  <-- REMOVED TO PREVENT JUMPING BACK TO CENTER
        currentTime = 0
        duration = 0
        formattedCurrentTime = "00:00"
        formattedDuration = "00:00"
        
        print("✅ VideoPlayerViewModel.reset - State reset complete.")
    }
    
    private func findVideoURL(for song: Song) async -> URL? {
        if let url = song.videoURL, FileManager.default.fileExists(atPath: url.path) {
            print("📁 VideoPlayerViewModel.find - Found video at original path: \(url.path)")
            return url
        } else {
            print("⚠️ VideoPlayerViewModel.find - Video not at original path. Attempting migration/search...")
            return await attemptFileMigration(for: song)
        }
    }
    
    func togglePlayPause() {
        guard let player = _player else { return }
        if isPlaying { player.pause() } else { player.play() }
        isPlaying.toggle()
        showControls()
    }
    
    func toggleSize() {
        isMinimized.toggle()
        showControls()
        if !isMinimized {
            // When going fullscreen, position doesn't matter (fullscreen)
        } else {
            // When going back to minimized, CENTER the video as default
            overlayOffset = .zero
            print("📺 Video toggled to minimized - CENTERED at origin")
        }
    }
    
    func centerVideo() {
        overlayOffset = .zero
        showControls()
        print("🎯 Video manually centered")
    }
    
    func skipForward() async {
        guard let player = _player else { return }
        let newTime = CMTimeGetSeconds(player.currentTime()) + skipInterval
        await seek(to: newTime)
    }
    
    func skipBackward() async {
        guard let player = _player else { return }
        let newTime = max(0, CMTimeGetSeconds(player.currentTime()) - skipInterval)
        await seek(to: newTime)
    }
    
    func showControls() {
        areControlsVisible = true
        startControlsFadeTimer()
        // CRITICAL: Never reset overlayOffset when showing controls
        // The position should persist wherever the user dragged it
    }
    
    func seek(to time: Double) async {
        await _player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        showControls()
    }
    
    private func setupTimeObserver() {
        timeObserver = _player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let item = self.playerItem else { return }
                
                // This is more reliable than observing the status
                if item.duration.isValid && !item.duration.isIndefinite {
                    self.duration = item.duration.seconds
                }
                self.currentTime = time.seconds
                self.updateTimeDisplay()
            }
        }
        
        // CRITICAL: Auto-delete when video finishes playing
        setupVideoCompletionObserver()
    }
    
    private func setupVideoCompletionObserver() {
        guard let playerItem = playerItem else { return }
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                print("🏁 Video playback completed - Auto-deleting video")
                self.deleteSong() // This will stop the video and remove it from playlist
            }
        }
    }
    
    private func startControlsFadeTimer() {
        controlsFadeTimer?.invalidate()
        controlsFadeTimer = Timer.scheduledTimer(withTimeInterval: controlsFadeDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.areControlsVisible = false
                }
            }
        }
    }
    

    
    private func updateTimeDisplay() {
        formattedCurrentTime = formatTime(currentTime)
        formattedDuration = formatTime(duration)
    }
    
    private func formatTime(_ time: Double) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    deinit {
        // Synchronous cleanup only - no async calls allowed in deinit
        _player?.pause()

        if let timeObserver = self.timeObserver {
            _player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        NotificationCenter.default.removeObserver(self)
        controlsFadeTimer?.invalidate()
        controlsFadeTimer = nil

        _player?.replaceCurrentItem(with: nil)
        _player = nil
        playerItem = nil
    }
    
    private func attemptFileMigration(for song: Song) async -> URL? {
        let fileName = URL(fileURLWithPath: song.filePath).lastPathComponent
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        
        // Primary search locations - check Media directory first
        let searchDirectories = [
            mediaDirectory, // Check our permanent storage first
            documentsDirectory,
            documentsDirectory.appendingPathComponent("Inbox"),
            documentsDirectory.appendingPathComponent("tmp"),
            FileManager.default.temporaryDirectory,
            FileManager.default.temporaryDirectory.appendingPathComponent("com.erlingbreaden.KAust-Inbox")
        ]
        
        print("🔍 Searching for file: \(fileName)")
        
        for dir in searchDirectories {
            let potentialPath = dir.appendingPathComponent(fileName)
            print("🔍 Checking: \(potentialPath.path)")
            
            if FileManager.default.fileExists(atPath: potentialPath.path) {
                print("🎯 Found match at: \(potentialPath.path)")
                
                // If file is already in Media directory, use it directly
                if potentialPath.path.contains("/Media/") {
                    print("✅ File already in permanent storage: \(potentialPath.path)")
                    return potentialPath
                }
                
                // Otherwise, move it to Media directory
                let destinationURL = mediaDirectory.appendingPathComponent(fileName)
                
                do {
                    try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
                    
                    // If a file already exists at the destination, it might be the correct one
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                       print("✅ File already exists at destination, using it. No move needed.")
                       return destinationURL
                    }
                    
                    // Move file to permanent storage
                    try FileManager.default.moveItem(at: potentialPath, to: destinationURL)
                    print("✅ Successfully moved file to permanent storage: \(destinationURL.path)")
                    return destinationURL
                } catch {
                    print("❌ Failed to move file from \(potentialPath.path) to \(destinationURL.path): \(error)")
                    // If move fails, maybe we can still play from the found location
                    return potentialPath
                }
            }
        }
        
        print("❌ File '\(fileName)' not found in any standard location.")
        return nil
    }
    
    private func waitForPlayerReady(player: AVPlayer, playerItem: AVPlayerItem) async {
        print("⏳ Waiting for player to be ready...")
        
        // Simple polling approach - wait for player to be ready
        var attempts = 0
        let maxAttempts = 20 // 1 second total wait time
        
        while playerItem.status == .unknown && attempts < maxAttempts {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            attempts += 1
        }
        
        if playerItem.status == .readyToPlay {
            print("✅ Player is ready to play - showing UI now")
        } else if playerItem.status == .failed {
            print("❌ Player failed to load")
        } else {
            print("⚠️ Player status still unknown after waiting, proceeding anyway")
        }
    }
    
    private func updateSongFilePath(songId: String, newPath: String) async {
        print("🗄️ VideoPlayerViewModel - Updating database file path for song: \(songId)")
        let context = PersistenceController.shared.container.viewContext
        
        guard let uuid = UUID(uuidString: songId) else {
             print("❌ Invalid UUID string: \(songId)")
             return
        }
        
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", uuid as CVarArg)
        
        do {
            let songs = try context.fetch(request)
            if let songEntity = songs.first {
                songEntity.filePath = newPath
                if context.hasChanges {
                    try context.save()
                    print("✅ Updated song file path in database: \(newPath)")
                }
            } else {
                print("❌ Song not found in database for UUID: \(songId)")
            }
        } catch {
            print("❌ Failed to update song file path: \(error)")
        }
    }
    
    private func setupAirPlayMonitoring() {
        guard let player = _player else { return }
        
        // Initial state check
        isAirPlayActive = player.isExternalPlaybackActive
        print("📺 Initial AirPlay state: \(isAirPlayActive ? "Active" : "Inactive")")
        
        // Observe changes to external playback state
        player.publisher(for: \.isExternalPlaybackActive)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isActive in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    self.isAirPlayActive = isActive
                    print("📺 AirPlay state changed: \(isActive ? "Active" : "Inactive")")
                    
                    if isActive {
                        // Hide custom controls when AirPlay is active
                        self.areControlsVisible = false
                        print("🎛️ Custom controls hidden - AirPlay native controls active")
                    } else {
                        // Show custom controls when AirPlay is inactive
                        self.showControls()
                        print("🎛️ Custom controls restored - AirPlay disconnected")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Record a song play in the Songs Played Table
    private func recordSongPlay(song: Song) async {
        print("📊 Recording song play for Songs Played Table: '\(song.title)' by '\(song.artist)'")
        
        let context = PersistenceController.shared.container.viewContext
        
        do {
            try await context.perform {
                // Create a new PlayedSongEntity record
                let playedSong = PlayedSongEntity(context: context)
                playedSong.id = UUID()
                playedSong.playedDate = Date()
                playedSong.songTitleSnapshot = song.title
                playedSong.artistNameSnapshot = song.artist
                
                // Try to link to the actual SongEntity if it exists
                if let songUUID = UUID(uuidString: song.id) {
                    let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", songUUID as CVarArg)
                    
                    if let songEntity = try? context.fetch(request).first {
                        playedSong.song = songEntity
                        print("✅ Linked played song to SongEntity: \(songEntity.title ?? "Unknown")")
                    } else {
                        print("⚠️ Could not find SongEntity for ID: \(song.id)")
                    }
                }
                
                // Note: We're not setting the user relationship since user management 
                // is not fully implemented in the current app structure
                
                try context.save()
                print("✅ Successfully recorded song play in database")
            }
        } catch {
            print("❌ Failed to record song play: \(error)")
        }
    }
} 
