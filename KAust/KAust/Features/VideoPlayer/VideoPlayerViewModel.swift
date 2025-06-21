import Foundation
import AVFoundation
import Combine
import CoreData
import SwiftUI
import UIKit

// MARK: - Notification Names
extension Notification.Name {
    static let deleteSongFromPlaylist = Notification.Name("deleteSongFromPlaylist")
    static let playbackFailed = Notification.Name("playbackFailed")
    static let requestFolderPicker = Notification.Name("requestFolderPicker")
    static let playNextSongFromPlaylist = Notification.Name("playNextSongFromPlaylist")
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
    @Published var formattedTimeRemaining: String = "-00:00"
    
    // MARK: - Performance Isolation for Smooth Video Playback
    @Published private(set) var isInPerformanceMode = false
    @Published private(set) var isDragging = false
    
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
    private var originalUpdateFrequency: TimeInterval = 0.5
    
    // MARK: - Deferred Database Operations
    private var deferredSongPlayRecord: Song?
    
    // MARK: - System-Level Video Prioritization
    nonisolated(unsafe) private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    nonisolated(unsafe) private var originalAudioCategory: AVAudioSession.Category?
    nonisolated(unsafe) private var originalAudioMode: AVAudioSession.Mode?
    nonisolated(unsafe) private var systemInterruptionObserver: NSObjectProtocol?
    nonisolated(unsafe) private var appLifecycleObservers: [NSObjectProtocol] = []
    nonisolated(unsafe) private var volumeObserver: NSObjectProtocol?
    
    // MARK: - Drag State Management

    /// Enter ultra-performance mode during video dragging for maximum smoothness
    func startDragging() async {
        guard !isDragging else { return }
        
        print("🎯 DRAG: Starting drag - entering ultra-performance mode")
        isDragging = true
        
        // Enter ultra-performance mode - even more aggressive than normal performance mode
        await enterUltraPerformanceMode()
    }

    /// Exit ultra-performance mode when dragging ends
    func stopDragging() async {
        guard isDragging else { return }
        
        print("🎯 DRAG: Ending drag - exiting ultra-performance mode")
        isDragging = false
        
        // Exit ultra-performance mode and return to normal performance mode
        await exitUltraPerformanceMode()
    }

    /// Ultra-performance mode for maximum smoothness during drag operations
    private func enterUltraPerformanceMode() async {
        print("🚀 ULTRA-PERFORMANCE: Entering ultra-performance mode for drag operations")
        
        // Suspend ALL observers and updates during drag
        await suspendTimeObserver()
        await suspendCoreDataObservers()
        
        // Notify all components to enter ultra-quiet mode
        NotificationCenter.default.post(name: .init("VideoUltraPerformanceModeEnabled"), object: nil)
        
        print("✅ ULTRA-PERFORMANCE: Maximum performance mode active - drag should be butter smooth")
    }

    /// Exit ultra-performance mode and return to normal performance mode
    private func exitUltraPerformanceMode() async {
        print("🔄 ULTRA-PERFORMANCE: Exiting ultra-performance mode")
        
        // Return to normal performance mode (restore minimal observers)
        if isInPerformanceMode {
            // Stay in normal performance mode but restore essential functions
            print("🔄 ULTRA-PERFORMANCE: Returning to normal performance mode")
        } else {
            // Exit all performance modes
            await restoreTimeObserver()
            await restoreCoreDataObservers()
        }
        
        // Notify all components to exit ultra-quiet mode
        NotificationCenter.default.post(name: .init("VideoUltraPerformanceModeDisabled"), object: nil)
        
        print("✅ ULTRA-PERFORMANCE: Returned to normal operation")
    }

    // MARK: - Performance Management Methods

