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
    @Published var storageOptimizationEnabled = false
    
    // Error handling
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var isShowingErrorAlert = false
    
    // Toast notifications
    @Published var currentToast: ToastNotification?
    
    // MARK: - Dependencies
    
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let dataProviderService: DataProviderServiceProtocol
    private let mediaMetadataService: MediaMetadataServiceProtocol
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    private var fileProcessingTask: Task<Void, Never>?
    
    // MARK: - Computed Properties
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var isFilePickerEnabled: Bool {
        !isProcessingFiles
    }
    
    var processingStatusText: String {
        if isProcessingFiles {
            return "Processing \(processedFileCount) of \(totalFileCount) files..."
        } else if processedFileCount > 0 {
            return "Completed processing \(processedFileCount) files"
        } else {
            return "Ready to process files"
        }
    }
    
    // MARK: - Initialization
    
    init(
        errorHandlingService: ErrorHandlingServiceProtocol = ErrorHandlingService(),
        dataProviderService: DataProviderServiceProtocol = DataProviderService.shared,
        mediaMetadataService: MediaMetadataServiceProtocol = MediaMetadataService()
    ) {
        self.errorHandlingService = errorHandlingService
        self.dataProviderService = dataProviderService
        self.mediaMetadataService = mediaMetadataService
        
        setupBindings()
        loadSettings()
    }
    
    deinit {
        fileProcessingTask?.cancel()
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
    
    func openFilePicker() {
        guard !isProcessingFiles else { return }
        isShowingFilePicker = true
    }
    
    func processSelectedFiles(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else { return }
        
        // Reset processing state
        processedFileCount = 0
        totalFileCount = fileURLs.count
        processingProgress = 0.0
        isProcessingFiles = true
        
        // Start processing files
        fileProcessingTask = Task {
            await processFiles(fileURLs)
        }
    }
    
    private func processFiles(_ fileURLs: [URL]) async {
        var successCount = 0
        var errorCount = 0
        
        for (index, fileURL) in fileURLs.enumerated() {
            // Update progress
            processingProgress = Double(index) / Double(fileURLs.count)
            
            do {
                // Extract metadata
                let metadata = try await mediaMetadataService.extractMetadata(from: fileURL)
                
                // Store in data provider
                try await dataProviderService.storeMetadata(metadata, for: fileURL)
                
                successCount += 1
                processedFileCount += 1
                
                // Show success toast for individual files if enabled
                if notificationsEnabled {
                    showToast(.success("Processed \(fileURL.lastPathComponent)"))
                }
                
            } catch {
                errorCount += 1
                
                // Handle individual file errors
                handleFileProcessingError(error, for: fileURL)
            }
            
            // Small delay to show progress
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // Final progress update
        processingProgress = 1.0
        isProcessingFiles = false
        
        // Show completion toast
        if successCount > 0 {
            showToast(.success("Successfully processed \(successCount) files"))
        }
        
        if errorCount > 0 {
            showToast(.error("Failed to process \(errorCount) files"))
        }
    }
    
    private func handleFileProcessingError(_ error: Error, for fileURL: URL) {
        let fileName = fileURL.lastPathComponent
        
        // Log error
        print("Error processing file \(fileName): \(error)")
        
        // For non-critical errors, just show a toast
        if error is MediaMetadataError {
            showToast(.error("Error processing \(fileName)"))
        } else {
            // For unexpected errors, show alert
            let alertConfig = errorHandlingService.createErrorAlert(for: error) { [weak self] in
                // Retry single file
                Task {
                    await self?.processFiles([fileURL])
                }
            }
            
            errorAlert = alertConfig
            isShowingErrorAlert = true
        }
    }
    
    func cancelFileProcessing() {
        fileProcessingTask?.cancel()
        isProcessingFiles = false
        processingProgress = 0.0
        
        showToast(.warning("File processing cancelled"))
    }
    
    func resetSettings() {
        // Reset to defaults
        notificationsEnabled = true
        autoProcessingEnabled = true
        storageOptimizationEnabled = false
        
        // Save defaults
        saveSettings()
        
        showToast(.info("Settings reset to defaults"))
    }
    
    func manageDownloads() {
        // This will be implemented in a future step
        showToast(.info("Download management coming soon"))
    }
    
    func showAudioSettings() {
        // This will be implemented in a future step
        showToast(.info("Audio settings coming soon"))
    }
    
    func showVolumeSettings() {
        // This will be implemented in a future step
        showToast(.info("Volume settings coming soon"))
    }
    
    func showUserAccount() {
        // This will be implemented in a future step
        showToast(.info("User account management coming soon"))
    }
    
    // MARK: - Toast Management
    
    private func showToast(_ toast: ToastNotification) {
        currentToast = toast
        
        // Auto-dismiss after delay
        Task {
            try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
            if currentToast?.id == toast.id {
                currentToast = nil
            }
        }
    }
    
    func dismissToast() {
        currentToast = nil
    }
    
    // MARK: - Error Handling
    
    func dismissErrorAlert() {
        isShowingErrorAlert = false
        errorAlert = nil
    }
}

// MARK: - Mock for Previews

extension SettingsViewModel {
    static func mock() -> SettingsViewModel {
        let viewModel = SettingsViewModel()
        viewModel.processedFileCount = 5
        viewModel.totalFileCount = 10
        viewModel.processingProgress = 0.5
        return viewModel
    }
} 