//
//  FocusManager.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import SwiftUI // For FocusState and ObservableObject

// Enum to define all focusable fields in the app.
// We will add more cases to this enum as we build more UI elements that need focus.
enum FocusField: Hashable {
    // For SignInView (will be used later)
    // case signInUsername
    // case signInPassword
    
    // For MainView Controls Panel
    case searchBar
    
    // Add other cases here as needed, e.g.:
    // case settingsTextFieldXYZ
    // case playlistRenameField
}

@MainActor // Ensures that changes to published properties happen on the main thread
class FocusManager: ObservableObject {
    // The @Published property wrapper allows SwiftUI views to subscribe to changes
    // in the focusedField. When focusedField changes, views observing it will re-render.
    // We use an optional FocusField because initially, or at certain times,
    // no field might be focused.
    @Published var focusedField: FocusField? = nil

    // Function to programmatically change the focus to a specific field.
    // Views will use a @FocusState variable and bind it to this manager's focusedField.
    func requestFocus(on field: FocusField) {
        self.focusedField = field
    }

    // Function to clear the current focus.
    // This will set focusedField to nil, causing any bound @FocusState to lose focus.
    func clearFocus() {
        self.focusedField = nil
    }
    
    // You could add more sophisticated logic here later, e.g.,
    // - Moving to the next/previous focusable field in a sequence.
    // - Handling specific focus transitions based on user actions.
}
