//
//  SettingsViewModel.swift
//  KAust
//
//  Consolidated from embedded class in SettingsView.swift
//

import SwiftUI
import Combine
import CoreData
import AVFoundation

// MARK: - Error Alert Configuration
struct ErrorAlertConfiguration {
    let title: String
    let message: String
    let primaryButton: Alert.Button
    let secondaryButton: Alert.Button?
    
    init(
        title: String,
        message: String,
        primaryButton: Alert.Button,
        secondaryButton: Alert.Button? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryButton = primaryButton
        self.secondaryButton = secondaryButton
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    // MARK: - Dependencies
    private var userPreferencesService: UserPreferencesServiceProtocol
    
    // MARK: - Published Properties
    @Published var isShowingErrorAlert = false
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var showingFactoryResetAlert = false
    @Published var showingDeleteSongsPlayedAlert = false
    @Published var isShowingSongsPlayedTable = false
    
    // MARK: - App Info
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    
    // MARK: - Initialization
    init(userPreferencesService: UserPreferencesServiceProtocol) {
        self.userPreferencesService = userPreferencesService
    }
    
    // MARK: - Volume Control Bindings
    var isMuted: Bool {
        get { userPreferencesService.isMuted }
        set { Task { @MainActor in userPreferencesService.isMuted = newValue } }
    }
    
    var masterVolume: Float {
        get { userPreferencesService.volume }
        set { Task { @MainActor in userPreferencesService.volume = newValue } }
    }
    
    // MARK: - Service Update
    func updateUserPreferencesService(_ service: UserPreferencesServiceProtocol) {
        Task { @MainActor in
            self.userPreferencesService = service
            objectWillChange.send()
        }
    }
    
    // MARK: - Settings Management
    func resetSettings() {
        print("🔄 Resetting settings to defaults")
        userPreferencesService.resetToDefaults()
        
        // Update local state
        isMuted = userPreferencesService.isMuted
        masterVolume = userPreferencesService.volume
    }
    
    // MARK: - Volume Control
    func setMasterVolume(_ volume: Float) {
        Task { @MainActor in
            userPreferencesService.volume = volume
        }
    }
    
    func toggleMute() {
        Task { @MainActor in
            userPreferencesService.toggleMute()
        }
    }
    
    var volumeIconName: String {
        userPreferencesService.volumeIconName
    }
    
    var volumePercentage: Int {
        userPreferencesService.volumePercentage
    }
    
    // MARK: - Core Data Management
    func clearAllCoreDataSongs() async {
        do {
            // Clear all songs from Core Data
            let context = PersistenceController.shared.container.viewContext
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "SongEntity")
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
            try context.save()
            print("✅ Successfully cleared all songs from Core Data")
        } catch {
            print("❌ Failed to clear songs: \(error.localizedDescription)")
            await MainActor.run {
                showError(error)
            }
        }
    }
    
    private func cleanupUserDefaultsWithService() async {
        userPreferencesService.resetToDefaults()
    }
    
    // MARK: - Error Handling
    private func showError(_ error: Error) {
        Task { @MainActor in
            errorAlert = ErrorAlertConfiguration(
                title: "Error",
                message: error.localizedDescription,
                primaryButton: .default(Text("OK")) { [weak self] in
                    self?.isShowingErrorAlert = false
                    self?.errorAlert = nil
                }
            )
            isShowingErrorAlert = true
        }
    }
} 
