//
//  SettingsView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI
import Combine
import UniformTypeIdentifiers
import AVFoundation
import CoreData

// Note: DataProviderService should be available since DataProviderServiceProtocol is already imported via existing protocol file structure

// MARK: - File Validation Errors

enum FileValidationError: LocalizedError {
    case invalidFileSize
    case invalidFileType
    case fileNotFound
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidFileSize:
            return "File size must be between 5MB and 150MB"
        case .invalidFileType:
            return "Only MP4 files are supported"
        case .fileNotFound:
            return "File could not be found"
        case .permissionDenied:
            return "Permission denied to access file"
        }
    }
}

// MARK: - File Picker Components

/// File picker view for selecting MP4 files
struct FilePickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFilesSelected: ([URL]) -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.mpeg4Movie],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.modalPresentationStyle = .formSheet
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FilePickerView
        
        init(_ parent: FilePickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            parent.onFilesSelected(urls)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            parent.isPresented = false
            parent.onFilesSelected([url])
        }
    }
}

/// Progress tracking for file processing operations
struct FileProcessingProgress {
    let totalFiles: Int
    let processedFiles: Int
    let currentFileName: String?
    let currentProgress: Double
    let overallProgress: Double
    let isComplete: Bool
    
    init(
        totalFiles: Int,
        processedFiles: Int,
        currentFileName: String? = nil,
        currentProgress: Double = 0.0
    ) {
        self.totalFiles = totalFiles
        self.processedFiles = processedFiles
        self.currentFileName = currentFileName
        self.currentProgress = currentProgress
        self.overallProgress = totalFiles > 0 ? Double(processedFiles) / Double(totalFiles) : 0.0
        self.isComplete = processedFiles >= totalFiles
    }
}

/// Simple metadata structure for demonstration
struct SimpleMetadata {
    let duration: TimeInterval
    let fileSize: Int64
    let videoDimensions: CGSize?
}

/// Result of file processing operation
struct FileProcessingResult {
    let url: URL
    let filename: String
    let isSuccess: Bool
    let metadata: SimpleMetadata?
    let error: Error?
    let processingTime: TimeInterval
    
    init(url: URL, metadata: SimpleMetadata?, error: Error?, processingTime: TimeInterval) {
        self.url = url
        self.filename = url.lastPathComponent
        self.isSuccess = error == nil
        self.metadata = metadata
        self.error = error
        self.processingTime = processingTime
    }
}

/// Simple file picker service for handling file operations
@MainActor
class FilePickerService: ObservableObject {
    @Published var isProcessing = false
    @Published var progress = FileProcessingProgress(totalFiles: 0, processedFiles: 0)
    @Published var results: [FileProcessingResult] = []
    @Published var currentError: Error?
    
    // Direct Core Data access for immediate functionality
    private let persistenceController = PersistenceController.shared
    
    func processFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        
        isProcessing = true
        currentError = nil
        results = []
        progress = FileProcessingProgress(totalFiles: urls.count, processedFiles: 0)
        
        for (index, url) in urls.enumerated() {
            let filename = url.lastPathComponent
            
            // Update progress
            progress = FileProcessingProgress(
                totalFiles: urls.count,
                processedFiles: index,
                currentFileName: filename,
                currentProgress: 0.0
            )
            
            await processFile(url, at: index)
        }
        
        // Final progress update
        progress = FileProcessingProgress(
            totalFiles: urls.count,
            processedFiles: urls.count
        )
        
