import Foundation
import AVFoundation
import Combine

/// Concrete implementation of UserPreferencesServiceProtocol using UserDefaults for persistence
/// Provides centralized preference management with reactive SwiftUI support
@MainActor
final class UserPreferencesService: ObservableObject, UserPreferencesServiceProtocol {
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        // Audio preferences
        static let volume = "user_preferences_volume"
        static let isMuted = "user_preferences_is_muted"
        
        // UI preferences
        static let swipeToDeleteEnabled = "swipeToDeleteEnabled"
        static let showLyricsByDefault = "user_preferences_show_lyrics_by_default"
        
        // Application state
        static let isKioskModeActive = "user_preferences_is_kiosk_mode_active"
        
        // File management
        static let mp4FolderBookmark = "mp4FolderBookmark"
        static let fileBookmarkPrefix = "fileBookmark_"
    }
    
    // MARK: - Published Properties for SwiftUI Reactivity
    
    @Published private var _volume: Float = 1.0
    @Published private var _isMuted: Bool = false
    @Published private var _swipeToDeleteEnabled: Bool = false
    
    // MARK: - UserDefaults Instance
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Load current values and set defaults if needed
        loadInitialValues()
        
        print("🎛️ Enhanced UserPreferencesService initialized - Volume: \(volumePercentage)%, Muted: \(isMuted), SwipeDelete: \(swipeToDeleteEnabled)")
    }
    
    // MARK: - Audio Preferences
    
    /// Master volume (0.0 to 1.0) - Default: 1.0 (100%)
    var volume: Float {
        get { _volume }
        set {
            let clampedValue = max(0.0, min(1.0, newValue))
            _volume = clampedValue
            userDefaults.set(clampedValue, forKey: Keys.volume)
            
            // Apply volume to system if not muted
            if !isMuted {
                applyVolumeToSystem(clampedValue)
            }
            
            print("🔊 Volume set to: \(Int(clampedValue * 100))%")
        }
    }
    
    /// Mute state - Default: false (OFF)
    var isMuted: Bool {
        get { _isMuted }
        set {
            _isMuted = newValue
            userDefaults.set(newValue, forKey: Keys.isMuted)
            
            // Apply mute state to system
            if newValue {
                // Mute: Set system volume to 0
                applyVolumeToSystem(0.0)
                print("🔇 Audio muted")
            } else {
                // Unmute: Restore stored volume
                applyVolumeToSystem(volume)
                print("🔊 Audio unmuted - volume restored to \(Int(volume * 100))%")
            }
        }
    }
    
    // MARK: - UI Preferences
    
    /// Enable swipe-to-delete functionality in song lists - Default: false
    var swipeToDeleteEnabled: Bool {
        get { _swipeToDeleteEnabled }
        set {
            _swipeToDeleteEnabled = newValue
            userDefaults.set(newValue, forKey: Keys.swipeToDeleteEnabled)
            print("🗑️ Swipe-to-delete \(newValue ? "enabled" : "disabled")")
        }
    }
    
    /// Show lyrics by default when available - Default: false
    var showLyricsByDefault: Bool {
        get {
            userDefaults.bool(forKey: Keys.showLyricsByDefault)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showLyricsByDefault)
            print("📝 Show lyrics by default: \(newValue)")
        }
    }
    
    // MARK: - Application State
    
    /// Current Kiosk Mode state - Default: false
    var isKioskModeActive: Bool {
        get {
            userDefaults.bool(forKey: Keys.isKioskModeActive)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.isKioskModeActive)
            print("🔒 Kiosk mode: \(newValue ? "active" : "inactive")")
        }
    }
    
    // MARK: - File Management
    
    /// Store file bookmark for MP4 folder access
    func setMP4FolderBookmark(_ bookmark: Data?) {
        if let bookmark = bookmark {
            userDefaults.set(bookmark, forKey: Keys.mp4FolderBookmark)
            print("📁 MP4 folder bookmark saved")
        } else {
            userDefaults.removeObject(forKey: Keys.mp4FolderBookmark)
            print("📁 MP4 folder bookmark removed")
        }
    }
    
    /// Retrieve MP4 folder bookmark
    func getMP4FolderBookmark() -> Data? {
        return userDefaults.data(forKey: Keys.mp4FolderBookmark)
    }
    
    /// Store security-scoped bookmark for individual file
    func setFileBookmark(_ bookmark: Data, forFile fileName: String) {
        let key = Keys.fileBookmarkPrefix + fileName
        userDefaults.set(bookmark, forKey: key)
        print("📄 File bookmark saved for: \(fileName)")
    }
    
    /// Retrieve security-scoped bookmark for individual file
    func getFileBookmark(forFile fileName: String) -> Data? {
        let key = Keys.fileBookmarkPrefix + fileName
        return userDefaults.data(forKey: key)
    }
    
    /// Remove security-scoped bookmark for individual file
    func removeFileBookmark(forFile fileName: String) {
        let key = Keys.fileBookmarkPrefix + fileName
        userDefaults.removeObject(forKey: key)
        print("🗑️ File bookmark removed for: \(fileName)")
    }
    
    /// Get all stored file bookmark keys
    func getAllFileBookmarkKeys() -> [String] {
        let allKeys = userDefaults.dictionaryRepresentation().keys
        return allKeys.filter { $0.hasPrefix(Keys.fileBookmarkPrefix) }
    }
    
    /// Clean up all file bookmarks
    func clearAllFileBookmarks() {
        let bookmarkKeys = getAllFileBookmarkKeys()
        for key in bookmarkKeys {
            userDefaults.removeObject(forKey: key)
        }
        // Also clear MP4 folder bookmark
        userDefaults.removeObject(forKey: Keys.mp4FolderBookmark)
        print("🧹 Cleared \(bookmarkKeys.count) file bookmarks and MP4 folder bookmark")
    }
    
    // MARK: - Session Management
    
    /// Clean up user preferences for factory reset
    func cleanupForFactoryReset(preserveAuthentication: Bool) {
        print("🧹 Cleaning up user preferences for factory reset...")
        
        let allKeys = Set(userDefaults.dictionaryRepresentation().keys)
        let preservedKeys: Set<String>
        
        if preserveAuthentication {
            preservedKeys = [
                // Preserve authentication data
                "is_authenticated", "user_id", "username", "user_role",
                "display_name", "login_date", "login_method"
            ]
        } else {
            preservedKeys = []
        }
        
        // Remove all keys except preserved ones
        for key in allKeys {
            if !preservedKeys.contains(key) {
                userDefaults.removeObject(forKey: key)
                print("  🗑️ Removed preference: \(key)")
            }
        }
        
        // Reset to defaults after cleanup
        resetToDefaults()
        
        print("✅ User preferences cleanup completed")
    }
    
    /// Reset all preferences to their default values
    func resetToDefaults() {
        volume = 1.0                    // 100%
        isMuted = false                 // OFF
        swipeToDeleteEnabled = false    // OFF
        showLyricsByDefault = false     // OFF
        isKioskModeActive = false       // OFF
        
        print("🔄 User preferences reset to defaults: Volume=100%, Mute=OFF, SwipeDelete=OFF")
    }
    
    // MARK: - Convenience Methods
    
    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()
    }
    
    /// Get volume icon name based on current state
    var volumeIconName: String {
        if isMuted {
            return "speaker.slash.fill"
        } else if volume == 0.0 {
            return "speaker.fill"
        } else if volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    /// Get volume as percentage (0-100)
    var volumePercentage: Int {
        return Int(volume * 100)
    }
    
    /// Set volume using percentage (0-100)
    func setVolumePercentage(_ percentage: Int) {
        let clampedPercentage = max(0, min(100, percentage))
        volume = Float(clampedPercentage) / 100.0
    }
    
    // MARK: - Reactive Support for SwiftUI
    
    /// Publisher for volume changes (for reactive UI updates)
    var volumePublisher: Published<Float>.Publisher {
        $_volume
    }
    
    /// Publisher for mute state changes (for reactive UI updates)
    var mutePublisher: Published<Bool>.Publisher {
        $_isMuted
    }
    
    /// Publisher for swipe-to-delete preference changes (for reactive UI updates)
    var swipeToDeletePublisher: Published<Bool>.Publisher {
        $_swipeToDeleteEnabled
    }
    
    // MARK: - Private Methods
    
    /// Load initial values from UserDefaults and set defaults if needed
    private func loadInitialValues() {
        // Set default values if they don't exist
        setDefaultValuesIfNeeded()
        
        // Load current values into published properties
        _volume = userDefaults.object(forKey: Keys.volume) as? Float ?? 1.0
        _isMuted = userDefaults.bool(forKey: Keys.isMuted)
        _swipeToDeleteEnabled = userDefaults.bool(forKey: Keys.swipeToDeleteEnabled)
        
        print("🎛️ Loaded preferences - Volume: \(volumePercentage)%, Muted: \(isMuted), SwipeDelete: \(swipeToDeleteEnabled)")
    }
    
    /// Set default values if keys don't exist
    private func setDefaultValuesIfNeeded() {
        // Audio preferences
        if userDefaults.object(forKey: Keys.volume) == nil {
            userDefaults.set(1.0, forKey: Keys.volume) // 100%
        }
        if userDefaults.object(forKey: Keys.isMuted) == nil {
            userDefaults.set(false, forKey: Keys.isMuted) // OFF
        }
        
        // UI preferences
        if userDefaults.object(forKey: Keys.swipeToDeleteEnabled) == nil {
            userDefaults.set(false, forKey: Keys.swipeToDeleteEnabled) // OFF
        }
        if userDefaults.object(forKey: Keys.showLyricsByDefault) == nil {
            userDefaults.set(false, forKey: Keys.showLyricsByDefault) // OFF
        }
        
        // Application state
        if userDefaults.object(forKey: Keys.isKioskModeActive) == nil {
            userDefaults.set(false, forKey: Keys.isKioskModeActive) // OFF
        }
    }
    
    /// Apply volume to the system audio session
    private func applyVolumeToSystem(_ volumeLevel: Float) {
        Task { @MainActor in
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyAppVolume"),
                object: nil,
                userInfo: ["volume": volumeLevel, "isMuted": isMuted]
            )
        }
    }
}

 