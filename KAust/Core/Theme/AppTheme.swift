import SwiftUI

/// Defines the color palette and theme for the KaraokeAustralia app.
struct AppTheme {

    // MARK: - Left Panel Colors
    static let leftPanelBackground = Color("LeftPanelBg") // Main purple background
    static let leftPanelAccent = Color("LeftPanelAccent") // Border/accent purple
    static let leftPanelTextPrimary = Color("LeftPanelTextPrimary") // Main text
    static let leftPanelTextSecondary = Color("LeftPanelTextSecondary") // Subtext
    static let leftPanelListBackground = Color("LeftPanelListBg").opacity(0.1) // Light purple

    // MARK: - Right Panel Colors
    static let rightPanelBackground = Color("RightPanelBg") // Main bright red background
    static let rightPanelAccent = Color("RightPanelAccent") // Border/accent bright red
    static let rightPanelTextPrimary = Color("RightPanelTextPrimary") // Main text
    static let rightPanelTextSecondary = Color("RightPanelTextSecondary") // Subtext (lighter or gray)
    static let rightPanelListBackground = Color("RightPanelListBg").opacity(0.1) // Light red
    
    // For list items in the right panel (playlist rows)
    static let rightPanelItemBackground: Color = {
        // Try to use a named color, fallback to a very light red with opacity
        if let color = UIColor(named: "RightPanelItemBg") {
            return Color(color)
        } else {
            return Color.red.opacity(0.06) // fallback: very light red
        }
    }()

    // For text in playlist rows
    static let rightPanelText: Color = rightPanelTextPrimary

    // MARK: - Video Player & Lyrics
    static let videoPlayerControls = Color.white
    static let videoPlayerProgressTrack = Color.gray.opacity(0.5)
    static let videoPlayerProgressFill = Color.white
    static let lyricsBackground = Color.black.opacity(0.6)
    static let lyricsText = Color.white
    static let lyricsHighlight = Color.yellow

    // MARK: - Settings Window
    static let settingsBackground = Color.black
    static let settingsText = Color.white
    static let settingsResetIconBlue = Color("SettingsResetBlue")

    // MARK: - ScrollBar Colors (for custom scrollbars)
    static let leftPanelScrollbarThumb = Color("LeftPanelAccent").opacity(0.7)
    static let leftPanelScrollbarTrack = Color("LeftPanelAccent").opacity(0.3)
    static let rightPanelScrollbarThumb = Color("RightPanelAccent").opacity(0.7)
    static let rightPanelScrollbarTrack = Color("RightPanelAccent").opacity(0.3)

    // MARK: - General UI
    static let appBackground = Color("AppBackground")
} 