    /// Enter high-performance mode for smooth video playback with 1000+ songs
    private func enterPerformanceMode() async {
        // Prevent duplicate performance mode activations
        guard !isInPerformanceMode else {
            print("🔄 PERFORMANCE: Already in performance mode - skipping duplicate activation")
            return
        }
        
        print("🚀 PERFORMANCE: Entering high-performance mode for smooth video playback")
        isInPerformanceMode = true
        
        // 1. Suspend all Core Data observers globally
        await suspendCoreDataObservers()
        
        // 2. Suspend time observer completely during performance mode
        await suspendTimeObserver()
        
        // 3. Notify UI components to reduce unnecessary updates
        NotificationCenter.default.post(name: .init("VideoPerformanceModeEnabled"), object: nil)
        
        // 4. NEW: Configure system-level video prioritization
        await configureSystemVideoProfile()
        await requestBackgroundVideoTask()
        await setupSystemInterruptionHandling()
        
        print("✅ PERFORMANCE: High-performance mode active - video should now be silky smooth")
    }

    /// Exit high-performance mode and restore normal operation
    private func exitPerformanceMode() async {
        // Prevent duplicate performance mode deactivations
        guard isInPerformanceMode else {
            print("🔄 PERFORMANCE: Already out of performance mode - skipping duplicate deactivation")
            return
        }
        
        print("🔄 PERFORMANCE: Exiting high-performance mode")
        isInPerformanceMode = false
        
        // 1. Restore time observer first
        await restoreTimeObserver()
        
        // 2. Restore Core Data observers
        await restoreCoreDataObservers()
        
        // 3. Process any deferred database operations
        await processDeferredDatabaseOperations()
        
        // 4. Notify UI components to resume normal updates
        NotificationCenter.default.post(name: .init("VideoPerformanceModeDisabled"), object: nil)
        
        // 5. NEW: Cleanup system-level video prioritization
        await cleanupSystemVideoProfile()
        await endBackgroundVideoTask()
        await removeSystemInterruptionHandling()
        
        print("✅ PERFORMANCE: Normal mode restored")
    }

    /// Suspend time observer completely during performance mode for maximum smoothness
    private func suspendTimeObserver() async {
        if let timeObserver = self.timeObserver {
            print("⏸️ PERFORMANCE: Suspending time observer for ultra-smooth video")
            _player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
    }

    /// Restore time observer after performance mode
    private func restoreTimeObserver() async {
        guard timeObserver == nil else { return }
        print("▶️ PERFORMANCE: Restoring time observer")
        await setupOptimizedTimeObserver()
    }

    /// Suspend Core Data observers that cause UI interference during video playback
    private func suspendCoreDataObservers() async {
        print("⏸️ PERFORMANCE: Suspending Core Data observers for smooth video")
        
        // Post notification to all ViewModels to suspend their Core Data observers
        NotificationCenter.default.post(name: .init("SuspendCoreDataObservers"), object: nil)
        
        // Small delay to ensure observers are suspended
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    /// Restore Core Data observers after video playback
    private func restoreCoreDataObservers() async {
        print("▶️ PERFORMANCE: Restoring Core Data observers")
        
        // Post notification to all ViewModels to restore their Core Data observers
        NotificationCenter.default.post(name: .init("RestoreCoreDataObservers"), object: nil)
        
        // Small delay to ensure observers are restored
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
    }

    /// Process any database operations that were deferred during performance mode
    private func processDeferredDatabaseOperations() async {
        print("🗄️ PERFORMANCE: Processing deferred database operations")
        
        // Process deferred song play recording
        if let song = deferredSongPlayRecord {
            await recordSongPlayImmediately(song: song)
            deferredSongPlayRecord = nil
        }
        
        print("✅ PERFORMANCE: Deferred database operations completed")
    }
    
    // MARK: - System-Level Video Prioritization Methods
    
    /// Configure iOS audio session and system settings for optimal video playback
    private func configureSystemVideoProfile() async {
        print("🎵 SYSTEM: Configuring audio session for video priority")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Save original settings for restoration
            originalAudioCategory = audioSession.category
            originalAudioMode = audioSession.mode
            
            // Configure for video playback with optimal performance
            try audioSession.setCategory(
                .playback,
                mode: .moviePlayback,
                options: [.allowAirPlay, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Activate the session
            try audioSession.setActive(true)
            
            print("✅ SYSTEM: Audio session configured for video priority")
            
        } catch {
            print("⚠️ SYSTEM: Failed to configure audio session: \(error.localizedDescription)")
            // Continue anyway - this is an optimization, not a requirement
        }
    }
    
    /// Request background task to continue video playback if app goes to background
    private func requestBackgroundVideoTask() async {
        print("📱 SYSTEM: Requesting background task for video continuity")
        
        // End any existing background task first
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        // Request new background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "VideoPlayback") { [weak self] in
            print("⏰ SYSTEM: Background task expiring - gracefully ending video")
            Task { @MainActor [weak self] in
                await self?.handleBackgroundTaskExpiration()
            }
        }
        
        if backgroundTaskID != .invalid {
            print("✅ SYSTEM: Background task granted for video continuity")
        } else {
            print("⚠️ SYSTEM: Background task denied - video may pause in background")
        }
    }
    
    /// Setup system interruption handling for calls, alarms, etc.
    private func setupSystemInterruptionHandling() async {
        print("📞 SYSTEM: Setting up interruption handling")
        
        // Remove existing observer
        if let observer = systemInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        
        // Observe audio session interruptions
        systemInterruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor [weak self] in
                await self?.handleSystemInterruption(notification)
            }
        }
        
        // Setup app lifecycle observers
        setupAppLifecycleObservers()
        
        print("✅ SYSTEM: Interruption handling configured")
    }
    
