import SwiftUI
import Combine

/// ViewModel for managing Settings view state and interactions
@MainActor
class SettingsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isShowingFilePicker = false
    @Published var isProcessingFiles = false
    @Published var processingProgress: Double = 0.0
    @Published var processedFileCount = 0
    @Published var totalFileCount = 0
    
    // Settings states
    @Published var swipeToDeleteEnabled = false
    
    // Volume control states
    @Published var masterVolume: Float = 1.0
    @Published var isMuted: Bool = false
    
    // Error handling
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var isShowingErrorAlert = false
    
    // Toast notifications
    @Published var currentToast: ToastNotification?
    
    // MARK: - Dependencies
    
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let dataProviderService: DataProviderServiceProtocol
    private let mediaMetadataService: MediaMetadataServiceProtocol
    private let filePickerService: EnhancedFilePickerService
    private let userPreferencesService: UserPreferencesServiceProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var fileProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        errorHandlingService: ErrorHandlingServiceProtocol = ErrorHandlingService(),
        dataProviderService: DataProviderServiceProtocol = DataProviderService.shared,
        mediaMetadataService: MediaMetadataServiceProtocol = MediaMetadataService(),
        filePickerService: EnhancedFilePickerService = EnhancedFilePickerService(),
        userPreferencesService: UserPreferencesServiceProtocol = UserPreferencesService()
    ) {
        self.errorHandlingService = errorHandlingService
        self.dataProviderService = dataProviderService
        self.mediaMetadataService = mediaMetadataService
        self.filePickerService = filePickerService
        self.userPreferencesService = userPreferencesService
        
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auto-save settings when they change
        // Storage optimization setting removed as it was redundant
        // No settings currently need auto-save binding
    }
    
    private func loadSettings() {
        // Load volume settings from UserPreferencesService
        masterVolume = userPreferencesService.volume
        isMuted = userPreferencesService.isMuted
        
        print("🎛️ Settings loaded - Volume: \(Int(masterVolume * 100))%, Muted: \(isMuted)")
    }
    
    private func saveSettings() {
        // Volume settings are automatically saved by UserPreferencesService
        // No additional saving needed as UserDefaults are used directly
    }
    
    // MARK: - Actions
    
    func resetSettings() {
        swipeToDeleteEnabled = false  // Reset to default OFF state
        
        // Reset volume settings to defaults
        userPreferencesService.resetToDefaults()
        
        // Update published properties
        masterVolume = userPreferencesService.volume
        isMuted = userPreferencesService.isMuted
        
        // Clear file processing results
        filePickerService.clearResults()
        
        // Save the reset settings
        saveSettings()
        
        print("🔄 Settings reset completed - Volume: 100%, Mute: OFF")
    }
    
    // MARK: - Volume Control Actions
    
    /// Update master volume
    func setMasterVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        userPreferencesService.volume = clampedVolume
        masterVolume = clampedVolume
        
        print("🔊 Master volume set to: \(Int(clampedVolume * 100))%")
    }
    
    /// Toggle mute state
    func toggleMute() {
        userPreferencesService.toggleMute()
        isMuted = userPreferencesService.isMuted
        
        print("🔇 Mute toggled: \(isMuted ? "ON" : "OFF")")
    }
    
    /// Get volume icon name based on current state
    var volumeIconName: String {
        return userPreferencesService.volumeIconName
    }
    
    /// Get volume percentage for display
    var volumePercentage: Int {
        return userPreferencesService.volumePercentage
    } 
} 