        isProcessing = false
    }
    
    private func processFile(_ url: URL, at index: Int) async {
        let startTime = Date()
        
        do {
            // File validation
            updateCurrentProgress(0.2, for: index)
            try await validateFile(at: url)
            
            // Extract metadata
            updateCurrentProgress(0.4, for: index)
            let metadata = try await extractSimpleMetadata(from: url)
            
            // Copy file to permanent storage FIRST
            updateCurrentProgress(0.6, for: index)
            let permanentURL = try await copyFileToDocuments(from: url)
            
            // Import song directly to Core Data with permanent path
            updateCurrentProgress(0.8, for: index)
            let filename = url.deletingPathExtension().lastPathComponent
            
            // Parse title and artist from filename if possible
            let components = filename.components(separatedBy: " - ")
            let title: String
            let artist: String?
            
            if components.count >= 2 {
                artist = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                title = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = filename
                artist = "Unknown Artist"
            }
            
            // Create song entity with permanent file path
            try await createSongEntity(
                title: title,
                artist: artist,
                duration: metadata.duration,
                filePath: permanentURL.path,
                fileSize: metadata.fileSize
            )
            
            updateCurrentProgress(1.0, for: index)
            
            let processingTime = Date().timeIntervalSince(startTime)
            let result = FileProcessingResult(
                url: permanentURL, // Use permanent URL
                metadata: metadata,
                error: nil,
                processingTime: processingTime
            )
            
            results.append(result)
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            let result = FileProcessingResult(
                url: url,
                metadata: nil,
                error: error,
                processingTime: processingTime
            )
            
            results.append(result)
            currentError = error
        }
    }
    
    private func createSongEntity(title: String, artist: String?, duration: TimeInterval, filePath: String, fileSize: Int64) async throws {
        let context = persistenceController.container.viewContext
        
        // Check for existing song to prevent duplicates
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@ AND artist == %@", title, artist ?? "")
        
        let existingSongs = try context.fetch(request)
        if !existingSongs.isEmpty {
            print("⚠️ Song '\(title)' by '\(artist ?? "Unknown")' already exists in Core Data. Skipping duplicate.")
            return
        }
        
        try await context.perform {
            let song = SongEntity(context: context)
            song.id = UUID()
            song.title = title
            song.artist = artist
            song.duration = duration
            song.filePath = filePath
            song.fileSizeBytes = fileSize
            song.dateAdded = Date()
            song.isDownloaded = true
            song.playCount = 0
            song.year = 0
            
            do {
                try context.save()
                print("✅ Successfully saved song: '\(title)' by '\(artist ?? "Unknown")' to Core Data")
                print("📊 Song details: Duration: \(duration)s, Size: \(fileSize) bytes, Path: \(filePath)")
                
                // Post notification to refresh song list
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("SongImported"), object: nil)
                }
            } catch {
                print("❌ Failed to save song to Core Data: \(error)")
                throw error
            }
        }
    }
    
    private func validateFile(at url: URL) async throws {
        // Check file size (5MB to 150MB)
        let fileSize = try getFileSize(url: url)
        if fileSize < 5_000_000 || fileSize > 150_000_000 {
            throw FileValidationError.invalidFileSize
        }
        
        // Check file extension
        if !url.pathExtension.lowercased().contains("mp4") {
            throw FileValidationError.invalidFileType
        }
    }
    
    private func extractSimpleMetadata(from url: URL) async throws -> SimpleMetadata {
        let fileSize = try getFileSize(url: url)
        
        // Extract real metadata using AVFoundation
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        
        var videoDimensions: CGSize?
        if let videoTrack = try await asset.loadTracks(withMediaType: .video).first {
            let naturalSize = try await videoTrack.load(.naturalSize)
            videoDimensions = naturalSize
        }
        
        return SimpleMetadata(
            duration: duration,
            fileSize: fileSize,
            videoDimensions: videoDimensions
        )
    }
    
    private func getFileSize(url: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func updateCurrentProgress(_ currentProgress: Double, for index: Int) {
        progress = FileProcessingProgress(
            totalFiles: progress.totalFiles,
            processedFiles: index,
            currentFileName: progress.currentFileName,
            currentProgress: currentProgress
        )
    }
    
    var processingStats: (successful: Int, failed: Int, totalTime: TimeInterval) {
        let successful = results.filter { $0.isSuccess }.count
        let failed = results.filter { !$0.isSuccess }.count
        let totalTime = results.reduce(0) { $0 + $1.processingTime }
        
        return (successful, failed, totalTime)
    }
    
    func clearResults() {
        results = []
        currentError = nil
        progress = FileProcessingProgress(totalFiles: 0, processedFiles: 0)
    }
    
    // NEW METHOD: Copy file to permanent Documents/Media directory
    private func copyFileToDocuments(from sourceURL: URL) async throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw NSError(domain: "FileProcessing", code: -1, userInfo: [NSLocalizedDescriptionKey: "Could not access documents directory"])
        }
        
        let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
        
        // Create Media directory if it doesn't exist
        try FileManager.default.createDirectory(at: mediaDirectory, withIntermediateDirectories: true, attributes: nil)
        
        let fileName = sourceURL.lastPathComponent
        let destinationURL = mediaDirectory.appendingPathComponent(fileName)
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Copy file to permanent location
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        
        print("✅ Copied file to permanent storage: \(destinationURL.path)")
        return destinationURL
    }
}

