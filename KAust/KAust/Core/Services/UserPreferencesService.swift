import Foundation
import AVFoundation

/// Concrete implementation of UserPreferencesServiceProtocol using UserDefaults for persistence
final class UserPreferencesService: UserPreferencesServiceProtocol {
    
    // MARK: - UserDefaults Keys
    private enum Keys {
        static let volume = "user_preferences_volume"
        static let isMuted = "user_preferences_is_muted"
        static let showLyricsByDefault = "user_preferences_show_lyrics_by_default"
        static let isKioskModeActive = "user_preferences_is_kiosk_mode_active"
    }
    
    // MARK: - UserDefaults Instance
    private let userDefaults: UserDefaults
    
    // MARK: - Initialization
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        
        // Set default values if they don't exist
        setDefaultValuesIfNeeded()
    }
    
    // MARK: - UserPreferencesServiceProtocol Implementation
    
    /// Master volume (0.0 to 1.0) - Default: 1.0 (100%)
    var volume: Float {
        get {
            let storedValue = userDefaults.float(forKey: Keys.volume)
            // If no value stored, return default of 1.0 (100%)
            return storedValue == 0.0 && !userDefaults.object(forKey: Keys.volume) is Float ? 1.0 : storedValue
        }
        set {
            let clampedValue = max(0.0, min(1.0, newValue))
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
        get {
            userDefaults.bool(forKey: Keys.isMuted)
        }
        set {
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
    
    /// Show lyrics by default
    var showLyricsByDefault: Bool {
        get {
            userDefaults.bool(forKey: Keys.showLyricsByDefault)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.showLyricsByDefault)
        }
    }
    
    /// Kiosk mode state
    var isKioskModeActive: Bool {
        get {
            userDefaults.bool(forKey: Keys.isKioskModeActive)
        }
        set {
            userDefaults.set(newValue, forKey: Keys.isKioskModeActive)
        }
    }
    
    /// Reset all preferences to their default values
    func resetToDefaults() {
        volume = 1.0           // 100%
        isMuted = false        // OFF
        showLyricsByDefault = false
        isKioskModeActive = false
        
        print("🔄 User preferences reset to defaults: Volume=100%, Mute=OFF")
    }
    
    // MARK: - Private Methods
    
    /// Set default values if keys don't exist
    private func setDefaultValuesIfNeeded() {
        // Only set defaults if the keys don't exist yet
        if userDefaults.object(forKey: Keys.volume) == nil {
            userDefaults.set(1.0, forKey: Keys.volume) // 100%
        }
        
        if userDefaults.object(forKey: Keys.isMuted) == nil {
            userDefaults.set(false, forKey: Keys.isMuted) // OFF
        }
        
        if userDefaults.object(forKey: Keys.showLyricsByDefault) == nil {
            userDefaults.set(false, forKey: Keys.showLyricsByDefault)
        }
        
        if userDefaults.object(forKey: Keys.isKioskModeActive) == nil {
            userDefaults.set(false, forKey: Keys.isKioskModeActive)
        }
        
        print("🎛️ UserPreferencesService initialized - Volume: \(Int(volume * 100))%, Muted: \(isMuted)")
    }
    
    /// Apply volume to the system audio session
    private func applyVolumeToSystem(_ volumeLevel: Float) {
        // Note: iOS restricts direct system volume control for security reasons
        // This method sets the AVAudioSession volume for the app's audio content
        // The actual system volume is controlled by the user via hardware buttons or Control Center
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Ensure we're in playback category for volume control
            if audioSession.category != .playback {
                try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
            }
            
            // For iOS, we primarily control the app's playback volume through AVPlayer
            // Post notification for VideoPlayerViewModel to apply volume
            NotificationCenter.default.post(
                name: NSNotification.Name("ApplyAppVolume"),
                object: nil,
                userInfo: ["volume": volumeLevel, "isMuted": isMuted]
            )
            
        } catch {
            print("⚠️ Failed to configure audio session for volume control: \(error)")
        }
    }
}

// MARK: - Convenience Extensions

extension UserPreferencesService {
    
    /// Get volume as percentage (0-100)
    var volumePercentage: Int {
        return Int(volume * 100)
    }
    
    /// Set volume using percentage (0-100)
    func setVolumePercentage(_ percentage: Int) {
        let clampedPercentage = max(0, min(100, percentage))
        volume = Float(clampedPercentage) / 100.0
    }
    
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
} 