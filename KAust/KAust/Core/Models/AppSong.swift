//
//  AppSong.swift
//  KAust
//
//  Created by Erling Breaden on 5/6/2025.
//

import Foundation
import SwiftUI

struct AppSong: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let artist: String
    let duration: String
}

extension AppSong {
    var durationSeconds: TimeInterval {
        let parts = duration.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2 else { return 0 }
        return parts[0] * 60 + parts[1]
    }
}

// MARK: - Focus Manager

/// Centralized focus manager for the entire app - single source of truth
@MainActor
final class FocusManager: ObservableObject {
    /// The currently focused field
    @Published var focusedField: FocusField?
    
    /// Track if keyboard should dismiss accessories
    @Published var dismissKeyboardAccessories = false
    
    /// Prevent multiple simultaneous focus operations
    private var isProcessingFocusChange = false
    
    init() {
        // Listen for app state changes to force dismiss keyboard
        NotificationCenter.default.addObserver(
            forName: UIApplication.willResignActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.forceKeyboardDismiss()
            }
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    /// All available focus fields in the app
    enum FocusField: Hashable, CaseIterable {
        // Authentication fields
        case username
        case password
        
        // Search fields
        case search
        case searchBar
        
        // Other fields
        case email
        case message
    }
    
    /// Sets focus to a specific field with constraint conflict prevention
    /// - Parameter field: The field to focus
    func focus(_ field: FocusField) {
        guard !isProcessingFocusChange else { return }
        
        isProcessingFocusChange = true
        
        // First clear any existing focus to prevent conflicts
        clearFocusImmediately()
        
        // Small delay to allow constraint cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.focusedField = field
            self.dismissKeyboardAccessories = false
            self.isProcessingFocusChange = false
        }
    }
    
    /// Clears the current focus with aggressive constraint cleanup
    func clearFocus() {
        guard !isProcessingFocusChange else { return }
        
        isProcessingFocusChange = true
        dismissKeyboardAccessories = true
        
        // Immediate focus clearing to prevent constraint buildup
        focusedField = nil
        
        // Extended delay for complete keyboard dismissal
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            self.dismissKeyboardAccessories = false
            self.isProcessingFocusChange = false
        }
    }
    
    /// Immediately clear focus without delays (for internal use)
    private func clearFocusImmediately() {
        focusedField = nil
        dismissKeyboardAccessories = true
    }
    
    /// Moves focus to the next logical field
    /// - Parameter from: Current field
    func focusNext(from currentField: FocusField) {
        switch currentField {
        case .username:
            focus(.password)
        case .password:
            clearFocus() // Submit action should handle this
        case .search, .searchBar:
            clearFocus()
        default:
            clearFocus()
        }
    }
    
    /// Force dismiss all keyboard-related accessories with complete cleanup
    func forceKeyboardDismiss() {
        isProcessingFocusChange = true
        dismissKeyboardAccessories = true
        focusedField = nil
        
        // Extended cleanup to ensure all constraints are resolved
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.dismissKeyboardAccessories = false
            self.isProcessingFocusChange = false
        }
    }
}