/// View for displaying file processing results
struct FileProcessingResultsView: View {
    let results: [FileProcessingResult]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                Section("Processing Summary") {
                    summaryView
                }
                
                Section("File Results") {
                    ForEach(results.indices, id: \.self) { index in
                        FileResultRow(result: results[index])
                    }
                }
            }
            .navigationTitle("Processing Results")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
    
    private var summaryView: some View {
        let stats = getProcessingStats()
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("\(stats.successful)", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Successful")
                Spacer()
            }
            
            HStack {
                Label("\(stats.failed)", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text("Failed")
                Spacer()
            }
            
            HStack {
                Label(String(format: "%.2fs", stats.totalTime), systemImage: "clock")
                    .foregroundColor(.blue)
                Text("Total Time")
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
    
    private func getProcessingStats() -> (successful: Int, failed: Int, totalTime: TimeInterval) {
        let successful = results.filter { $0.isSuccess }.count
        let failed = results.filter { !$0.isSuccess }.count
        let totalTime = results.reduce(0) { $0 + $1.processingTime }
        
        return (successful, failed, totalTime)
    }
}

/// Individual file result row
struct FileResultRow: View {
    let result: FileProcessingResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isSuccess ? .green : .red)
                    .font(.system(size: 16))
                
                Text(result.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(String(format: "%.2fs", result.processingTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if result.isSuccess, let metadata = result.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Duration: \(formatDuration(metadata.duration))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let dimensions = metadata.videoDimensions {
                        Text("Resolution: \(Int(dimensions.width))×\(Int(dimensions.height))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("Size: \(formatFileSize(metadata.fileSize))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let error = result.error {
                Text(error.localizedDescription)
                    .font(.caption)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

// MARK: - Settings ViewModel

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var isShowingFilePicker = false
    @Published var isShowingResults = false
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var isShowingErrorAlert = false
    
    @Published var notificationsEnabled = true
    @Published var autoProcessingEnabled = true
    @Published var storageOptimizationEnabled = false
    
    // File picker service
    @Published var filePickerService: FilePickerService
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    var isFilePickerEnabled: Bool {
        !filePickerService.isProcessing
    }
    
    var statusMessage: String {
        if filePickerService.isProcessing {
            let progress = filePickerService.progress
            if let currentFile = progress.currentFileName {
                return "Processing \(currentFile)... (\(progress.processedFiles + 1)/\(progress.totalFiles))"
            } else {
                return "Processing \(progress.processedFiles) of \(progress.totalFiles) files..."
            }
        } else if !filePickerService.results.isEmpty {
            let stats = filePickerService.processingStats
            return "Completed: \(stats.successful) successful, \(stats.failed) failed"
        } else {
            return "Ready to process MP4 files"
        }
    }
    
    init() {
        // Initialize services
        self.filePickerService = FilePickerService()
    }
    
    // MARK: - Actions
    
    func openFilePicker() {
        guard !filePickerService.isProcessing else { return }
        isShowingFilePicker = true
    }
    
    func handleFilesSelected(_ urls: [URL]) {
        Task {
            await filePickerService.processFiles(urls)
            
            // Show results when processing is complete
            if !filePickerService.results.isEmpty {
                isShowingResults = true
            }
            
            // Show error if there was one
            if let error = filePickerService.currentError {
                showError(error)
            }
        }
    }
    
    func handleFilePickerError(_ error: Error) {
        showError(error)
    }
    
    func resetSettings() {
        notificationsEnabled = true
        autoProcessingEnabled = true
        storageOptimizationEnabled = false
        
        // Clear file processing results
        filePickerService.clearResults()
    }
    
    func manageDownloads() {
        // Placeholder
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
    
    private func showError(_ error: Error) {
        errorAlert = ErrorAlertConfiguration(
            title: "File Processing Error",
            message: error.localizedDescription,
            primaryButton: .default(Text("OK")) { [weak self] in
                self?.isShowingErrorAlert = false
            }
        )
        isShowingErrorAlert = true
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = SettingsViewModel()

    var body: some View {
        ZStack {
            // Black background fills the whole screen
            AppTheme.settingsBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with RESET and DONE
                    headerView

                    // Main settings content
                    settingsContent
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
        .sheet(isPresented: $viewModel.isShowingFilePicker) {
            FilePickerView(
                isPresented: $viewModel.isShowingFilePicker,
                onFilesSelected: viewModel.handleFilesSelected,
                onError: viewModel.handleFilePickerError
            )
        }
        .sheet(isPresented: $viewModel.isShowingResults) {
            FileProcessingResultsView(
                results: viewModel.filePickerService.results,
                onDismiss: {
                    viewModel.isShowingResults = false
                    viewModel.filePickerService.clearResults()
                }
            )
        }
        .alert(
            "Error",
            isPresented: $viewModel.isShowingErrorAlert
        ) {
            Button("OK") {
                viewModel.isShowingErrorAlert = false
            }
        } message: {
            if let errorAlert = viewModel.errorAlert {
                Text(errorAlert.message)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("RESET") {
                viewModel.resetSettings()
            }
            .font(.headline)
            .foregroundColor(.blue)
            
            Spacer()
            
            DoneButton {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding(.top, 32)
    }
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Download MP4 files section
            downloadSection
            
            // App Settings section
            appSettingsSection
            
            // Other Settings section
            otherSettingsSection
            
            // Account section
            accountSection
            
            // App Info section
            appInfoSection
            
            // Debug Section (temporary for troubleshooting)
            Section("Debug") {
                Button("Show All Core Data Songs") {
                    Task {
                        await printAllCoreDataSongs()
                    }
                }
                .foregroundColor(.blue)
                
                Button("Clear All Core Data Songs") {
                    Task {
                        await clearAllCoreDataSongs()
                    }
                }
                .foregroundColor(.red)
            }
            
            // Storage Management
            Section("Storage") {
            }
        }
    }
    
    // MARK: - Debug Methods (temporary for troubleshooting)
    
    private func printAllCoreDataSongs() async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        
        do {
            let songs = try context.fetch(request)
            print("🔍 DEBUG: Found \(songs.count) songs in Core Data:")
            for (index, song) in songs.enumerated() {
                print("  \(index + 1). '\(song.title ?? "Unknown")' by '\(song.artist ?? "Unknown")'")
                print("     - Added: \(song.dateAdded ?? Date())")
                print("     - Duration: \(song.duration)s")
                print("     - File: \(song.filePath ?? "Unknown")")
                print("     - ID: \(song.id?.uuidString ?? "Unknown")")
            }
        } catch {
            print("❌ DEBUG: Error fetching Core Data songs: \(error)")
        }
    }
    
    private func clearAllCoreDataSongs() async {
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        do {
            let songs = try context.fetch(request)
            print("🗑️ DEBUG: Deleting \(songs.count) songs from Core Data")
            
            for song in songs {
                context.delete(song)
            }
            
            try context.save()
            print("✅ DEBUG: Successfully cleared all Core Data songs")
        } catch {
            print("❌ DEBUG: Error clearing Core Data songs: \(error)")
        }
    }
    
    private var downloadSection: some View {
        SettingsSection(title: "Download MP4 files", icon: "arrow.down.circle") {
            VStack(spacing: 12) {
                FilePickerRow(
                    title: "Select MP4 Files",
                    subtitle: viewModel.statusMessage,
                    isEnabled: viewModel.isFilePickerEnabled,
                    isLoading: viewModel.filePickerService.isProcessing,
                    action: viewModel.openFilePicker
                )
                
                if viewModel.filePickerService.isProcessing {
                    ProcessingProgressView(
                        progress: viewModel.filePickerService.progress
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var appSettingsSection: some View {
        SettingsSection(title: "App Settings", icon: "gearshape") {
            VStack(spacing: 8) {
                SettingRow(
                    title: "Enable Notifications",
                    subtitle: "Get notified when downloads complete",
                    icon: "bell",
                    accessoryType: .toggle($viewModel.notificationsEnabled)
                )
                
                SettingRow(
                    title: "Auto-Process Files",
                    subtitle: "Automatically process files after selection",
                    icon: "wand.and.rays",
                    accessoryType: .toggle($viewModel.autoProcessingEnabled)
                )
                
                SettingRow(
                    title: "Storage Optimization",
                    subtitle: "Optimize storage for processed files",
                    icon: "internaldrive",
                    accessoryType: .toggle($viewModel.storageOptimizationEnabled)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var otherSettingsSection: some View {
        SettingsSection(title: "Other Settings", icon: "slider.horizontal.3") {
            VStack(spacing: 8) {
                SettingRow(
                    title: "Manage Downloads",
                    subtitle: "View and manage downloaded files",
                    icon: "folder",
                    action: viewModel.manageDownloads
                )
                
                SettingRow(
                    title: "Audio Settings",
                    subtitle: "Configure audio preferences",
                    icon: "speaker.wave.2",
                    action: viewModel.showAudioSettings
                )
                
                SettingRow(
                    title: "Volume Settings",
                    subtitle: "Adjust volume controls",
                    icon: "speaker.3",
                    action: viewModel.showVolumeSettings
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var accountSection: some View {
        SettingsSection(title: "Account", icon: "person.circle") {
            VStack(spacing: 8) {
                SettingRow(
                    title: "User Account",
                    subtitle: "Manage your account settings",
                    icon: "person.crop.circle",
                    action: viewModel.showUserAccount
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    private var appInfoSection: some View {
        SettingsSection(title: "App Info", icon: "info.circle") {
            VStack(spacing: 8) {
                SettingRow(
                    title: "Version",
                    subtitle: "Current app version",
                    icon: "app.badge",
                    iconColor: .gray,
                    accessoryType: .value(viewModel.appVersion)
                )
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
}

// MARK: - Processing Progress View

struct ProcessingProgressView: View {
    let progress: FileProcessingProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Progress")
                    .font(.caption)
                    .foregroundColor(AppTheme.settingsText.opacity(0.7))
                
                Spacer()
                
                Text("\(progress.processedFiles)/\(progress.totalFiles)")
                    .font(.caption)
                    .foregroundColor(AppTheme.settingsText.opacity(0.7))
            }
            
            ProgressView(value: progress.overallProgress)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            if let currentFile = progress.currentFileName {
                HStack {
                    Text("Current: \(currentFile)")
                        .font(.caption2)
                        .foregroundColor(AppTheme.settingsText.opacity(0.6))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Text("\(Int(progress.currentProgress * 100))%")
                        .font(.caption2)
                        .foregroundColor(AppTheme.settingsText.opacity(0.6))
                }
                
                ProgressView(value: progress.currentProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(y: 0.5)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsText.opacity(0.1))
        )
    }
}

// MARK: - Simple Error Alert Configuration

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

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            content
        }
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsBackground.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

struct SettingRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let action: (() -> Void)?
    let accessoryType: AccessoryType
    
    enum AccessoryType {
        case none
        case disclosure
        case toggle(Binding<Bool>)
        case value(String)
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color = .blue,
        accessoryType: AccessoryType = .disclosure,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.accessoryType = accessoryType
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.settingsText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                accessoryView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsText.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil && !isInteractiveAccessory)
    }
    
    @ViewBuilder
    private var accessoryView: some View {
        switch accessoryType {
        case .none:
            EmptyView()
        case .disclosure:
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.settingsText.opacity(0.5))
                .font(.system(size: 12, weight: .medium))
        case .toggle(let binding):
            Toggle("", isOn: binding)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
        case .value(let value):
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.settingsText.opacity(0.7))
        }
    }
    
    private var isInteractiveAccessory: Bool {
        switch accessoryType {
        case .toggle(_):
            return true
        default:
            return false
        }
    }
}

struct FilePickerRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String = "folder.badge.plus",
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(isEnabled ? .blue : AppTheme.settingsText.opacity(0.5))
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? AppTheme.settingsText : AppTheme.settingsText.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                if !isLoading {
                    Image(systemName: "chevron.right")
                        .foregroundColor(AppTheme.settingsText.opacity(0.5))
                        .font(.system(size: 12, weight: .medium))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsText.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
