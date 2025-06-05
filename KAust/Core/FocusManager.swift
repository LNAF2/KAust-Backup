import SwiftUI

/// Manages focus state for text fields across the app
@MainActor
final class FocusManager: ObservableObject {
    /// The currently focused field
    @Published var focusedField: FocusField?
    
    /// Available focus fields in the app
    enum FocusField: Hashable {
        case username
        case password
        case search
        case email
        case message
    }
    
    /// Sets focus to a specific field
    /// - Parameter field: The field to focus
    func focus(_ field: FocusField) {
        focusedField = field
    }
    
    /// Clears the current focus
    func clearFocus() {
        focusedField = nil
    }
} 