//
//  UserPreferencesServiceProtocol.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import Foundation

// Protocol for managing simple user preferences (likely using UserDefaults)
protocol UserPreferencesServiceProtocol {
    // Volume (0.0 to 1.0)
    var volume: Float { get set }
    
    // Mute State
    var isMuted: Bool { get set }
    
    // Default for showing lyrics (if applicable with LRC files later)
    var showLyricsByDefault: Bool { get set }
    
    // Current Kiosk Mode State
    var isKioskModeActive: Bool { get set }

    // Function to reset relevant settings to their defaults
    func resetToDefaults()
}
