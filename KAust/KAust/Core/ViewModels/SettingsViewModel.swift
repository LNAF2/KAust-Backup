//
//  SettingsViewModel.swift
//  KAust
//
//  Consolidated from embedded class in SettingsView.swift
//

import SwiftUI
import Combine
import CoreData

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isShowingFilePicker = false
    @Published var isShowingFolderPicker = false
    @Published var isShowingResults = false
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var isShowingErrorAlert = false
    @Published var isShowingSongsPlayedTable = false
    @Published var showingDeleteSongsPlayedAlert = false
    @Published var showingFactoryResetAlert = false
    
    // MODULAR SERVICES: Use centralized UserPreferencesService instead of direct UserDefaults
    private var userPreferencesService: any UserPreferencesServiceProtocol
    
    // Volume control properties - now backed by UserPreferencesService
    var masterVolume: Float {
        get { userPreferencesService.volume }
        set { userPreferencesService.volume = newValue }
    }
    
    var isMuted: Bool {
        get { userPreferencesService.isMuted }
        set { userPreferencesService.isMuted = newValue }
    }
    
    // Swipe-to-delete setting - now backed by UserPreferencesService
    var swipeToDeleteEnabled: Bool {
        get { userPreferencesService.swipeToDeleteEnabled }
        set { userPreferencesService.swipeToDeleteEnabled = newValue }
    }
    
    // Shared access to swipe-to-delete setting (for compatibility with existing usage)
    static var shared: SettingsViewModel = SettingsViewModel(userPreferencesService: UserPreferencesService())
    
    // File picker service
    @Published var filePickerService: EnhancedFilePickerService
    
    // DIRECT UI STATE MIRRORS FOR SWIFTUI REACTIVITY
    @Published var isProcessingFiles = false
    @Published var processingProgress: Double = 0.0
    @Published var processingFileName = ""
    @Published var processingBatch = ""
    @Published var processingFileCount = ""
    
    // Combine subscribers
    private var cancellables = Set<AnyCancellable>()
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var isFilePickerEnabled: Bool {
        filePickerService.processingState != .processing
    }
    
    var statusMessage: String {
        switch filePickerService.processingState {
        case .processing:
            let progress = filePickerService.batchProgress
            return "Processing batch \(progress.currentBatch)/\(progress.totalBatches) - \(progress.progressText)"
        case .paused:
            let progress = filePickerService.batchProgress
            return "Paused at \(progress.progressText)"
        case .completed:
            let stats = filePickerService.processingStats
            return "Completed: \(stats.successful) successful, \(stats.failed) failed, \(stats.duplicates) duplicates"
        case .cancelled:
            return "Processing cancelled"
        case .idle:
            if !filePickerService.results.isEmpty {
                let stats = filePickerService.processingStats
                return "Last run: \(stats.successful) successful, \(stats.failed) failed, \(stats.duplicates) duplicates"
            } else {
                return "Ready to process MP4 files"
            }
        }
    }
    
    init(userPreferencesService: any UserPreferencesServiceProtocol) {
        // Initialize services with dependency injection
        self.userPreferencesService = userPreferencesService
        self.filePickerService = EnhancedFilePickerService()
        
        // SETUP REACTIVE MONITORING FOR UI STATE
        setupProgressMonitoring()
        
        print("🎛️ Enhanced SettingsViewModel initialized with UserPreferencesService - Volume: \(Int(masterVolume * 100))%, Muted: \(isMuted), SwipeDelete: \(swipeToDeleteEnabled)")
    }
    
    private func setupProgressMonitoring() {
        // Monitor isProcessingFiles changes
        filePickerService.$isProcessingFiles
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isProcessing in
                print("🎯 REACTIVE SYNC: isProcessingFiles = \(isProcessing)")
                self?.isProcessingFiles = isProcessing
            }
            .store(in: &cancellables)
        
        // Monitor processing state changes for pause/resume handling
        filePickerService.$processingState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                print("🎯 REACTIVE SYNC: processingState = \(state)")
                // Keep isProcessingFiles true for paused state so UI stays visible
                if state == .paused {
                    self?.isProcessingFiles = true
                } else if state == .cancelled || state == .completed {
                    // For cancelled/completed, rely on the service's isProcessingFiles flag
                    // which should be set to false by the service
                }
            }
            .store(in: &cancellables)
        
        // Monitor currentProgressPercentage changes
        filePickerService.$currentProgressPercentage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] percentage in
                self?.processingProgress = percentage
            }
            .store(in: &cancellables)
        
        // Monitor currentFileName changes
        filePickerService.$currentFileName
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileName in
                self?.processingFileName = fileName
            }
            .store(in: &cancellables)
        
        // Monitor file count changes
        filePickerService.$currentFileCount
            .combineLatest(filePickerService.$totalFileCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current, total in
                self?.processingFileCount = "\(current)/\(total)"
            }
            .store(in: &cancellables)
        
        // Monitor batch changes
        filePickerService.$currentBatch
            .combineLatest(filePickerService.$totalBatches)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] current, total in
                self?.processingBatch = "Batch \(current) of \(total)"
            }
            .store(in: &cancellables)
        
        print("🎯 REACTIVE MONITORING SETUP COMPLETE")
    }
    
    // MARK: - Actions
    
    func openFilePicker() {
        guard filePickerService.processingState != .processing else { return }
        isShowingFilePicker = true
    }
    
    func selectMP4Folder() {
        print("📁 Opening folder picker...")
        
        // Simple guard - don't open if already processing
        guard filePickerService.processingState != .processing else { 
            print("❌ Cannot open folder picker while processing files")
            return 
        }
        
        // Clear any previous state
        filePickerService.clearResults()
        
        // CRITICAL FIX: Dismiss Settings first to prevent presentation conflict
        // Then present folder picker from ContentView level
        DispatchQueue.main.async { [weak self] in
            // Use environment dismiss if available, otherwise fallback to presentationMode
            self?.dismissSettingsAndShowFolderPicker()
        }
    }
    
    private func dismissSettingsAndShowFolderPicker() {
        // Dismiss Settings view first
        isShowingFolderPicker = false  // Reset in case it was stuck
        
        // Post notification to ContentView to handle folder picker presentation
        NotificationCenter.default.post(
            name: .requestFolderPicker,
            object: nil
        )
    }
    
    func handleFilesSelected(_ urls: [URL]) {
        print("📋 Processing \(urls.count) files")
        
        // Start processing
        filePickerService.handleFileSelection(urls)
        
        // Monitor completion
        monitorProcessingCompletion()
    }
    
    func handleFolderSelected(_ folderURL: URL) {
        print("📁 Folder selected: \(folderURL.path)")
        
        // Dismiss the folder picker
        isShowingFolderPicker = false
        
        // Check if we're already processing files
        if filePickerService.processingState == .processing {
            showSingleFolderEnforcement()
            return
        }
        
        // Process the selected folder
        Task {
            await processMP4FolderAccess(folderURL)
        }
    }
    
    /// Shows error when user tries to select multiple folders at once
    private func showSingleFolderEnforcement() {
        print("🚫 Enforcing single folder selection rule")
        
        errorAlert = ErrorAlertConfiguration(
            title: "Cannot Download from 2 or More Folders",
            message: "Select one folder.\n\nYou can only download from one folder at a time. Please wait for the current download to complete, or cancel it, then try selecting your new folder.",
            primaryButton: .default(Text("OK")) { [weak self] in
                self?.isShowingErrorAlert = false
                self?.errorAlert = nil
                // Take user back to previous screen (dismiss the folder picker if still shown)
                self?.isShowingFolderPicker = false
            }
        )
        isShowingErrorAlert = true
    }
    
    private func processMP4FolderAccess(_ folderURL: URL) async {
        print("📂 Processing folder: \(folderURL.path)")
        
        // Try to access the folder
        guard folderURL.startAccessingSecurityScopedResource() else {
            await MainActor.run {
                showError(FilePickerError.processingFailed(reason: "Cannot access folder: \(folderURL.lastPathComponent)"))
            }
            return
        }
        
        do {
            // Save bookmark for persistent access using UserPreferencesService
            let bookmark = try folderURL.bookmarkData(
                options: .suitableForBookmarkFile,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            userPreferencesService.setMP4FolderBookmark(bookmark)
            
            // Find MP4 files in the folder
            let mp4Files = await scanForMP4Files(in: folderURL)
            
            await MainActor.run {
                if mp4Files.isEmpty {
                    showError(FilePickerError.processingFailed(reason: "No MP4 files found in folder"))
                    folderURL.stopAccessingSecurityScopedResource()
                } else {
                    print("🎵 Found \(mp4Files.count) MP4 files")
                    
                    // Set up folder access mode
                    filePickerService.processingMode = .directFolderAccess
                    filePickerService.folderSecurityScope = folderURL
                    
                    // Process the files
                    handleFilesSelected(mp4Files)
                }
            }
            
        } catch {
            await MainActor.run {
                showError(error)
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
    }
    
    private func scanForMP4Files(in folderURL: URL) async -> [URL] {
        let fileManager = FileManager.default
        var mp4Files: [URL] = []
        
        // Get all files in the folder and subfolders
        if let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.nameKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) {
            // Collect all MP4 files
            let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
            mp4Files = allURLs.filter { $0.pathExtension.lowercased() == "mp4" }
        }
        
        print("📂 Found \(mp4Files.count) MP4 files in folder")
        
        // Sort alphabetically
        return mp4Files.sorted { $0.lastPathComponent < $1.lastPathComponent }
    }
    
    func handleFilePickerError(_ error: Error) {
        print("❌ File picker error: \(error.localizedDescription)")
        
        // Check if this is a crash-related error
        if error.localizedDescription.contains("Service Connection Interrupted") ||
           error.localizedDescription.contains("Remote view controller crashed") ||
           error.localizedDescription.contains("Connection invalid") {
            showFilePickerCrashError()
        } else {
            showError(error)
        }
    }
    
    private func showError(_ error: Error) {
        print("🚨 Showing error alert: \(error.localizedDescription)")
        errorAlert = ErrorAlertConfiguration(
            title: "Error",
            message: error.localizedDescription,
            primaryButton: .default(Text("OK")) { [weak self] in
                self?.isShowingErrorAlert = false
            }
        )
        isShowingErrorAlert = true
    }
    
    private func showFilePickerCrashError() {
        print("💥 File picker crashed - showing recovery instructions")
        errorAlert = ErrorAlertConfiguration(
            title: "File Picker System Error",
            message: "The system file picker crashed, likely due to selecting too many files at once. For large batches (500+ files), the app now automatically processes files in smaller chunks.\n\nTry selecting your files again - the improved system should handle large selections much better.",
            primaryButton: .default(Text("OK")) { [weak self] in
                self?.isShowingErrorAlert = false
            }
        )
        isShowingErrorAlert = true
    }
    
    func resetSettings() {
        userPreferencesService.resetToDefaults()
        filePickerService.clearResults()
        
        print("🔄 Settings reset completed using UserPreferencesService")
    }
    
    // MARK: - Volume Control Actions (Delegated to UserPreferencesService)
    
    /// Update master volume
    func setMasterVolume(_ volume: Float) {
        let clampedVolume = max(0.0, min(1.0, volume))
        
        userPreferencesService.volume = clampedVolume
        
        print("🔊 Master volume set to: \(Int(clampedVolume * 100))%")
    }
    
    /// Toggle mute state
    func toggleMute() {
        isMuted.toggle()
        
        print("🔇 Mute toggled: \(isMuted ? "ON" : "OFF")")
    }
    
    /// Get volume icon name based on current state
    var volumeIconName: String {
        userPreferencesService.volumeIconName
    }
    
    /// Get volume percentage for display
    var volumePercentage: Int {
        userPreferencesService.volumePercentage
    }
    
    // MARK: - File Processing Controls
    
    func pauseFileProcessing() {
        filePickerService.pauseProcessing()
    }
    
    func resumeFileProcessing() async {
        await filePickerService.resumeProcessing()
    }
    
    func cancelFileProcessing() {
        filePickerService.cancelProcessing()
    }
    
    func restartFileProcessing() async {
        await filePickerService.restartProcessing()
    }
    
    func clearAllFiles() async {
        await filePickerService.resetAndClearFiles()
    }
    
    func showAudioSettings() {
        // Placeholder
    }
    
    func showVolumeSettings() {
        // Placeholder
    }
    
    func showUserAccount() {
        // Placeholder
    }
    
    func showSongsPlayedTable() {
        print("📊 Showing Songs Played Table")
        isShowingSongsPlayedTable = true
    }
    
    func deleteSongsPlayedTable() {
        print("🗑️ Delete Songs Played Table requested")
        showingDeleteSongsPlayedAlert = true
    }
    
    func factoryReset() {
        print("🏭 Factory Reset requested")
        showingFactoryResetAlert = true
    }
    
    func confirmFactoryReset() async {
        print("🏭 Factory Reset confirmed - starting complete app cleanup")
        
        do {
            // Step 1: Perform Core Data and file system cleanup
            try await PersistenceController.shared.factoryReset()
            
            // Step 2: Clean up UserDefaults using UserPreferencesService (preserve authentication)
            await cleanupUserDefaultsWithService()
            
            // Step 3: Force UI refresh
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("FactoryResetCompleted"), object: nil)
            }
            
            print("✅ Factory Reset completed successfully")
            
        } catch {
            print("❌ Factory Reset failed: \(error)")
            await MainActor.run {
                errorAlert = ErrorAlertConfiguration(
                    title: "Factory Reset Failed",
                    message: "An error occurred during factory reset: \(error.localizedDescription)",
                    primaryButton: .default(Text("OK")) { [weak self] in
                        self?.isShowingErrorAlert = false
                    }
                )
                isShowingErrorAlert = true
            }
        }
    }
    
    private func cleanupUserDefaultsWithService() async {
        print("🧹 Cleaning up UserDefaults using UserPreferencesService...")
        
        // Use the centralized service for cleanup
        userPreferencesService.cleanupForFactoryReset(preserveAuthentication: true)
        
        print("✅ UserDefaults cleanup completed using UserPreferencesService")
    }
    
    func confirmDeleteSongsPlayedTable() async {
        print("🗑️ Executing delete of all songs played history")
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<PlayedSongEntity> = PlayedSongEntity.fetchRequest()
        
        do {
            let playedSongs = try context.fetch(request)
            print("📊 Found \(playedSongs.count) played songs to delete")
            
            for playedSong in playedSongs {
                context.delete(playedSong)
            }
            
            try context.save()
            print("✅ Successfully deleted all \(playedSongs.count) played songs from history")
        } catch {
            print("❌ Error deleting songs played history: \(error)")
            showError(FilePickerError.processingFailed(reason: "Failed to delete songs played history: \(error.localizedDescription)"))
        }
    }
    
    func monitorProcessingCompletion() {
        Task {
            // Wait for processing to start
            while filePickerService.processingState == .idle {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            // Monitor processing state
            while filePickerService.processingState == .processing {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // NOTE: No longer automatically showing results sheet
            // User must manually request results via "Show Report" button
            
            // Show error if there was one
            if let error = filePickerService.currentError {
                await MainActor.run {
                    showError(error)
                }
            }
        }
    }
} 
