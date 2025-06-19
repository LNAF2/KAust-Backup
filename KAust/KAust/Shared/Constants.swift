//
//  Constants.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import SwiftUI // For CGFloat

// Global constants for UI layout and theming
enum AppConstants {

    // MARK: - Layout Dimensions
    enum Layout {
        static let outerUIPadding: CGFloat = 16.0
        static let panelCornerRadius: CGFloat = 8.0
        static let panelBorderWidth: CGFloat = 1.0
        static let defaultInternalPadding: CGFloat = 12.0 // For content inside panels
        static let defaultSpacing: CGFloat = 12.0         // Default spacing between elements
        static let controlsPanelHeight: CGFloat = 44.0
        static let titlePanelHeight: CGFloat = 60.0
        static let filterButtonWidth: CGFloat = 85.0
    }

    // MARK: - Animation & Timing
    enum Animation {
        static let defaultDuration: TimeInterval = 0.3
        static let playlistReorderFeedbackDuration: TimeInterval = 0.4
        static let videoControlsFadeDelay: TimeInterval = 8.0
    }
    
    // MARK: - File System
    enum FileSystem {
        static let minMP4SizeMB: Double = 5.0
        static let maxMP4SizeMB: Double = 200.0
        static let bytesInMegabyte: Double = 1024 * 1024
    }

    // Add other app-wide constants here as needed
    // For example:
    // enum API {
    //     static let baseURL = "https://api.example.com"
    // }
}

// MARK: - Processing Mode

/// Processing mode for file operations
enum ProcessingMode {
    case filePickerCopy    // Traditional: copy files to app storage
    case directFolderAccess // New: use files directly from their location
}
