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
    @Published var notificationsEnabled = true
    @Published var autoProcessingEnabled = true
    @Published var storageOptimizationEnabled = true
    @Published var swipeToDeleteEnabled = false
    
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
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var fileProcessingTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init(
        errorHandlingService: ErrorHandlingServiceProtocol = ErrorHandlingService(),
        dataProviderService: DataProviderServiceProtocol = DataProviderService.shared,
        mediaMetadataService: MediaMetadataServiceProtocol = MediaMetadataService(),
        filePickerService: EnhancedFilePickerService = EnhancedFilePickerService()
    ) {
        self.errorHandlingService = errorHandlingService
        self.dataProviderService = dataProviderService
        self.mediaMetadataService = mediaMetadataService
        self.filePickerService = filePickerService
        
        setupBindings()
        loadSettings()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Auto-save settings when they change
        Publishers.CombineLatest3(
            $notificationsEnabled,
            $autoProcessingEnabled,
            $storageOptimizationEnabled
        )
        .dropFirst() // Skip initial values
        .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
        .sink { [weak self] _, _, _ in
            self?.saveSettings()
        }
        .store(in: &cancellables)
    }
    
    private func loadSettings() {
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        autoProcessingEnabled = UserDefaults.standard.bool(forKey: "autoProcessingEnabled")
        storageOptimizationEnabled = UserDefaults.standard.bool(forKey: "storageOptimizationEnabled")
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(autoProcessingEnabled, forKey: "autoProcessingEnabled")
        UserDefaults.standard.set(storageOptimizationEnabled, forKey: "storageOptimizationEnabled")
    }
    
    // MARK: - Actions
    
    func resetSettings() {
        notificationsEnabled = true
        autoProcessingEnabled = true
        storageOptimizationEnabled = true
        swipeToDeleteEnabled = false  // Reset to default OFF state
        
        // Clear file processing results
        filePickerService.clearResults()
        
        // Save the reset settings
        saveSettings()
    } 
} 