    /// Setup app lifecycle observers for background/foreground transitions
    private func setupAppLifecycleObservers() {
        // Clear existing observers
        appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appLifecycleObservers.removeAll()
        
        // App entering background
        let backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleAppEnterBackground()
            }
        }
        appLifecycleObservers.append(backgroundObserver)
        
        // App entering foreground
        let foregroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleAppEnterForeground()
            }
        }
        appLifecycleObservers.append(foregroundObserver)
        
        // App becoming active
        let activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleAppBecomeActive()
            }
        }
        appLifecycleObservers.append(activeObserver)
    }
    
         /// Setup volume control observer to listen for volume changes from settings
     private func setupVolumeObserver() {
         print("🔊 SYSTEM: Setting up volume observer...")
         
         // Remove existing observer
         if let observer = volumeObserver {
             NotificationCenter.default.removeObserver(observer)
             print("🔊 SYSTEM: Removed existing volume observer")
         }
         
         // Observe volume changes from UserPreferencesService
         volumeObserver = NotificationCenter.default.addObserver(
             forName: NSNotification.Name("ApplyAppVolume"),
             object: nil,
             queue: .main
         ) { [weak self] notification in
             print("🔊 SYSTEM: Volume observer received notification")
             Task { @MainActor [weak self] in
                 await self?.handleVolumeChange(notification)
             }
         }
         
         print("🔊 SYSTEM: Volume observer configured successfully")
     }
    
         /// Handle volume changes from settings
     private func handleVolumeChange(_ notification: Notification) async {
         print("🔊 VIDEO: Received volume change notification")
         
         guard let userInfo = notification.userInfo,
               let volume = userInfo["volume"] as? Float,
               let isMuted = userInfo["isMuted"] as? Bool else {
             print("❌ VIDEO: Invalid volume notification userInfo")
             return
         }
         
         print("🔊 VIDEO: Volume change details - Volume: \(Int(volume * 100))%, Muted: \(isMuted)")
         
         // Apply volume to current player
         if let player = _player {
             // Configure audio session first
             configureAudioSessionForVolumeControl()
             
             let effectiveVolume = isMuted ? 0.0 : volume
             player.volume = effectiveVolume
             
             print("🔊 VIDEO: Applied volume change - Volume: \(Int(volume * 100))%, Effective: \(Int(effectiveVolume * 100))%, Muted: \(isMuted)")
             print("🔊 VIDEO: AVPlayer.volume is now: \(player.volume)")
             
             // Debug: Double-check after a small delay
             DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                 print("🔊 VIDEO: Post-change check - AVPlayer.volume is: \(player.volume)")
                 
                 // Also log system volume for comparison
                 let audioSession = AVAudioSession.sharedInstance()
                 print("🔊 SYSTEM: Output volume is: \(audioSession.outputVolume)")
             }
         } else {
             print("❌ VIDEO: Cannot apply volume change - no player available")
         }
     }
     
     /// Apply current volume settings from UserPreferencesService to the player
     private func applyCurrentVolumeSettings() {
         guard let player = _player else { 
             print("❌ VIDEO: Cannot apply volume - no player available")
             return 
         }
         
         // First check and configure audio session for volume control
         configureAudioSessionForVolumeControl()
         
         // Get current volume settings from UserDefaults (same keys as UserPreferencesService)
         let userDefaults = UserDefaults.standard
         let volume = userDefaults.object(forKey: "user_preferences_volume") as? Float ?? 1.0
         let isMuted = userDefaults.bool(forKey: "user_preferences_is_muted")
         
         // Apply to player
         let effectiveVolume = isMuted ? 0.0 : volume
         player.volume = effectiveVolume
         
         print("🔊 VIDEO: Applied volume settings - Volume: \(Int(volume * 100))%, Muted: \(isMuted), Effective: \(Int(effectiveVolume * 100))%")
         print("🔊 VIDEO: AVPlayer.volume is now: \(player.volume)")
         
         // Debug: Check if volume was actually applied
         DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
             print("🔊 VIDEO: Post-check - AVPlayer.volume is: \(player.volume)")
         }
     }
     
     /// Configure audio session specifically for volume control
     private func configureAudioSessionForVolumeControl() {
         do {
             let audioSession = AVAudioSession.sharedInstance()
             
             // Try playback category which allows volume control
             try audioSession.setCategory(.playback, options: [.allowBluetoothA2DP, .allowAirPlay])
             try audioSession.setActive(true)
             
             print("🔊 AUDIO: Audio session configured for volume control")
             print("🔊 AUDIO: Category: \(audioSession.category), Options: \(audioSession.categoryOptions)")
             
         } catch {
             print("❌ AUDIO: Failed to configure audio session for volume control: \(error)")
         }
     }
    
    /// Handle system audio interruptions (calls, alarms, etc.)
    private func handleSystemInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("📞 SYSTEM: Interruption began - pausing video gracefully")
            if isPlaying {
                _player?.pause()
                isPlaying = false
            }
            
        case .ended:
            print("📞 SYSTEM: Interruption ended - checking if we should resume")
            
            // Check if we should resume
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("📞 SYSTEM: System suggests resume - restarting video")
                    
                    // Re-activate audio session and resume playback
                    do {
                        try AVAudioSession.sharedInstance().setActive(true)
                        _player?.play()
                        isPlaying = true
                    } catch {
                        print("⚠️ SYSTEM: Failed to resume after interruption: \(error)")
                    }
                }
            }
            
        @unknown default:
            print("⚠️ SYSTEM: Unknown interruption type")
        }
    }
    
    /// Handle app entering background
    private func handleAppEnterBackground() async {
        print("📱 SYSTEM: App entering background - maintaining video priority")
        
        // Keep video playing in background if possible
        // The background task we requested earlier should handle this
        
        // Reduce non-essential operations
        await suspendCoreDataObservers()
        
        print("✅ SYSTEM: Background transition optimized for video")
    }
    
    /// Handle app entering foreground
    private func handleAppEnterForeground() async {
        print("📱 SYSTEM: App entering foreground - restoring full performance")
        
        // Restore full functionality
        if isInPerformanceMode {
            // Restore essential observers for performance mode
            await restoreTimeObserver()
        } else {
            // Restore all observers if not in performance mode
            await restoreCoreDataObservers()
        }
        
        print("✅ SYSTEM: Foreground transition completed")
    }
    
    /// Handle app becoming active (after being inactive)
    private func handleAppBecomeActive() async {
        print("📱 SYSTEM: App became active - verifying video state")
        
        // Verify and restore video playback if needed
        if let player = _player, currentVideo != nil {
            // Ensure audio session is still active
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("⚠️ SYSTEM: Failed to reactivate audio session: \(error)")
            }
            
            // Restore playback state if it was interrupted
            if isPlaying && player.rate == 0 {
                print("📱 SYSTEM: Restoring interrupted playback")
                player.play()
            }
        }
        
        print("✅ SYSTEM: App active state verified")
    }
    
    /// Handle background task expiration gracefully
    private func handleBackgroundTaskExpiration() async {
        print("⏰ SYSTEM: Background task expiring - pausing video to preserve state")
        
        // Pause video gracefully
        _player?.pause()
        isPlaying = false
        
        // End the background task
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
        
        print("✅ SYSTEM: Background task ended gracefully")
    }
    
    /// Cleanup system video profile and restore original settings
    private func cleanupSystemVideoProfile() async {
        print("🎵 SYSTEM: Restoring original audio session settings")
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Restore original category and mode if we saved them
            if let originalCategory = originalAudioCategory,
               let originalMode = originalAudioMode {
                try audioSession.setCategory(originalCategory, mode: originalMode)
                print("✅ SYSTEM: Audio session restored to original settings")
            }
            
            // Clear saved settings
            originalAudioCategory = nil
            originalAudioMode = nil
            
        } catch {
            print("⚠️ SYSTEM: Failed to restore audio session: \(error.localizedDescription)")
            // Continue anyway - this is cleanup, not critical
        }
    }
    
    /// End background video task
    private func endBackgroundVideoTask() async {
        if backgroundTaskID != .invalid {
            print("📱 SYSTEM: Ending background video task")
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
            print("✅ SYSTEM: Background task ended")
        }
    }
    
    /// Remove system interruption handling
    private func removeSystemInterruptionHandling() async {
        print("📞 SYSTEM: Removing interruption handling")
        
        // Remove audio session interruption observer
        if let observer = systemInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            systemInterruptionObserver = nil
        }
        
        // Remove app lifecycle observers
        appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appLifecycleObservers.removeAll()
        
        // Remove volume observer
        if let observer = volumeObserver {
            NotificationCenter.default.removeObserver(observer)
            volumeObserver = nil
        }
        
        print("✅ SYSTEM: Interruption handling removed")
    }
    
    /// Synchronous cleanup for use in reset() and deinit
    nonisolated private func cleanupSystemResourcesSync() {
        // End background task synchronously
        if backgroundTaskID != .invalid {
            // Use MainActor.assumeIsolated since cleanup should run on main thread
            MainActor.assumeIsolated {
                UIApplication.shared.endBackgroundTask(backgroundTaskID)
            }
            backgroundTaskID = .invalid
        }
        
        // Remove observers synchronously
        if let observer = systemInterruptionObserver {
            NotificationCenter.default.removeObserver(observer)
            systemInterruptionObserver = nil
        }
        
        appLifecycleObservers.forEach { NotificationCenter.default.removeObserver($0) }
        appLifecycleObservers.removeAll()
        
        // Remove volume observer
        if let observer = volumeObserver {
            NotificationCenter.default.removeObserver(observer)
            volumeObserver = nil
        }
        
        // Reset audio session to default (best effort)
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient)
        } catch {
            // Ignore errors during cleanup
        }
        
        // Clear saved settings
        originalAudioCategory = nil
        originalAudioMode = nil
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
        formattedTimeRemaining = "-00:00"
        
        // Ensure performance mode is disabled when player is reset
        isInPerformanceMode = false
        
        // NEW: Cleanup system resources synchronously
        cleanupSystemResourcesSync()
        
        print("✅ VideoPlayerViewModel.reset - State reset complete.")
    }
    
    private func findVideoURL(for song: Song) async -> URL? {
        // CRITICAL: For external folder files, restore security access before attempting playback
        await restoreSecurityAccessIfNeeded(for: song)
        
        if let url = song.videoURL, FileManager.default.fileExists(atPath: url.path) {
            print("📁 VideoPlayerViewModel.find - Found video at original path: \(url.path)")
            return url
        } else {
            print("⚠️ VideoPlayerViewModel.find - Video not at original path. Attempting migration/search...")
            return await attemptFileMigration(for: song)
        }
    }
    
    /// Restore security-scoped access to external folders when needed for playback
    private func restoreSecurityAccessIfNeeded(for song: Song) async {
        // CRITICAL: Run file access operations in background to prevent UI blocking
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                // Background thread operations
                let filePath = song.filePath
                
                // Check if this looks like an external file path
                if !filePath.contains("/Documents/Media/") {
                    print("🔒 VideoPlayerVM: Attempting to restore security access for external file: \(filePath)")
                    
                    // Try to restore from saved bookmark for the parent folder
                    let folderPath = URL(fileURLWithPath: filePath).deletingLastPathComponent()
                    await self.restoreSecurityAccessToFolder(folderPath)
                }
            }
        }
    }
    
    /// Restore security-scoped access to a specific folder using saved bookmarks
    private func restoreSecurityAccessToFolder(_ folderURL: URL) async {
        print("🔍 VideoPlayerVM: Attempting to restore security access to: \(folderURL.path)")
        
        // Look for saved bookmarks in UserDefaults
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if key.hasPrefix("mp4FolderBookmark") {
                if let bookmarkData = userDefaults.data(forKey: key) {
                    do {
                        var isStale = false
                        let bookmarkedURL = try URL(
                            resolvingBookmarkData: bookmarkData,
                            options: .withoutUI,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale
                        )
                        
                        // Check if this bookmark matches the folder we need
                        if bookmarkedURL.path == folderURL.path || folderURL.path.hasPrefix(bookmarkedURL.path) {
                            if bookmarkedURL.startAccessingSecurityScopedResource() {
                                print("✅ VideoPlayerVM: Successfully restored security access to: \(bookmarkedURL.path)")
                                // Note: Keep access active for playback duration
                                return
                            } else {
                                print("❌ VideoPlayerVM: Failed to restore security access to bookmark: \(bookmarkedURL.path)")
                            }
                        }
                    } catch {
                        print("❌ VideoPlayerVM: Failed to resolve bookmark \(key): \(error)")
                    }
                }
            }
        }
        
        print("⚠️ VideoPlayerVM: No valid bookmark found for folder: \(folderURL.path)")
    }
    
    func togglePlayPause() {
        guard let player = _player else { return }
        if isPlaying { 
            player.pause() 
            isPlaying = false
            // When pausing, show controls and keep them visible (don't fade)
            showControlsWithoutFade()
        } else { 
            player.play() 
            isPlaying = true
            // When playing, show controls and start fade timer
            showControls()
        }
    }
    
    func toggleSize() {
        isMinimized.toggle()
        // Show controls appropriately based on play state
        if isPlaying {
            showControls() // Will fade if playing
        } else {
            showControlsWithoutFade() // Won't fade if paused
        }
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
        // Show controls appropriately based on play state
        if isPlaying {
            showControls() // Will fade if playing
        } else {
            showControlsWithoutFade() // Won't fade if paused
        }
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
    
    /// Show controls without starting fade timer (for paused state)
    func showControlsWithoutFade() {
        areControlsVisible = true
        cancelControlsFadeTimer()
        print("🎛️ Controls shown without fade (video paused)")
        // CRITICAL: Never reset overlayOffset when showing controls
        // The position should persist wherever the user dragged it
    }
    
    /// Cancel the controls fade timer
    private func cancelControlsFadeTimer() {
        controlsFadeTimer?.invalidate()
        controlsFadeTimer = nil
        print("⏰ Controls fade timer cancelled")
    }
    
    func seek(to time: Double) async {
        await _player?.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        // Show controls appropriately based on play state
        if isPlaying {
            showControls() // Will fade if playing
        } else {
            showControlsWithoutFade() // Won't fade if paused
        }
    }
    
    private func setupTimeObserver() {
        timeObserver = _player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let item = self.playerItem else { return }
                
                // Skip frequent updates during performance mode
                guard !self.isInPerformanceMode else { return }
                
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
    
    /// Setup optimized time observer for better performance during video playback
    private func setupOptimizedTimeObserver() async {
        // Remove existing time observer
        if let timeObserver = self.timeObserver {
            _player?.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        
        // Setup optimized time observer with reduced frequency for better performance
        timeObserver = _player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1.0, preferredTimescale: 600), // Reduced from 0.5 to 1.0 seconds
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self = self, let item = self.playerItem else { return }
                
                // Only update essential properties during performance mode
                if item.duration.isValid && !item.duration.isIndefinite {
                    self.duration = item.duration.seconds
                }
                self.currentTime = time.seconds
                
                // Throttled time display updates during performance mode
                if !self.isInPerformanceMode || Int(time.seconds) % 2 == 0 {
                    self.updateTimeDisplay()
                }
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
        
        // Only start fade timer if video is playing
        guard isPlaying else {
            print("⏰ Skipping controls fade timer - video is paused")
            return
        }
        
        controlsFadeTimer = Timer.scheduledTimer(withTimeInterval: controlsFadeDelay, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                // Double-check that video is still playing before fading controls
                guard self.isPlaying else {
                    print("⏰ Cancelled controls fade - video was paused")
                    return
                }
                withAnimation(.easeInOut(duration: 0.3)) {
                    self.areControlsVisible = false
                }
                print("🎛️ Controls faded after \(self.controlsFadeDelay) seconds")
            }
        }
        print("⏰ Started controls fade timer (\(controlsFadeDelay) seconds)")
    }
    
    private func updateTimeDisplay() {
        formattedCurrentTime = formatTime(currentTime)
        formattedDuration = formatTime(duration)
        
        // Calculate time remaining
        let remainingTime = max(0, duration - currentTime)
        formattedTimeRemaining = "-" + formatTime(remainingTime)
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
        
        // NEW: Cleanup system resources synchronously
        cleanupSystemResourcesSync()
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
                        // Show custom controls when AirPlay is inactive - appropriately based on play state
                        if self.isPlaying {
                            self.showControls() // Will fade if playing
                        } else {
                            self.showControlsWithoutFade() // Won't fade if paused
                        }
                        print("🎛️ Custom controls restored - AirPlay disconnected")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    /// Record a song play in the Songs Played Table with performance mode awareness
    private func recordSongPlay(song: Song) async {
        // PERFORMANCE: Defer database operations during performance mode to prevent jerky video
        if isInPerformanceMode {
            print("⏸️ PERFORMANCE: Deferring song play recording until performance mode ends")
            deferredSongPlayRecord = song
            return
        }
        
        // If not in performance mode, record immediately
        await recordSongPlayImmediately(song: song)
    }
    
    /// Immediately record a song play in the Songs Played Table
    private func recordSongPlayImmediately(song: Song) async {
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

    // MARK: - Public Methods

    func play(song: Song) async {
        print("🎵 VideoPlayerViewModel.play - Attempting to play: '\(song.title)'")
        
        // CRITICAL: Enter performance mode before starting video playback
        await enterPerformanceMode()

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
            await exitPerformanceMode() // Exit performance mode on failure
            return
        }
        
        print("✅ VideoPlayerViewModel.play - Found video URL: \(url.path)")

        // If we migrated the file, update the database with the new path (deferred)
        if url.path != song.filePath {
            await updateSongFilePath(songId: song.id, newPath: url.path)
        }
        
        // 3. Setup the new player and wait for it to be ready
        let newPlayerItem = AVPlayerItem(url: url)
        self.playerItem = newPlayerItem
        self._player = AVPlayer(playerItem: newPlayerItem)
        
        // CRITICAL: Setup volume observer and apply current volume settings
        setupVolumeObserver()
        applyCurrentVolumeSettings()
        
        // 4. Wait for player to be ready to play, then show UI immediately
        await waitForPlayerReady(player: self._player!, playerItem: newPlayerItem)
        
        // 5. NOW set state - player is ready, video will appear immediately
        self.currentVideo = song
        self.isPlaying = true
        self.isMinimized = true
        
        // 6. Start playback and setup with optimized observers (only if not in performance mode)
        self._player?.play()
        if !isInPerformanceMode {
            await setupOptimizedTimeObserver()
        }
        setupAirPlayMonitoring()
        showControls()
        
        // 7. PERFORMANCE: Defer song play recording until after performance mode ends
        await recordSongPlay(song: song)
        
        print("✅ VideoPlayerViewModel.play - Playback started for: '\(song.title)' with performance optimizations")
    }

    func stop() {
        print("⏹️ VideoPlayerViewModel.stop - Stopping playback.")
        
        // Exit performance mode before reset
        Task {
            await exitPerformanceMode()
        }
        
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
    
    func playNextSong() {
        print("⏭️ VideoPlayerViewModel - Next song requested")
        stop()
        // Notify the ContentView to play the next song from playlist
        NotificationCenter.default.post(name: .playNextSongFromPlaylist, object: nil)
    }
} 
