//
//  UserPreferencesServiceProtocol.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import Foundation
import Combine

/// Protocol for managing all user preferences across the app
/// Centralizes UserDefaults access and provides reactive updates for SwiftUI
@MainActor
protocol UserPreferencesServiceProtocol {
    
    // MARK: - Audio Preferences
    
    /// Master volume (0.0 to 1.0) - Default: 1.0 (100%)
    var volume: Float { get set }
    
    /// Mute state - Default: false (OFF)
    var isMuted: Bool { get set }
    
    // MARK: - UI Preferences
    
    /// Enable swipe-to-delete functionality in song lists - Default: false
    var swipeToDeleteEnabled: Bool { get set }
    
    /// Show lyrics by default when available - Default: false
    var showLyricsByDefault: Bool { get set }
    
    // MARK: - Application State
    
    /// Current Kiosk Mode state - Default: false
    var isKioskModeActive: Bool { get set }
    
    // MARK: - File Management
    
    /// Store file bookmark for MP4 folder access
    /// - Parameter bookmark: Security-scoped bookmark data
    func setMP4FolderBookmark(_ bookmark: Data?)
    
    /// Retrieve MP4 folder bookmark
    /// - Returns: Security-scoped bookmark data if available
    func getMP4FolderBookmark() -> Data?
    
    /// Store security-scoped bookmark for individual file
    /// - Parameters:
    ///   - bookmark: Security-scoped bookmark data
    ///   - fileName: Unique identifier for the file
    func setFileBookmark(_ bookmark: Data, forFile fileName: String)
    
    /// Retrieve security-scoped bookmark for individual file
    /// - Parameter fileName: Unique identifier for the file
    /// - Returns: Security-scoped bookmark data if available
    func getFileBookmark(forFile fileName: String) -> Data?
    
    /// Remove security-scoped bookmark for individual file
    /// - Parameter fileName: Unique identifier for the file
    func removeFileBookmark(forFile fileName: String)
    
    /// Get all stored file bookmark keys
    /// - Returns: Array of file bookmark keys
    func getAllFileBookmarkKeys() -> [String]
    
    /// Clean up all file bookmarks
    func clearAllFileBookmarks()
    
    // MARK: - Session Management
    
    /// Clean up user preferences for factory reset
    /// - Parameter preserveAuthentication: Whether to preserve authentication data
    func cleanupForFactoryReset(preserveAuthentication: Bool)
    
    /// Reset all preferences to their default values
    func resetToDefaults()
    
    // MARK: - Convenience Methods
    
    /// Toggle mute state
    func toggleMute()
    
    /// Get volume icon name based on current state
    var volumeIconName: String { get }
    
    /// Get volume as percentage (0-100)
    var volumePercentage: Int { get }
    
    /// Set volume using percentage (0-100)
    /// - Parameter percentage: Volume percentage (0-100)
    func setVolumePercentage(_ percentage: Int)
    
    // MARK: - Reactive Support for SwiftUI
    
    /// Publisher for volume changes (for reactive UI updates)
    var volumePublisher: Published<Float>.Publisher { get }
    
    /// Publisher for mute state changes (for reactive UI updates)
    var mutePublisher: Published<Bool>.Publisher { get }
    
    /// Publisher for swipe-to-delete preference changes (for reactive UI updates)
    var swipeToDeletePublisher: Published<Bool>.Publisher { get }
}
