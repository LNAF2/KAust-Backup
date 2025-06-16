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
import AVKit
import CoreData

// Note: DataProviderService should be available since DataProviderServiceProtocol is already imported via existing protocol file structure

// MARK: - File Validation Errors

enum FileValidationError: LocalizedError {
    case invalidFileSize
    case invalidFileType
    case fileNotFound
    case permissionDenied
    case fileNotReadable
    
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
        case .fileNotReadable:
            return "File is not readable or corrupted"
        }
    }
}

// MARK: - File Picker Components

/// Enhanced file picker view with crash recovery and large file handling
struct FilePickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFilesSelected: ([URL]) -> Void
    let onError: (Error) -> Void
    let filePickerService: EnhancedFilePickerService // Add service reference
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [UTType.mpeg4Movie],
            asCopy: true
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        picker.modalPresentationStyle = .formSheet
        
        // Add safeguards for large selections
        if #available(iOS 14.0, *) {
            picker.shouldShowFileExtensions = true
        }
        
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
        private var crashRecoveryAttempts = 0
        private let maxCrashRecoveryAttempts = 2
        
        // CRITICAL: Prevent system picker crashes by limiting selection size
        private let systemSafeThreshold = 50    // Never allow more than 50 files in one picker session
        private let warningThreshold = 25        // Warn when approaching system limits
        
        init(_ parent: FilePickerView) {
            self.parent = parent
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            
            print("📁 Selected \(urls.count) files - starting automatic batch processing")
            
            // Always process files through automatic batch processing
            handleFileSelection(urls)
            
            // Reset crash recovery counter on successful selection
            crashRecoveryAttempts = 0
        }
        

        

        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
            crashRecoveryAttempts = 0
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentAt url: URL) {
            parent.isPresented = false
            handleFileSelection([url])
            crashRecoveryAttempts = 0
        }
        
        private func handleFileSelection(_ urls: [URL]) {
            // Immediately release the UI thread and handle in background
            Task { @MainActor in
                await processFileSelectionSafely(urls)
            }
        }
        
        private func processFileSelectionSafely(_ urls: [URL]) async {
            // SIMPLE PROCESSING: Just like before - automatic background batching
            let fileCount = urls.count
            
            print("📁 File picker received \(fileCount) files")
            print("🔄 Starting automatic batch processing (30 files per batch, 5-second pauses)")
            
            // Always process files - automatic batching happens in the background
            parent.onFilesSelected(urls)
        }
        

        

        
        private func estimatedProcessingTime(for fileCount: Int) -> String {
            let avgTimePerFile: Double = 2.0  // seconds per file (conservative estimate)
            let totalSeconds = Double(fileCount) * avgTimePerFile
            
            let hours = Int(totalSeconds) / 3600
            let minutes = Int(totalSeconds) % 3600 / 60
            
            if hours > 0 {
                return "\(hours)h \(minutes)m"
            } else if minutes > 5 {
                return "\(minutes) minutes"
            } else {
                return "a few minutes"
            }
        }
        
        @MainActor
        private func presentAlert(_ alert: UIAlertController) async {
            // Find the topmost view controller to present the alert
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first,
               let topController = getTopViewController(from: window.rootViewController) {
                topController.present(alert, animated: true)
            }
        }
        
        private func getTopViewController(from controller: UIViewController?) -> UIViewController? {
            if let presented = controller?.presentedViewController {
                return getTopViewController(from: presented)
            }
            
            if let navigationController = controller as? UINavigationController {
                return getTopViewController(from: navigationController.visibleViewController)
            }
            
            if let tabController = controller as? UITabBarController {
                return getTopViewController(from: tabController.selectedViewController)
            }
            
            return controller
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
    let status: ProcessingStatus
    let metadata: SimpleMetadata?
    let error: Error?
    let processingTime: TimeInterval
    
    enum ProcessingStatus {
        case success
        case failed
        case duplicate
        
        var isSuccess: Bool {
            return self == .success
        }
        
        var isDuplicate: Bool {
            return self == .duplicate
        }
        
        var isFailed: Bool {
            return self == .failed
        }
    }
    
    init(url: URL, status: ProcessingStatus, metadata: SimpleMetadata? = nil, error: Error? = nil, processingTime: TimeInterval) {
        self.url = url
        self.filename = url.lastPathComponent
        self.status = status
        self.metadata = metadata
        self.error = error
        self.processingTime = processingTime
    }
    
    // Legacy compatibility
    var isSuccess: Bool {
        return status.isSuccess
    }
}

// MARK: - Batch Processing Configuration
struct BatchProcessingConfig {
    // Optimized for 3000+ files
    static let defaultBatchSize = 25  // Reduced for better memory management
    static let maxConcurrentOperations = 2  // Reduced to prevent overwhelming the system
    static let progressUpdateInterval: TimeInterval = 0.5  // Less frequent updates for performance
    
    // Dynamic sizing based on file count
    static func optimalBatchSize(for fileCount: Int) -> Int {
        switch fileCount {
        case 0...100:
            return 20
        case 101...500:
            return 25
        case 501...1000:
            return 30
        case 1001...2000:
            return 35
        default: // 2000+
            return 40
        }
    }
    
    static func optimalConcurrency(for fileCount: Int) -> Int {
        switch fileCount {
        case 0...100:
            return 3
        case 101...500:
            return 2
        case 501...1000:
            return 2
        default: // 1000+
            return 1  // Single threaded for massive batches to prevent system overload
        }
    }
}

// MARK: - Batch Processing State
enum BatchProcessingState {
    case idle
    case processing
    case paused
    case completed
    case cancelled
}

// MARK: - File Picker Errors
enum FilePickerError: LocalizedError {
    case selectionCancelled
    case processingFailed(reason: String)
    case thumbnailGenerationFailed(fileName: String)
    case viewServiceTerminated
    
    var errorDescription: String? {
        switch self {
        case .selectionCancelled:
            return "File Selection Cancelled"
        case .processingFailed(let reason):
            return "Processing Failed: \(reason)"
        case .thumbnailGenerationFailed(let fileName):
            return "Thumbnail Error: \(fileName)"
        case .viewServiceTerminated:
            return "System File Picker Crashed"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .selectionCancelled:
            return "Please select files again."
        case .processingFailed(let reason):
            return "Please try again. Reason: \(reason)"
        case .thumbnailGenerationFailed(let fileName):
            return """
            Thumbnail generation failed for \(fileName). This is a system issue and the file will still be processed correctly.
            
            • The file itself is not damaged
            • Processing will continue normally
            • This is a known iOS file picker issue
            """
        case .viewServiceTerminated:
            return """
            The iOS file picker service crashed. The app will automatically handle this by processing your selected files in safe batches.
            
            • Your files are safe and will be processed
            • App uses automatic batch processing to prevent crashes
            • This is a known iOS limitation that we handle automatically
            """
        }
    }
}

// MARK: - Overall Batch Progress
struct BatchProgress {
    let totalFiles: Int
    let completedFiles: Int
    let currentBatch: Int
    let totalBatches: Int
    let currentBatchProgress: Double
    let successfulFiles: Int
    let failedFiles: Int
    let duplicateFiles: Int
    let estimatedTimeRemaining: TimeInterval?
    let currentFileName: String?
    
    var overallProgress: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(completedFiles) / Double(totalFiles)
    }
    
    var progressText: String {
        if let currentFileName = currentFileName {
            return "Processing \(currentFileName) (\(completedFiles + 1) of \(totalFiles))"
        } else {
            return "\(completedFiles) of \(totalFiles) files"
        }
    }
    
    var batchText: String {
        return "Batch \(currentBatch) of \(totalBatches)"
    }
}

/// Processing mode for file picker service
enum ProcessingMode {
    case filePickerCopy    // Traditional: copy files to app storage
    case directFolderAccess // New: use files directly from their location
}

/// Enhanced file picker service with crash recovery and chunked processing
@MainActor
class EnhancedFilePickerService: ObservableObject {
    @Published var processingState = BatchProcessingState.idle
    @Published var batchProgress = BatchProgress(
        totalFiles: 0, completedFiles: 0, currentBatch: 0, totalBatches: 0, 
        currentBatchProgress: 0, successfulFiles: 0, failedFiles: 0, 
        duplicateFiles: 0, estimatedTimeRemaining: nil, currentFileName: nil
    )
    @Published var results: [FileProcessingResult] = []
    @Published var currentError: Error?
    @Published var canPause = false
    @Published var canResume = false
    @Published var showLargeSelectionWarning = false
    @Published var pendingLargeSelection: [URL] = []
    
    // DEDICATED UI STATE FOR PROGRESS VISIBILITY
    @Published var isProcessingFiles = false
    @Published var currentProgressPercentage: Double = 0.0
    @Published var currentFileCount = 0
    @Published var totalFileCount = 0
    @Published var currentFileName: String = ""
    @Published var currentBatch = 0
    @Published var totalBatches = 0
    
    // NEW: Direct folder access support
    var processingMode: ProcessingMode = .filePickerCopy
    var folderSecurityScope: URL?
    
    // BATCH SELECTION MODE - Critical for preventing system picker crashes
    @Published var isBatchSelectionMode = false
    @Published var batchSelectionProgress = 0
    @Published var totalBatchesNeeded = 0
    @Published var currentBatchCollection: [URL] = []
    @Published var showBatchInstructions = false
    
    // Configuration
    private let batchSize: Int
    private let maxConcurrentOperations: Int
    private let largeSelectionThreshold = 500  // Warn for selections > 500 files
    
    // Processing state
    private var allFiles: [URL] = []
    private var currentBatchIndex = 0
    private var currentFileIndexInBatch = 0  // NEW: Track file position within current batch
    private var shouldPause = false
    private var shouldCancel = false
    private var processingStartTime: Date?
    private var avgProcessingTimePerFile: TimeInterval = 0
    
    // Core Data access
    private let persistenceController = PersistenceController.shared
    
    // Background processing queue
    private let processingQueue = DispatchQueue(label: "com.kaust.fileprocessing", qos: .utility)
    
    init(batchSize: Int = BatchProcessingConfig.defaultBatchSize,
         maxConcurrentOperations: Int = BatchProcessingConfig.maxConcurrentOperations) {
        self.batchSize = batchSize
        self.maxConcurrentOperations = maxConcurrentOperations
    }
    
    // Initialize with optimal settings for file count
    convenience init(optimizedFor fileCount: Int) {
        self.init(
            batchSize: BatchProcessingConfig.optimalBatchSize(for: fileCount),
            maxConcurrentOperations: BatchProcessingConfig.optimalConcurrency(for: fileCount)
        )
        print("🔧 Initialized optimized file processor: batchSize=\(batchSize), concurrency=\(maxConcurrentOperations) for \(fileCount) files")
    }
    
    // MARK: - Public Interface
    
    func handleFileSelection(_ urls: [URL]) {
        let fileCount = urls.count
        print("🎯 DEBUG: handleFileSelection called with \(fileCount) files")
        print("📁 Received \(fileCount) files for automatic batch processing")
        
        // Simple automatic processing with intelligent batching
        Task {
            print("🎯 DEBUG: About to call processFilesWithAutomaticBatching")
            await processFilesWithAutomaticBatching(urls)
        }
    }
    

    
    func confirmLargeSelection() {
        showLargeSelectionWarning = false
        if !pendingLargeSelection.isEmpty {
            Task {
                await processFiles(pendingLargeSelection)
            }
            pendingLargeSelection = []
        }
    }
    
    func cancelLargeSelection() {
        showLargeSelectionWarning = false
        pendingLargeSelection = []
    }
    
    // MARK: - Batch Selection Mode (Prevents System Picker Crashes)
    
    func startBatchSelectionMode(targetFiles: Int) {
        let ultraSafeSelectionSize = 30  // Ultra-safe number for system picker
        totalBatchesNeeded = Int(ceil(Double(targetFiles) / Double(ultraSafeSelectionSize)))
        batchSelectionProgress = 0
        currentBatchCollection = []
        isBatchSelectionMode = true
        showBatchInstructions = true
        
        print("🔄 Starting ULTRA-SAFE batch selection mode: \(totalBatchesNeeded) batches needed for \(targetFiles) files (30 files max per batch)")
    }
    
    func handleBatchSelection(_ urls: [URL]) {
        batchSelectionProgress += 1
        currentBatchCollection.append(contentsOf: urls)
        
        print("📂 Batch \(batchSelectionProgress)/\(totalBatchesNeeded): Added \(urls.count) files (Total: \(currentBatchCollection.count))")
        
        // Check if we've completed all batches
        if batchSelectionProgress >= totalBatchesNeeded {
            completeBatchSelection()
        } else {
            // Show instructions for next batch
            showBatchInstructions = true
        }
    }
    
    func completeBatchSelection() {
        print("✅ Batch selection complete! Total files collected: \(currentBatchCollection.count)")
        
        isBatchSelectionMode = false
        showBatchInstructions = false
        
        // Process all collected files
        Task {
            await processFiles(currentBatchCollection)
        }
    }
    
    func cancelBatchSelection() {
        print("🚫 Batch selection cancelled")
        isBatchSelectionMode = false
        showBatchInstructions = false
        batchSelectionProgress = 0
        totalBatchesNeeded = 0
        currentBatchCollection = []
    }
    
    func processFilesWithAutomaticBatching(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        
        print("🔄 Starting automatic batch processing for \(urls.count) files")
        print("📊 Will process in batches of 30 files with 5-second pauses")
        
        await resetProcessing()
        allFiles = urls
        processingStartTime = Date()
        
        // Use 30-file batches for stability
        let safeBatchSize = 30
        let totalBatches = Int(ceil(Double(urls.count) / Double(safeBatchSize)))
        
        await updateBatchProgress(
            totalFiles: urls.count,
            completedFiles: 0,
            currentBatch: 0,
            totalBatches: totalBatches,
            currentBatchProgress: 0,
            successfulFiles: 0,
            failedFiles: 0,
            duplicateFiles: 0,
            estimatedTimeRemaining: nil
        )
        
        // Set processing state and ensure UI sees the initial batch progress
        await MainActor.run {
            print("🎯 DEBUG: Setting processing state and initial progress")
            self.processingState = .processing
            self.canPause = true
            self.canResume = false
            
            // Initialize with first file to ensure progress is visible immediately
            self.batchProgress = BatchProgress(
                totalFiles: urls.count,
                completedFiles: 0,
                currentBatch: 1,
                totalBatches: totalBatches,
                currentBatchProgress: 0,
                successfulFiles: 0,
                failedFiles: 0,
                duplicateFiles: 0,
                estimatedTimeRemaining: nil,
                currentFileName: urls.first?.lastPathComponent
            )
            
            // INITIALIZE DEDICATED UI STATE FOR PROGRESS VISIBILITY
            self.isProcessingFiles = true
            self.totalFileCount = urls.count
            self.totalBatches = totalBatches
            self.currentBatch = 1
            self.currentFileCount = 0
            self.currentProgressPercentage = 0.0
            self.currentFileName = urls.first?.lastPathComponent ?? ""
            
            print("🎯 PROGRESS UI STATE INITIALIZED: \(self.totalFileCount) files, \(self.totalBatches) batches")
            print("🎯 isProcessingFiles = \(self.isProcessingFiles)")
            print("🎯 totalFileCount = \(self.totalFileCount)")
            print("🎯 currentFileCount = \(self.currentFileCount)")
            
            // Force view update
            self.objectWillChange.send()
        }
        
        // Small delay to ensure UI updates
        print("🎯 DEBUG: UI should now show progress overlay...")
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        await processBatchesWithPauses(batchSize: safeBatchSize)
    }
    
    func processFiles(_ urls: [URL]) async {
        print("🎯 DEBUG: OLD processFiles() called - redirecting to enhanced method")
        // Keep the old method for compatibility
        await processFilesWithAutomaticBatching(urls)
    }
    
    func pauseProcessing() {
        guard processingState == .processing else { return }
        shouldPause = true
        processingState = .paused
        canPause = false
        canResume = true
        
        // KEEP UI STATE TRUE FOR PAUSED STATE SO OVERLAY STAYS VISIBLE
        Task { @MainActor in
            self.isProcessingFiles = true  // Keep overlay visible when paused
            print("⏸️ Processing paused - keeping UI overlay visible")
        }
    }
    
    func resumeProcessing() async {
        guard processingState == .paused else { 
            print("❌ RESUME ERROR: Cannot resume, current state is \(processingState)")
            return 
        }
        
        print("▶️ Resuming processing from pause state...")
        print("📊 Resume context: \(results.count)/\(allFiles.count) files processed, currentBatchIndex=\(currentBatchIndex), currentFileIndexInBatch=\(currentFileIndexInBatch)")
        
        // RESET FLAGS AND STATE
        shouldPause = false
        processingState = .processing
        canPause = true
        canResume = false
        
        // RESUME WITH DEDICATED UI STATE
        await MainActor.run {
            self.isProcessingFiles = true
            print("🎯 RESUME: isProcessingFiles = true, UI state updated")
        }
        
        print("▶️ RESTARTING processing loop from currentBatchIndex=\(currentBatchIndex)")
        
        // RESTART THE PROCESSING LOOP - this is the key fix!
        // The paused function already exited, so we need to restart it
        await processBatchesWithPauses(batchSize: 30)
    }
    
    func cancelProcessing() {
        shouldCancel = true
        shouldPause = false
        processingState = .cancelled
        canPause = false
        canResume = false
        
        // UPDATE DEDICATED UI STATE FOR CANCELLATION
        Task { @MainActor in
            self.isProcessingFiles = false
            print("🛑 Processing cancelled by user - UI state updated")
        }
        
        print("🛑 Processing cancelled by user")
    }
    
    // MARK: - Restart Functionality
    
    func restartProcessing() async {
        print("🔄 Restarting processing with same files...")
        
        guard !allFiles.isEmpty else {
            print("❌ No files to restart with")
            return
        }
        
        // Reset processing state completely
        await resetProcessing()
        
        // Start fresh with the same files
        await processFiles(allFiles)
    }
    
    func resetAndClearFiles() async {
        print("🧹 Resetting and clearing all files")
        
        await resetProcessing()
        allFiles = []
        
        await MainActor.run {
            self.batchProgress = BatchProgress(
                totalFiles: 0, completedFiles: 0, currentBatch: 0, totalBatches: 0,
                currentBatchProgress: 0, successfulFiles: 0, failedFiles: 0,
                duplicateFiles: 0, estimatedTimeRemaining: nil, currentFileName: nil
            )
        }
    }
    
    // MARK: - Enhanced Batch Processing with 5-Second Pauses
    
    private func processBatchesWithPauses(batchSize: Int) async {
        let totalFiles = allFiles.count
        let totalBatches = Int(ceil(Double(totalFiles) / Double(batchSize)))
        
        print("📊 Processing \(totalFiles) files in \(totalBatches) batches of \(batchSize) files each")
        
        // USE WHILE LOOP INSTEAD OF FOR LOOP TO PROPERLY HANDLE PAUSING
        while currentBatchIndex < totalBatches && !shouldCancel {
            // Check for pause at start of each batch iteration
            while shouldPause && !shouldCancel {
                print("⏸️ Processing paused (batch \(currentBatchIndex + 1)/\(totalBatches)) - waiting for resume...")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            }
            
            // Check if we resumed or if we should cancel
            if shouldCancel {
                print("🛑 Processing cancelled")
                processingState = .cancelled
                return
            }
            
            if !shouldPause {
                print("▶️ Processing resumed for batch \(currentBatchIndex + 1)/\(totalBatches)")
            }
            
            let startIndex = currentBatchIndex * batchSize
            let endIndex = min(startIndex + batchSize, totalFiles)
            let batch = Array(allFiles[startIndex..<endIndex])
            
            if currentFileIndexInBatch > 0 {
                print("📂 Resuming batch \(currentBatchIndex + 1)/\(totalBatches): \(batch.count) files (starting from file \(currentFileIndexInBatch + 1))")
            } else {
                print("📂 Processing batch \(currentBatchIndex + 1)/\(totalBatches): \(batch.count) files")
            }
            
            // Update progress
            await updateBatchProgress(
                totalFiles: totalFiles,
                completedFiles: startIndex,
                currentBatch: currentBatchIndex + 1,
                totalBatches: totalBatches,
                currentBatchProgress: 0,
                successfulFiles: results.filter(\.isSuccess).count,
                failedFiles: results.filter(\.status.isFailed).count,
                duplicateFiles: results.filter(\.status.isDuplicate).count,
                estimatedTimeRemaining: calculateEstimatedTimeRemaining(
                    completedFiles: startIndex,
                    totalFiles: totalFiles
                )
            )
            
            // UPDATE UI BATCH STATE
            await MainActor.run {
                self.currentBatch = currentBatchIndex + 1
                print("🎯 UI BATCH UPDATED: \(currentBatchIndex + 1)/\(totalBatches)")
            }
            
            // Process the batch
            await processSingleBatch(batch, batchIndex: currentBatchIndex + 1, totalBatches: totalBatches)
            
            // CHECK IF BATCH WAS PAUSED DURING PROCESSING
            if shouldPause {
                print("🎯 BATCH PROCESSING PAUSED: currentBatchIndex remains \(currentBatchIndex) (will resume from here)")
                return  // Exit function, batch index stays the same for resume
            }
            
            // Only advance batch index if batch completed successfully
            currentBatchIndex += 1
            currentFileIndexInBatch = 0  // RESET file index for new batch
            print("🎯 BATCH COMPLETED: Advanced to batch \(currentBatchIndex)/\(totalBatches)")
            
            // 5-second pause between batches (except for the last batch)
            if currentBatchIndex < totalBatches && !shouldCancel && !shouldPause {
                print("⏳ 5-second pause before next batch...")
                for second in 1...5 {
                    // Check for cancellation or pause during the wait
                    if shouldCancel || shouldPause { 
                        print("🎯 Inter-batch pause interrupted by user action")
                        break 
                    }
                    
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    print("⏳ \(6 - second) seconds remaining...")
                }
            }
        }
        
        // Final completion
        if !shouldCancel {
            processingState = .completed
            canPause = false
            canResume = false
            
            // COMPLETE DEDICATED UI STATE
            await MainActor.run {
                self.isProcessingFiles = false
                self.currentProgressPercentage = 100.0
                print("🎯 UI PROCESSING COMPLETED!")
            }
            
            // Clean up folder access if we were in direct folder access mode
            if processingMode == .directFolderAccess {
                cleanupFolderAccess()
            }
            
            let successCount = results.filter(\.isSuccess).count
            let failCount = results.filter(\.status.isFailed).count
            let duplicateCount = results.filter(\.status.isDuplicate).count
            
            print("✅ Processing complete! Success: \(successCount), Failed: \(failCount), Duplicates: \(duplicateCount)")
        }
    }
    
    private func processSingleBatch(_ batchFiles: [URL], batchIndex: Int, totalBatches: Int) async {
        let batchStartTime = Date()
        print("🔄 Processing batch \(batchIndex) with \(batchFiles.count) files")
        
        // START FROM WHERE WE LEFT OFF (if resuming)
        let startIndex = currentFileIndexInBatch
        print("🎯 RESUME: Starting from file \(startIndex + 1)/\(batchFiles.count) in batch \(batchIndex)")
        
        // Process each file in the batch, starting from where we left off
        for index in startIndex..<batchFiles.count {
            let url = batchFiles[index]
            
            // Check for cancellation or pause
            if shouldCancel { 
                print("🛑 Processing cancelled during batch \(batchIndex)")
                break 
            }
            if shouldPause { 
                print("⏸️ Processing paused during batch \(batchIndex) at file \(index + 1)/\(batchFiles.count)")
                print("🎯 BATCH PAUSED: Saving position \(index) for resume")
                currentFileIndexInBatch = index  // SAVE CURRENT POSITION
                return  // EXIT WITHOUT MARKING BATCH AS COMPLETE
            }
            
            // Update batch progress
            let fileProgress = Double(index) / Double(batchFiles.count)
            await updateCurrentBatchProgress(fileProgress, currentFileName: url.lastPathComponent)
            
            // Process the file
            await processFile(url, batchIndex: batchIndex, fileIndex: index, totalInBatch: batchFiles.count)
            
            // Small delay between files within a batch
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        }
        
        // ONLY mark batch as complete if we processed ALL files without pause
        if !shouldPause {
            await updateCurrentBatchProgress(1.0, currentFileName: nil)
            print("✅ Completed batch \(batchIndex) in \(String(format: "%.1f", Date().timeIntervalSince(batchStartTime)))s")
            currentFileIndexInBatch = 0  // RESET for next batch
        }
    }
    
    private func calculateEstimatedTimeRemaining(completedFiles: Int, totalFiles: Int) -> TimeInterval? {
        guard let startTime = processingStartTime,
              completedFiles > 0 else { return nil }
        
        let elapsedTime = Date().timeIntervalSince(startTime)
        let avgTimePerFile = elapsedTime / Double(completedFiles)
        let remainingFiles = totalFiles - completedFiles
        return avgTimePerFile * Double(remainingFiles)
    }
    
    var canRestart: Bool {
        return !allFiles.isEmpty && (processingState == .cancelled || processingState == .completed)
    }
    
    // MARK: - Batch Processing Logic
    
    private func processBatches() async {
        print("🎯 DEBUG: processBatches() called - this might be the wrong method!")
        while currentBatchIndex * batchSize < allFiles.count && !shouldCancel {
            // Check for pause
            if shouldPause {
                print("⏸️ Processing paused at batch \(currentBatchIndex + 1)")
                return
            }
            
            let startIndex = currentBatchIndex * batchSize
            let endIndex = min(startIndex + batchSize, allFiles.count)
            let batchFiles = Array(allFiles[startIndex..<endIndex])
            
            print("🚀 Starting batch \(currentBatchIndex + 1) with \(batchFiles.count) files")
            await updateCurrentBatch(currentBatchIndex + 1)
            
            await processBatch(batchFiles, batchIndex: currentBatchIndex)
            
            currentBatchIndex += 1
            
            // CRITICAL: Memory cleanup between batches for large operations
            if allFiles.count > 500 {
                await performMemoryCleanup()
            }
            
            // Adaptive delay based on file count
            let delayNanoseconds = allFiles.count > 1000 ? 500_000_000 : 100_000_000 // 0.5s for large batches, 0.1s for smaller
            try? await Task.sleep(nanoseconds: UInt64(delayNanoseconds))
        }
        
        // Processing completed
        if !shouldCancel {
            // Ensure minimum processing time for UI visibility
            let processingTime = Date().timeIntervalSince(processingStartTime ?? Date())
            let minimumDisplayTime: TimeInterval = 2.0 // 2 seconds minimum
            
            if processingTime < minimumDisplayTime {
                let remainingTime = minimumDisplayTime - processingTime
                print("🎯 DEBUG: Extending processing display time by \(remainingTime) seconds for UI visibility")
                try? await Task.sleep(nanoseconds: UInt64(remainingTime * 1_000_000_000))
            }
            
            print("🎯 DEBUG: Setting processing state to .completed")
            processingState = .completed
            canPause = false
            canResume = false
            
            // Clean up folder access if we were in direct folder access mode
            if processingMode == .directFolderAccess {
                cleanupFolderAccess()
            }
            
            print("🎉 All batches completed successfully!")
        }
    }
    
    // Memory cleanup between batches
    private func performMemoryCleanup() async {
        print("🧹 Performing memory cleanup...")
        
        // Force garbage collection
        autoreleasepool {
            // This block helps release any autoreleased objects
        }
        
        // Small delay to let system clean up
        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
    }
    
    private func processBatch(_ batchFiles: [URL], batchIndex: Int) async {
        let batchStartTime = Date()
        print("🔄 Processing batch \(batchIndex + 1) with \(batchFiles.count) files")
        
        // Memory-efficient sequential processing
        for (index, url) in batchFiles.enumerated() {
            // Check for cancellation or pause
            if shouldCancel { 
                print("🛑 Processing cancelled during batch \(batchIndex + 1)")
                break 
            }
            if shouldPause { 
                print("⏸️ Processing paused during batch \(batchIndex + 1)")
                return 
            }
            
            // Update batch progress at start of each file
            let fileProgress = Double(index) / Double(batchFiles.count)
            await updateCurrentBatchProgress(fileProgress, currentFileName: url.lastPathComponent)
            
            // Process the file with memory management
            await processFile(url, batchIndex: batchIndex, fileIndex: index, totalInBatch: batchFiles.count)
            
            // Adaptive delay: faster for large batches to improve overall speed
            let delayNanos = allFiles.count > 1000 ? 50_000_000 : 200_000_000 // 0.05s for massive batches, 0.2s for normal
            try? await Task.sleep(nanoseconds: UInt64(delayNanos))
        }
        
        // Mark batch as complete
        await updateCurrentBatchProgress(1.0, currentFileName: nil)
        print("✅ Completed batch \(batchIndex + 1) in \(String(format: "%.1f", Date().timeIntervalSince(batchStartTime)))s")
        
        // Update processing time statistics
        let batchProcessingTime = Date().timeIntervalSince(batchStartTime)
        avgProcessingTimePerFile = (avgProcessingTimePerFile + batchProcessingTime / Double(batchFiles.count)) / 2
    }
    
    private func processFile(_ url: URL, batchIndex: Int, fileIndex: Int, totalInBatch: Int) async {
        let startTime = Date()
        let filename = url.lastPathComponent
        
        do {
            print("   📋 Validating \(filename)... (Mode: \(processingMode))")
            // File validation
            try await validateFile(at: url)
            
            print("   🎵 Extracting metadata from \(filename)...")
            // Extract metadata
            let metadata = try await extractSimpleMetadata(from: url)
            
            // Handle file location based on processing mode
            let finalURL: URL
            let filePath: String
            
            switch processingMode {
            case .filePickerCopy:
                print("   💾 Copying \(filename) to permanent storage...")
                // Traditional mode: copy to app storage
                finalURL = try await copyFileToDocuments(from: url)
                filePath = finalURL.path
                
            case .directFolderAccess:
                print("   📁 Using direct folder access for \(filename)...")
                // New mode: use original location directly
                finalURL = url
                filePath = url.path
                print("   📂 Direct path: \(filePath)")
            }
            
            // Parse title and artist from filename
            let filenameWithoutExt = url.deletingPathExtension().lastPathComponent
            
            // Remove supplier information in parentheses first
            let cleanFilename = filenameWithoutExt.replacingOccurrences(
                of: "\\s*\\(.*?\\)\\s*", 
                with: "", 
                options: .regularExpression
            ).trimmingCharacters(in: .whitespacesAndNewlines)
            
            let components = cleanFilename.components(separatedBy: " - ")
            let title: String
            let artist: String?
            
            if components.count >= 2 {
                title = components[0].trimmingCharacters(in: .whitespacesAndNewlines)
                artist = components[1].trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                title = cleanFilename
                artist = "Unknown Artist"
            }
            
            print("   🗄️ Saving '\(title)' by '\(artist ?? "Unknown")' to database...")
            // Create song entity
            let status = try await createSongEntity(
                title: title,
                artist: artist,
                duration: metadata.duration,
                filePath: filePath,
                fileSize: metadata.fileSize
            )
            
            let processingTime = Date().timeIntervalSince(startTime)
            let result = FileProcessingResult(
                url: finalURL,
                status: status,
                metadata: metadata,
                error: nil,
                processingTime: processingTime
            )
            
            print("   ✅ Completed \(filename) in \(String(format: "%.2f", processingTime))s - Status: \(status)")
            await addResult(result)
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            let result = FileProcessingResult(
                url: url,
                status: .failed,
                metadata: nil,
                error: error,
                processingTime: processingTime
            )
            
            print("   ❌ Failed \(filename) in \(String(format: "%.2f", processingTime))s - Error: \(error.localizedDescription)")
            await addResult(result)
            currentError = error
        }
    }
    
    // MARK: - Progress Management
    
    private func updateBatchProgress(
        totalFiles: Int,
        completedFiles: Int,
        currentBatch: Int,
        totalBatches: Int,
        currentBatchProgress: Double,
        successfulFiles: Int,
        failedFiles: Int,
        duplicateFiles: Int,
        estimatedTimeRemaining: TimeInterval?,
        currentFileName: String? = nil
    ) async {
        await MainActor.run {
            self.batchProgress = BatchProgress(
                totalFiles: totalFiles,
                completedFiles: completedFiles,
                currentBatch: currentBatch,
                totalBatches: totalBatches,
                currentBatchProgress: currentBatchProgress,
                successfulFiles: successfulFiles,
                failedFiles: failedFiles,
                duplicateFiles: duplicateFiles,
                estimatedTimeRemaining: estimatedTimeRemaining,
                currentFileName: currentFileName
            )
        }
    }
    
    private func updateCurrentBatch(_ batch: Int) async {
        await updateBatchProgress(
            totalFiles: batchProgress.totalFiles,
            completedFiles: batchProgress.completedFiles,
            currentBatch: batch,
            totalBatches: batchProgress.totalBatches,
            currentBatchProgress: 0,
            successfulFiles: batchProgress.successfulFiles,
            failedFiles: batchProgress.failedFiles,
            duplicateFiles: batchProgress.duplicateFiles,
            estimatedTimeRemaining: calculateEstimatedTimeRemaining()
        )
    }
    
    private func updateCurrentBatchProgress(_ progress: Double, currentFileName: String? = nil) async {
        await updateBatchProgress(
            totalFiles: batchProgress.totalFiles,
            completedFiles: batchProgress.completedFiles,
            currentBatch: batchProgress.currentBatch,
            totalBatches: batchProgress.totalBatches,
            currentBatchProgress: progress,
            successfulFiles: batchProgress.successfulFiles,
            failedFiles: batchProgress.failedFiles,
            duplicateFiles: batchProgress.duplicateFiles,
            estimatedTimeRemaining: calculateEstimatedTimeRemaining(),
            currentFileName: currentFileName
        )
        
        // UPDATE DEDICATED UI STATE
        await MainActor.run {
            if let fileName = currentFileName {
                self.currentFileName = fileName
                print("🎯 UI FILE NAME UPDATED: \(fileName)")
            }
        }
    }
    
    private func addResult(_ result: FileProcessingResult) async {
        await MainActor.run {
            self.results.append(result)
            
            let stats = self.processingStats
            let completedFiles = self.results.count
            
            self.batchProgress = BatchProgress(
                totalFiles: self.batchProgress.totalFiles,
                completedFiles: completedFiles,
                currentBatch: self.batchProgress.currentBatch,
                totalBatches: self.batchProgress.totalBatches,
                currentBatchProgress: self.batchProgress.currentBatchProgress,
                successfulFiles: stats.successful,
                failedFiles: stats.failed,
                duplicateFiles: stats.duplicates,
                estimatedTimeRemaining: self.calculateEstimatedTimeRemaining(),
                currentFileName: nil  // Clear filename when file is completed
            )
            
            // UPDATE DEDICATED UI STATE
            self.currentFileCount = completedFiles
            self.currentProgressPercentage = (Double(completedFiles) / Double(self.totalFileCount)) * 100.0
            
            print("🎯 UI PROGRESS UPDATED: \(completedFiles)/\(self.totalFileCount) (\(Int(self.currentProgressPercentage))%)")
        }
    }
    
    private func calculateEstimatedTimeRemaining() -> TimeInterval? {
        guard processingStartTime != nil,
              avgProcessingTimePerFile > 0,
              batchProgress.completedFiles > 0 else { return nil }
        
        let remainingFiles = batchProgress.totalFiles - batchProgress.completedFiles
        return avgProcessingTimePerFile * Double(remainingFiles)
    }
    
    private func resetProcessing() async {
        print("🎯 DEBUG: resetProcessing() called")
        currentBatchIndex = 0
        currentFileIndexInBatch = 0  // RESET file position
        shouldPause = false
        shouldCancel = false
        processingStartTime = nil
        avgProcessingTimePerFile = 0
        
        await MainActor.run {
            print("🎯 DEBUG: Setting state to idle in resetProcessing")
            self.results = []
            self.currentError = nil
            self.processingState = .idle
            self.canPause = false
            self.canResume = false
            
            // RESET DEDICATED UI STATE FOR PROGRESS
            self.isProcessingFiles = false
            self.currentProgressPercentage = 0.0
            self.currentFileCount = 0
            self.totalFileCount = 0
            self.currentFileName = ""
            self.currentBatch = 0
            self.totalBatches = 0
        }
    }
    
    private func createSongEntity(title: String, artist: String?, duration: TimeInterval, filePath: String, fileSize: Int64) async throws -> FileProcessingResult.ProcessingStatus {
        let context = persistenceController.container.viewContext
        
        // Check for existing song to prevent duplicates
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.predicate = NSPredicate(format: "title == %@ AND artist == %@", title, artist ?? "")
        
        let existingSongs = try context.fetch(request)
        if !existingSongs.isEmpty {
            print("⚠️ Song '\(title)' by '\(artist ?? "Unknown")' already exists in Core Data. Skipping duplicate.")
            return .duplicate
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
        
        return .success
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
    
    var processingStats: (successful: Int, failed: Int, duplicates: Int, totalTime: TimeInterval) {
        let successful = results.filter { $0.status == .success }.count
        let failed = results.filter { $0.status == .failed }.count
        let duplicates = results.filter { $0.status == .duplicate }.count
        let totalTime = results.reduce(0) { $0 + $1.processingTime }
        
        return (successful, failed, duplicates, totalTime)
    }
    
    func clearResults() {
        results = []
        currentError = nil
        processingState = .idle
        batchProgress = BatchProgress(
            totalFiles: 0, completedFiles: 0, currentBatch: 0, totalBatches: 0, 
            currentBatchProgress: 0, successfulFiles: 0, failedFiles: 0, 
            duplicateFiles: 0, estimatedTimeRemaining: nil, currentFileName: nil
        )
        
        // Clean up folder security scope if needed
        cleanupFolderAccess()
    }
    
    private func cleanupFolderAccess() {
        // Don't automatically release folder access - we need it for playback
        // Only release when explicitly requested or when app terminates
        print("🔒 Keeping folder security-scoped access for playback")
    }
    
    // NEW METHOD: Restore folder access from saved bookmark
    func restoreFolderAccess() -> Bool {
        guard let bookmarkData = UserDefaults.standard.data(forKey: "mp4FolderBookmark") else {
            print("📁 No saved folder bookmark found")
            return false
        }
        
        do {
            var isStale = false
            let folderURL = try URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            guard folderURL.startAccessingSecurityScopedResource() else {
                print("❌ Failed to restore folder security-scoped access")
                return false
            }
            
            folderSecurityScope = folderURL
            processingMode = .directFolderAccess
            print("✅ Restored folder security-scoped access: \(folderURL.path)")
            return true
            
        } catch {
            print("❌ Failed to restore folder bookmark: \(error)")
            return false
        }
    }
    
    // NEW METHOD: Explicitly release folder access (call when app terminates)
    func releaseFolderAccess() {
        if let folderURL = folderSecurityScope {
            folderURL.stopAccessingSecurityScopedResource()
            folderSecurityScope = nil
            processingMode = .filePickerCopy
            print("🔓 Explicitly released security-scoped access to folder")
        }
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
                
                // Successful files section
                let successfulResults = results.filter { $0.status == .success }
                if !successfulResults.isEmpty {
                    Section("Successfully Processed (\(successfulResults.count))") {
                        ForEach(successfulResults.indices, id: \.self) { index in
                            FileResultRow(result: successfulResults[index])
                        }
                    }
                }
                
                // Duplicate files section
                let duplicateResults = results.filter { $0.status == .duplicate }
                if !duplicateResults.isEmpty {
                    Section("Duplicate Files (\(duplicateResults.count))") {
                        ForEach(duplicateResults.indices, id: \.self) { index in
                            FileResultRow(result: duplicateResults[index])
                        }
                    }
                }
                
                // Failed files section
                let failedResults = results.filter { $0.status == .failed }
                if !failedResults.isEmpty {
                    Section("Failed Files (\(failedResults.count))") {
                        ForEach(failedResults.indices, id: \.self) { index in
                            FileResultRow(result: failedResults[index])
                        }
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
                Label("\(stats.duplicates)", systemImage: "repeat.circle.fill")
                    .foregroundColor(.yellow)
                Text("Duplicates")
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
    
    private func getProcessingStats() -> (successful: Int, failed: Int, duplicates: Int, totalTime: TimeInterval) {
        let successful = results.filter { $0.status == .success }.count
        let failed = results.filter { $0.status == .failed }.count
        let duplicates = results.filter { $0.status == .duplicate }.count
        let totalTime = results.reduce(0) { $0 + $1.processingTime }
        
        return (successful, failed, duplicates, totalTime)
    }
}

/// Individual file result row
struct FileResultRow: View {
    let result: FileProcessingResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status icon with appropriate color
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                    .font(.system(size: 16))
                
                Text(result.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(String(format: "%.2fs", result.processingTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Status-specific details
            if result.status == .duplicate {
                Text("File already exists in database")
                    .font(.caption)
                    .foregroundColor(.yellow)
                    .italic()
            } else if result.status == .failed, let error = result.error {
                Text("Error: \(getDetailedErrorMessage(error))")
                    .font(.caption)
                    .foregroundColor(.red)
                    .fixedSize(horizontal: false, vertical: true)
            } else if result.status == .success, let metadata = result.metadata {
                Text("Duration: \(formatDuration(metadata.duration)) • Size: \(formatFileSize(metadata.fileSize))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusIcon: String {
        switch result.status {
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .duplicate:
            return "repeat.circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch result.status {
        case .success:
            return .green
        case .failed:
            return .red
        case .duplicate:
            return .yellow
        }
    }
    
    private func getDetailedErrorMessage(_ error: Error) -> String {
        if let validationError = error as? FileValidationError {
            switch validationError {
            case .invalidFileSize:
                return "File size must be between 5MB and 150MB"
            case .invalidFileType:
                return "Only MP4 files are supported"
            case .fileNotFound:
                return "File not found or was moved"
            case .permissionDenied:
                return "Permission denied - check file access rights"
            case .fileNotReadable:
                return "File is corrupted, damaged, or in an unsupported format"
            }
        } else {
            // Handle other error types by checking the description first
            let errorDescription = error.localizedDescription
            if errorDescription.contains("AVFoundation") {
                return "Video file is corrupted or in an unsupported format"
            } else if errorDescription.contains("CoreData") {
                return "Database error - could not save file information"
            } else {
                // Cast to NSError for additional system error information
                let nsError = error as NSError
                switch nsError.code {
                case NSFileReadNoSuchFileError:
                    return "File was deleted or moved during processing"
                case NSFileReadNoPermissionError:
                    return "Insufficient permissions to read the file"
                case NSFileReadCorruptFileError:
                    return "File is corrupted and cannot be read"
                case NSFileWriteFileExistsError:
                    return "A file with this name already exists"
                case NSFileWriteVolumeReadOnlyError:
                    return "Storage location is read-only"
                case NSFileWriteOutOfSpaceError:
                    return "Not enough storage space available"
                default:
                    if nsError.domain == "AVFoundationErrorDomain" {
                        return "Invalid or corrupted video file - cannot extract metadata"
                    } else if nsError.domain == "NSCocoaErrorDomain" {
                        return "File system error: \(nsError.localizedDescription)"
                    } else {
                        return errorDescription
                    }
                }
            }
        }
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
    @Published var isShowingFolderPicker = false
    @Published var isShowingResults = false
    @Published var errorAlert: ErrorAlertConfiguration?
    @Published var isShowingErrorAlert = false
    
    @Published var notificationsEnabled = true
    @Published var autoProcessingEnabled = true
    @Published var storageOptimizationEnabled = true
    @AppStorage("swipeToDeleteEnabled") var swipeToDeleteEnabled = false  // Use @AppStorage for automatic persistence
    
    // Shared access to swipe-to-delete setting
    static var shared: SettingsViewModel = SettingsViewModel()
    
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
    
    init() {
        // Initialize services with default configuration
        // The service will be reconfigured dynamically based on file count
        self.filePickerService = EnhancedFilePickerService()
        
        // SETUP REACTIVE MONITORING FOR UI STATE
        setupProgressMonitoring()
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
    
    // Reinitialize file picker service with optimal settings for large batches
    private func optimizeForFileCount(_ fileCount: Int) {
        print("🔧 Optimizing file picker service for \(fileCount) files")
        // Clear existing subscribers
        cancellables.removeAll()
        // Create new optimized service
        self.filePickerService = EnhancedFilePickerService(optimizedFor: fileCount)
        // Re-setup reactive monitoring for the new service
        setupProgressMonitoring()
    }
    
    // MARK: - Actions
    
    func openFilePicker() {
        guard filePickerService.processingState != .processing else { return }
        isShowingFilePicker = true
    }
    
    func selectMP4Folder() {
        guard filePickerService.processingState != .processing else { return }
        isShowingFolderPicker = true
    }
    
    func handleFilesSelected(_ urls: [URL]) {
        let fileCount = urls.count
        print("📋 Handling selection of \(fileCount) files")
        
        // Optimize the service configuration for the file count
        if fileCount > 100 {
            optimizeForFileCount(fileCount)
        }
        
        // Use the enhanced file selection handling
        filePickerService.handleFileSelection(urls)
        
        // Monitor processing completion for ALL file selections
        monitorProcessingCompletion()
    }
    
    func handleFolderSelected(_ folderURL: URL) {
        print("📁 Folder selected: \(folderURL.path)")
        
        Task {
            await processMP4FolderAccess(folderURL)
        }
    }
    
    private func processMP4FolderAccess(_ folderURL: URL) async {
        guard folderURL.startAccessingSecurityScopedResource() else {
            print("❌ Failed to access security-scoped resource")
            showError(FilePickerError.processingFailed(reason: "Permission denied to access folder"))
            return
        }
        
        do {
            // Create bookmark for persistent access
            let bookmark = try folderURL.bookmarkData(
                options: .suitableForBookmarkFile,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            
            // Save bookmark for future access
            UserDefaults.standard.set(bookmark, forKey: "mp4FolderBookmark")
            print("✅ Saved folder bookmark for future access")
            
            // Scan for MP4 files and create bookmarks for each
            let mp4Files = await scanForMP4FilesWithBookmarks(in: folderURL)
            
            await MainActor.run {
                print("🎵 Found \(mp4Files.count) MP4 files in folder")
                
                if mp4Files.isEmpty {
                    showError(FilePickerError.processingFailed(reason: "No MP4 files found in selected folder"))
                } else {
                    // Process files directly from their location (no copying needed!)
                    // Mark this as direct folder access so processing knows not to copy files
                    filePickerService.processingMode = .directFolderAccess
                    filePickerService.folderSecurityScope = folderURL
                    handleFilesSelected(mp4Files)
                }
            }
            
        } catch {
            await MainActor.run {
                print("❌ Error processing folder: \(error)")
                showError(error)
            }
        }
    }
    
    private func scanForMP4FilesWithBookmarks(in folderURL: URL) async -> [URL] {
        let fileManager = FileManager.default
        let resourceKeys: [URLResourceKey] = [.nameKey, .isDirectoryKey, .fileSizeKey]
        
        // First, collect all MP4 URLs synchronously to avoid Swift 6 async iterator issues
        var allMP4URLs: [URL] = []
        
        if let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles]
        ) {
            // Swift 6 fix: collect URLs synchronously first
            let allURLs = enumerator.allObjects.compactMap { $0 as? URL }
            allMP4URLs = allURLs.filter { $0.pathExtension.lowercased() == "mp4" }
        }
        
        print("🔍 Found \(allMP4URLs.count) MP4 files in folder before processing")
        
        // Now process the collected URLs (can be done async-safely)
        var mp4Files: [URL] = []
        
        for fileURL in allMP4URLs {
            // Try to create individual file bookmark for persistent access
            var hasIndividualBookmark = false
            
            // First, try to get individual security-scoped access
            if fileURL.startAccessingSecurityScopedResource() {
                do {
                    let fileBookmark = try fileURL.bookmarkData(
                        options: .suitableForBookmarkFile,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    
                    // Store bookmark with filename as key
                    let bookmarkKey = "fileBookmark_\(fileURL.lastPathComponent)"
                    UserDefaults.standard.set(fileBookmark, forKey: bookmarkKey)
                    
                    hasIndividualBookmark = true
                    print("📁 Created individual bookmark for: \(fileURL.lastPathComponent)")
                    
                } catch {
                    print("⚠️ Failed to create individual bookmark for \(fileURL.lastPathComponent): \(error)")
                }
                
                // Stop accessing individual security scope (we'll rely on folder scope for now)
                fileURL.stopAccessingSecurityScopedResource()
            } else {
                print("⚠️ Failed to get individual security-scoped access for: \(fileURL.lastPathComponent)")
            }
            
            // Always add the file to the list - we have folder-level access
            // The file should be accessible through the folder's security scope
            mp4Files.append(fileURL)
            
            if hasIndividualBookmark {
                print("✅ Added file with individual bookmark: \(fileURL.lastPathComponent)")
            } else {
                print("📂 Added file with folder-level access: \(fileURL.lastPathComponent)")
            }
        }
        
        print("✅ Scanned folder: \(mp4Files.count) MP4 files found (with folder-level access)")
        
        // Sort alphabetically for consistent ordering
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
        notificationsEnabled = true
        autoProcessingEnabled = true
        storageOptimizationEnabled = true
        swipeToDeleteEnabled = false  // Reset to default OFF state
        
        // Clear file processing results
        filePickerService.clearResults()
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

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel = SettingsViewModel()
    @State private var showingClearSongsAlert = false
    @State private var showingCompletionOverlay = false
    @State private var hasCompletionResults = false  // Track when results are ready to show
    @State private var wasProcessingCancelled = false  // Track if processing was cancelled

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
            
            // TOP-LEVEL REACTIVE PROGRESS OVERLAY
            // Show during processing OR when completion results are available
            if viewModel.isProcessingFiles || (hasCompletionResults && !viewModel.filePickerService.results.isEmpty) {
                
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 16) {
                            // Show different content based on processing state  
                            if hasCompletionResults && !viewModel.isProcessingFiles {
                                // Completion/Cancellation Status
                                VStack(spacing: 16) {
                                    if !wasProcessingCancelled {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.green)
                                        
                                        VStack(spacing: 8) {
                                            Text("Processing Complete!")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            
                                            let stats = viewModel.filePickerService.processingStats
                                            Text("\(stats.successful) successful, \(stats.failed) failed")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    } else {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 60))
                                            .foregroundColor(.orange)
                                        
                                        VStack(spacing: 8) {
                                            Text("Processing Cancelled")
                                                .font(.title2)
                                                .fontWeight(.bold)
                                                .foregroundColor(.white)
                                            
                                            let stats = viewModel.filePickerService.processingStats
                                            Text("\(stats.successful) processed before cancellation")
                                                .font(.subheadline)
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                    }
                                }
                            } else {
                                // Active Processing - Circular progress with percentage
                                ZStack {
                                    Circle()
                                        .stroke(Color.white.opacity(0.3), lineWidth: 8)
                                        .frame(width: 120, height: 120)
                                    
                                    Circle()
                                        .trim(from: 0, to: max(0, min(1, viewModel.processingProgress / 100.0)))
                                        .stroke(AppTheme.settingsResetIconBlue, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                                        .frame(width: 120, height: 120)
                                        .rotationEffect(.degrees(-90))
                                        .animation(.easeInOut(duration: 0.5), value: viewModel.processingProgress)
                                    
                                    VStack(spacing: 4) {
                                        Text("\(Int(viewModel.processingProgress))%")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                        
                                        Text(viewModel.processingFileCount)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                }
                            }
                            
                            VStack(spacing: 8) {
                                if viewModel.filePickerService.processingState == .completed || viewModel.filePickerService.processingState == .cancelled {
                                    // Completion/Cancellation State
                                    VStack(spacing: 12) {
                                        Text(!wasProcessingCancelled ? 
                                             "All files processed successfully!" : 
                                             "Processing was cancelled")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .multilineTextAlignment(.center)
                                        
                                        // Completion Action Buttons
                                        HStack(spacing: 16) {
                                            Button(action: {
                                                // Show detailed completion results overlay
                                                showingCompletionOverlay = true
                                                print("📊 Showing detailed completion results overlay")
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "doc.text.magnifyingglass")
                                                    Text("Show Report")
                                                }
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(AppTheme.settingsResetIconBlue)
                                                )
                                            }
                                            
                                            Button(action: {
                                                // GENTLE DISMISS: Hide overlay but preserve results for "Show Report"
                                                hasCompletionResults = false
                                                wasProcessingCancelled = false
                                                print("✅ Dismissed completion overlay, results preserved for Show Report")
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "xmark")
                                                    Text("Dismiss")
                                                }
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 12)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.6))
                                                )
                                            }
                                        }
                                    }
                                } else {
                                    // Active Processing State
                                    Text("Processing MP4 Files")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    
                                    if !viewModel.processingFileName.isEmpty {
                                        Text(viewModel.processingFileName)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.9))
                                            .lineLimit(1)
                                            .frame(maxWidth: 250)
                                    }
                                    
                                    if !viewModel.processingBatch.isEmpty && viewModel.processingBatch != "Batch 0 of 0" {
                                        Text(viewModel.processingBatch)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    
                                    // Processing Control Buttons
                                    HStack(spacing: 16) {
                                        if viewModel.filePickerService.processingState == .processing {
                                            Button(action: {
                                                viewModel.pauseFileProcessing()
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "pause.fill")
                                                    Text("Pause")
                                                }
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.orange.opacity(0.8))
                                                )
                                            }
                                        } else if viewModel.filePickerService.processingState == .paused {
                                            Button(action: {
                                                Task {
                                                    await viewModel.resumeFileProcessing()
                                                }
                                            }) {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "play.fill")
                                                    Text("Continue")
                                                }
                                                .font(.caption)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.green.opacity(0.8))
                                                )
                                            }
                                        }
                                        
                                        // Cancel Button
                                        Button(action: {
                                            viewModel.cancelFileProcessing()
                                        }) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "xmark.circle.fill")
                                                Text("Cancel")
                                            }
                                            .font(.caption)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 8)
                                            .background(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Color.red.opacity(0.8))
                                            )
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .padding(32)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.black.opacity(0.8))
                                .shadow(radius: 20)
                        )
                        Spacer()
                    }
                    Spacer()
                }
                .background(Color.black.opacity(0.4))
                .ignoresSafeArea()
                .transition(.opacity.combined(with: .scale).animation(.easeInOut(duration: 0.3)))
                .onAppear {
                    print("🎯 TOP-LEVEL PROGRESS OVERLAY APPEARED!")
                }
                .onDisappear {
                    print("🎯 TOP-LEVEL PROGRESS OVERLAY DISAPPEARED!")
                }
            }
            
            // SECONDARY DEBUG OVERLAY - Always shows when processing
            if viewModel.isProcessingFiles {
                VStack {
                    HStack {
                        Spacer()
                        VStack {
                            Text("🔄 PROCESSING \(viewModel.processingFileCount)")
                                .foregroundColor(.white)
                                .padding(8)
                                .background(Color.green.opacity(0.8))
                                .cornerRadius(8)
                        }
                        .padding()
                    }
                    Spacer()
                }
                .onAppear {
                    print("🔴 SECONDARY DEBUG OVERLAY APPEARED!")
                }
            }
            

            
            // Completion Results Overlay - persistent until dismissed
            if showingCompletionOverlay && !viewModel.filePickerService.results.isEmpty {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .transition(.opacity.animation(.easeInOut(duration: 0.3)))
                
                CompletionResultsOverlay(
                    results: viewModel.filePickerService.results,
                    filePickerService: viewModel.filePickerService,
                    onDismiss: {
                        showingCompletionOverlay = false
                    },
                    onShowDetails: {
                        showingCompletionOverlay = false
                        viewModel.isShowingResults = true
                    }
                )
                .transition(.scale(scale: 0.8).combined(with: .opacity).animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0)))
            }
        }
        .sheet(isPresented: $viewModel.isShowingFilePicker) {
            FilePickerView(
                isPresented: $viewModel.isShowingFilePicker,
                onFilesSelected: viewModel.handleFilesSelected,
                onError: viewModel.handleFilePickerError,
                filePickerService: viewModel.filePickerService
            )
        }
        .sheet(isPresented: $viewModel.isShowingFolderPicker) {
            FolderPickerView(
                isPresented: $viewModel.isShowingFolderPicker,
                onFolderSelected: viewModel.handleFolderSelected,
                onError: viewModel.handleFilePickerError
            )
        }
        .sheet(isPresented: $viewModel.isShowingResults) {
            FileProcessingResultsView(
                results: viewModel.filePickerService.results,
                onDismiss: {
                    viewModel.isShowingResults = false
                    viewModel.filePickerService.clearResults()
                    // Clear completion results flag when results are fully cleared
                    hasCompletionResults = false
                    wasProcessingCancelled = false
                }
            )
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { 
                    viewModel.isShowingErrorAlert && 
                    viewModel.filePickerService.processingState != .processing && 
                    viewModel.filePickerService.processingState != .completed 
                },
                set: { viewModel.isShowingErrorAlert = $0 }
            )
        ) {
            Button("OK") {
                viewModel.isShowingErrorAlert = false
                viewModel.errorAlert = nil
                // Clear the service error as well
                viewModel.filePickerService.currentError = nil
            }

        } message: {
            if let error = viewModel.filePickerService.currentError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    if let localizedError = error as? LocalizedError,
                       let recovery = localizedError.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            } else if let errorAlert = viewModel.errorAlert {
                Text(errorAlert.message)
            }
        }
        .alert(
            "Warning!",
            isPresented: $showingClearSongsAlert
        ) {
            Button("Cancel", role: .cancel) {
                showingClearSongsAlert = false
            }
            Button("Continue", role: .destructive) {
                Task {
                    await clearAllCoreDataSongs()
                }
                showingClearSongsAlert = false
            }
        } message: {
            Text("This will delete all the songs in the SONG LIST")
        }
        .onChange(of: viewModel.filePickerService.processingState) { oldState, newState in
            print("🎯 Processing state: \(oldState) → \(newState)")
            
            // Set completion results flag when processing finishes
            if (oldState == .processing || oldState == .paused) && (newState == .completed || newState == .cancelled) {
                hasCompletionResults = true
                wasProcessingCancelled = (newState == .cancelled)
                print("✅ Completion results now available for display (cancelled: \(wasProcessingCancelled))")
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
    
    private func estimatedProcessingTime(for fileCount: Int) -> String {
        let avgTimePerFile: Double = 2.0  // seconds
        let totalSeconds = Double(fileCount) * avgTimePerFile
        
        let hours = Int(totalSeconds) / 3600
        let minutes = Int(totalSeconds) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes) minutes"
        } else {
            return "< 1 minute"
        }
    }
    
    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            // AirPlay section - at the top
            airPlaySection
            
            // Download MP4 files section
            downloadSection
            
            // Song List Management section
            songListManagementSection
            
            // App Settings section
            appSettingsSection
            
            // Other Settings section
            otherSettingsSection
            
            // Account section
            accountSection
            
            // App Info section
            appInfoSection
            
            // Storage Management
            Section("Storage") {
            }
        }
    }
    
    // MARK: - AirPlay Section
    
    private var airPlaySection: some View {
        SettingsSection(title: "AirPlay", icon: "airplayaudio") {
            HStack(spacing: 12) {
                Image(systemName: "airplayaudio")
                    .foregroundColor(.blue)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connect to Apple TV")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.settingsText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Stream to AirPlay devices")
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.settingsText.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // AirPlay picker
                AirPlayPickerViewWrapper()
                    .frame(width: 44, height: 44)
                    .padding(.trailing, -20)  // Negative padding to move the icon further rightay icon
            }
            .padding(.horizontal, 32)  // Increased from 16 to 32 to match other sections
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsText.opacity(0.05))
            )
        }
    }
    
    // MARK: - Debug Methods (temporary for troubleshooting)
    
    private func printAllCoreDataSongs() async {
        print("🚀 DEBUG: printAllCoreDataSongs() function called!")
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]
        
        print("📋 DEBUG: About to fetch songs from Core Data...")
        
        do {
            let songs = try context.fetch(request)
            print("🔍 DEBUG: Found \(songs.count) songs in Core Data:")
            
            if songs.isEmpty {
                print("⚠️ DEBUG: No songs found in Core Data - the song list might be empty or stored differently")
            } else {
                for (index, song) in songs.enumerated() {
                    print("  \(index + 1). '\(song.title ?? "Unknown")' by '\(song.artist ?? "Unknown")'")
                    print("     - Added: \(song.dateAdded ?? Date())")
                    print("     - Duration: \(song.duration)s")
                    print("     - File: \(song.filePath ?? "Unknown")")
                    print("     - ID: \(song.id?.uuidString ?? "Unknown")")
                }
            }
        } catch {
            print("❌ DEBUG: Error fetching Core Data songs: \(error)")
            print("❌ DEBUG: Error details: \(error.localizedDescription)")
        }
        
        print("✅ DEBUG: printAllCoreDataSongs() function completed!")
    }
    
    private func clearAllCoreDataSongs() async {
        print("\n🗑️ DEBUG: Starting complete cleanup")
        
        let context = PersistenceController.shared.container.viewContext
        let request: NSFetchRequest<SongEntity> = SongEntity.fetchRequest()
        
        do {
            let songs = try context.fetch(request)
            print("📊 Found \(songs.count) songs to clean up")
            
            // Get the app's Documents/Media directory path
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Could not access documents directory")
                return
            }
            let mediaDirectory = documentsDirectory.appendingPathComponent("Media")
            let mediaPath = mediaDirectory.path
            
            // Clean up UserDefaults bookmarks
            print("🧹 Cleaning up all file bookmarks...")
            let userDefaults = UserDefaults.standard
            let allKeys = userDefaults.dictionaryRepresentation().keys
            for key in allKeys {
                if key.hasPrefix("fileBookmark_") {
                    userDefaults.removeObject(forKey: key)
                    print("  ✅ Removed bookmark: \(key)")
                }
            }
            
            // Process each song
            for song in songs {
                if let filePath = song.filePath {
                    let fileName = URL(fileURLWithPath: filePath).lastPathComponent
                    
                    // Check if this is an internal file
                    if filePath.hasPrefix(mediaPath) {
                        print("\n📱 Processing internal file: \(fileName)")
                        
                        // Delete MP4 file
                        if FileManager.default.fileExists(atPath: filePath) {
                            try FileManager.default.removeItem(atPath: filePath)
                            print("  ✅ Deleted MP4 file")
                        }
                        
                        // Delete LRC file if exists
                        if let lrcPath = song.lrcFilePath,
                           FileManager.default.fileExists(atPath: lrcPath) {
                            try FileManager.default.removeItem(atPath: lrcPath)
                            print("  ✅ Deleted LRC file")
                        }
                    } else {
                        print("\n📁 Processing external file: \(fileName)")
                    }
                }
                
                // Delete Core Data entity
                context.delete(song)
                print("  ✅ Deleted song data from database")
            }
            
            // Save Core Data changes
            try context.save()
            print("\n✅ Cleanup complete:")
            print("  - Deleted \(songs.count) songs from database")
            print("  - Cleaned up all file bookmarks")
            print("  - Removed all internal files")
            
        } catch {
            print("\n❌ Error during cleanup: \(error.localizedDescription)")
        }
    }
    
    private var downloadSection: some View {
        SettingsSection(title: "Download MP4 files", icon: "arrow.down.circle") {
            VStack(spacing: 12) {
                if viewModel.filePickerService.processingState == .idle {
                    VStack(spacing: 16) {
                        FilePickerRow(
                            title: "📁 Access MP4 Folder",
                            subtitle: "✅ RECOMMENDED: Select folder with MP4s",
                            icon: "folder.badge.gearshape",
                            isEnabled: true,
                            isLoading: false
                        ) {
                            viewModel.selectMP4Folder()
                        }
                        
                        FilePickerRow(
                            title: "📄 Select Individual Files",
                            subtitle: "⚠️ Select up to 30 files to prevent crashes",
                            icon: "folder.badge.plus",
                            isEnabled: viewModel.isFilePickerEnabled,
                            isLoading: false
                        ) {
                            viewModel.openFilePicker()
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        FilePickerRow(
                            title: "Processing Files...",
                            subtitle: viewModel.statusMessage,
                            isEnabled: false,
                            isLoading: true,
                            action: {}
                        )
                        
                        // Compact Progress Summary - show during processing
                        if viewModel.filePickerService.processingState == .processing || viewModel.filePickerService.processingState == .paused {
                            CompactProgressView(
                                progress: viewModel.filePickerService.batchProgress,
                                filePickerService: viewModel.filePickerService
                            )
                        }
                    }
                }
                
                // Control buttons based on processing state
                HStack(spacing: 12) {
                    if !viewModel.filePickerService.results.isEmpty && viewModel.filePickerService.processingState == .idle {
                        Button("Show Last Results") {
                            viewModel.isShowingResults = true
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.settingsResetIconBlue)
                    }
                    
                    if viewModel.filePickerService.canRestart {
                        Button("Restart Download") {
                            Task {
                                await viewModel.restartFileProcessing()
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.green)
                    }
                    
                    if viewModel.filePickerService.processingState != .processing && !viewModel.filePickerService.results.isEmpty {
                        Button("Clear All") {
                            Task {
                                await viewModel.clearAllFiles()
                                // Clear completion results flag when results are cleared
                                hasCompletionResults = false
                                wasProcessingCancelled = false
                            }
                        }
                        .font(.subheadline)
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                
                if viewModel.filePickerService.processingState == .processing || viewModel.filePickerService.processingState == .paused {
                    ProcessingProgressView(
                        progress: viewModel.filePickerService.batchProgress,
                        filePickerService: viewModel.filePickerService
                    )
                } else if viewModel.filePickerService.processingState == .completed && !viewModel.filePickerService.results.isEmpty {
                    // Show completion summary in download section too
                    VStack(spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 16))
                            
                            Text("Processing Complete!")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppTheme.settingsText)
                            
                            Spacer()
                        }
                        
                        HStack {
                            Text("Tap above for detailed results")
                                .font(.caption)
                                .foregroundColor(AppTheme.settingsText.opacity(0.7))
                            
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                            .fill(.green.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                                    .stroke(.green.opacity(0.3), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }
    
    // MARK: - Song List Management Section
    
    private var songListManagementSection: some View {
        SettingsSection(title: "SONG LIST Management", icon: "music.note.list") {
            VStack(spacing: 8) {
                SettingRow(
                    title: "Show All Core Data Songs",
                    subtitle: "Display all songs in the console for debugging",
                    icon: "list.bullet",
                    iconColor: .blue,
                    accessoryType: .disclosure
                ) {
                    Task {
                        await printAllCoreDataSongs()
                    }
                }
                
                SettingRow(
                    title: "Clear All Core Data Songs",
                    subtitle: "Remove all songs and associated files permanently",
                    icon: "trash.fill",
                    iconColor: .red,
                    accessoryType: .disclosure
                ) {
                    showingClearSongsAlert = true
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
                
                SettingRow(
                    title: "Enable Swipe to Delete",
                    subtitle: "Allow swiping left on songs to delete them",
                    icon: "trash",
                    accessoryType: .toggle($viewModel.swipeToDeleteEnabled)
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
    let progress: BatchProgress
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // State indicator
            HStack {
                statusIcon
                Text(statusText)
                    .font(.headline)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
            }
            
            // Overall Progress Section
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Overall Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.settingsText)
                    
                    Spacer()
                    
                    Text(progress.progressText)
                        .font(.caption)
                        .foregroundColor(AppTheme.settingsText.opacity(0.7))
                }
                
                // Overall progress bar
                ProgressView(value: max(0, min(1, progress.overallProgress)))
                    .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.settingsResetIconBlue))
                    .scaleEffect(y: 1.5)
                
                HStack {
                    Text("\(Int(progress.overallProgress * 100))% Complete")
                        .font(.caption)
                        .foregroundColor(AppTheme.settingsText.opacity(0.8))
                    
                    Spacer()
                    
                    if let timeRemaining = progress.estimatedTimeRemaining {
                        Text("~\(formatTimeRemaining(timeRemaining)) remaining")
                            .font(.caption)
                            .foregroundColor(AppTheme.settingsText.opacity(0.6))
                    }
                }
            }
            
            // Batch Progress Section
            if progress.totalBatches > 1 {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(progress.batchText)
                            .font(.subheadline)
                            .foregroundColor(AppTheme.settingsText.opacity(0.9))
                        
                        Spacer()
                        
                        Text("\(Int(progress.currentBatchProgress * 100))% of current batch")
                            .font(.caption2)
                            .foregroundColor(AppTheme.settingsText.opacity(0.6))
                    }
                    
                    ProgressView(value: max(0, min(1, progress.currentBatchProgress)))
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(y: 1.0)
                }
            }
            
            // Statistics
            HStack(spacing: 16) {
                StatView(icon: "checkmark.circle.fill", color: .green, 
                        value: progress.successfulFiles, label: "Success")
                StatView(icon: "xmark.circle.fill", color: .red, 
                        value: progress.failedFiles, label: "Failed")
                StatView(icon: "repeat.circle.fill", color: .yellow, 
                        value: progress.duplicateFiles, label: "Duplicates")
            }
            
            // Control Buttons
            HStack(spacing: 12) {
                if filePickerService.canPause {
                    Button("Pause") {
                        filePickerService.pauseProcessing()
                    }
                    .buttonStyle(ControlButtonStyle(color: .orange))
                }
                
                if filePickerService.canResume {
                    Button("Resume") {
                        Task {
                            await filePickerService.resumeProcessing()
                        }
                    }
                    .buttonStyle(ControlButtonStyle(color: .blue))
                }
                
                if filePickerService.canRestart {
                    Button("Restart") {
                        Task {
                            await filePickerService.restartProcessing()
                        }
                    }
                    .buttonStyle(ControlButtonStyle(color: .green))
                }
                
                Button(filePickerService.processingState == .processing ? "Cancel" : "Clear") {
                    if filePickerService.processingState == .processing {
                        filePickerService.cancelProcessing()
                    } else {
                        Task {
                            await filePickerService.resetAndClearFiles()
                        }
                    }
                }
                .buttonStyle(ControlButtonStyle(color: .red))
                
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsText.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsResetIconBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch filePickerService.processingState {
        case .processing:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
        default:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.system(size: 20))
        }
    }
    
    private var statusText: String {
        switch filePickerService.processingState {
        case .processing:
            return "Processing Files..."
        case .paused:
            return "Processing Paused"
        case .completed:
            return "Processing Complete"
        case .cancelled:
            return "Processing Cancelled"
        default:
            return "Ready"
        }
    }
    
    private func formatTimeRemaining(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct StatView: View {
    let icon: String
    let color: Color
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.settingsText)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.settingsText.opacity(0.6))
        }
    }
}

struct ControlButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(configuration.isPressed ? 0.3 : 0.2))
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
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

// MARK: - Compact Progress View

struct CompactProgressView: View {
    let progress: BatchProgress
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        VStack(spacing: 8) {
            // Progress bar with percentage
            HStack {
                ProgressView(value: max(0, min(1, progress.overallProgress)))
                    .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.settingsResetIconBlue))
                    .scaleEffect(y: 1.5)
                
                Text("\(Int(progress.overallProgress * 100))%")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppTheme.settingsText)
                    .frame(minWidth: 40)
            }
            
            // Current file and stats
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let currentFileName = progress.currentFileName {
                        Text("Processing: \(currentFileName)")
                            .font(.caption)
                            .foregroundColor(AppTheme.settingsText.opacity(0.8))
                            .lineLimit(1)
                    }
                    
                    HStack(spacing: 12) {
                        Text("\(progress.completedFiles)/\(progress.totalFiles) files")
                            .font(.caption2)
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                        
                        if let timeRemaining = progress.estimatedTimeRemaining {
                            Text("~\(formatCompactTime(timeRemaining)) left")
                                .font(.caption2)
                                .foregroundColor(AppTheme.settingsResetIconBlue)
                        }
                    }
                }
                
                Spacer()
                
                // Mini stats
                HStack(spacing: 8) {
                    CompactStatBadge(
                        value: progress.successfulFiles,
                        color: .green,
                        icon: "checkmark"
                    )
                    
                    if progress.failedFiles > 0 {
                        CompactStatBadge(
                            value: progress.failedFiles,
                            color: .red,
                            icon: "xmark"
                        )
                    }
                    
                    if progress.duplicateFiles > 0 {
                        CompactStatBadge(
                            value: progress.duplicateFiles,
                            color: .orange,
                            icon: "repeat"
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsResetIconBlue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsResetIconBlue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    private func formatCompactTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct CompactStatBadge: View {
    let value: Int
    let color: Color
    let icon: String
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(color)
            
            Text("\(value)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(AppTheme.settingsText)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(color.opacity(0.2))
        )
    }
}

// MARK: - Enhanced Progress Overlay

struct EnhancedProgressOverlay: View {
    let progress: BatchProgress
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        VStack(spacing: 32) {
            // Title
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(AppTheme.settingsResetIconBlue)
                
                Text("Processing MP4 Files")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.settingsText)
            }
            
            // Main Progress Circle
            ZStack {
                Circle()
                    .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: max(0, min(1, progress.overallProgress)))
                    .stroke(
                        AppTheme.settingsResetIconBlue,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: progress.overallProgress)
                
                VStack(spacing: 4) {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.settingsText)
                    
                    Text("\(progress.completedFiles) of \(progress.totalFiles)")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.settingsText.opacity(0.8))
                    
                    if let timeRemaining = progress.estimatedTimeRemaining {
                        Text("~\(formatTime(timeRemaining)) left")
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsResetIconBlue)
                    }
                }
            }
            
            // Current File Info
            VStack(spacing: 8) {
                if let currentFileName = progress.currentFileName {
                    VStack(spacing: 4) {
                        Text("Currently Processing:")
                            .font(.caption)
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                        
                        Text(currentFileName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(AppTheme.settingsText)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                }
                
                // Batch info if multiple batches
                if progress.totalBatches > 1 {
                    HStack(spacing: 12) {
                        Text("Batch \(progress.currentBatch)/\(progress.totalBatches)")
                            .font(.caption)
                            .foregroundColor(AppTheme.settingsText.opacity(0.8))
                        
                        ProgressView(value: max(0, min(1, progress.currentBatchProgress)))
                            .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.settingsResetIconBlue))
                            .frame(width: 100)
                    }
                }
            }
            
            // Statistics Row
            HStack(spacing: 24) {
                OverlayStatView(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: progress.successfulFiles,
                    label: "Success"
                )
                
                OverlayStatView(
                    icon: "xmark.circle.fill",
                    color: .red,
                    value: progress.failedFiles,
                    label: "Failed"
                )
                
                OverlayStatView(
                    icon: "repeat.circle.fill",
                    color: .orange,
                    value: progress.duplicateFiles,
                    label: "Duplicates"
                )
            }
            
            // Control Buttons
            HStack(spacing: 16) {
                if filePickerService.canPause {
                    Button("⏸ Pause") {
                        filePickerService.pauseProcessing()
                    }
                    .buttonStyle(OverlayButtonStyle(color: .orange))
                }
                
                Button("✕ Cancel") {
                    filePickerService.cancelProcessing()
                }
                .buttonStyle(OverlayButtonStyle(color: .red))
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.settingsBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(AppTheme.settingsResetIconBlue.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 500)
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

struct OverlayStatView: View {
    let icon: String
    let color: Color
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 20))
            
            Text("\(value)")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(AppTheme.settingsText)
            
            Text(label)
                .font(.caption)
                .foregroundColor(AppTheme.settingsText.opacity(0.7))
        }
        .frame(minWidth: 60)
    }
}

struct OverlayButtonStyle: ButtonStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Completion Results Overlay

struct CompletionResultsOverlay: View {
    let results: [FileProcessingResult]
    @ObservedObject var filePickerService: EnhancedFilePickerService
    let onDismiss: () -> Void
    let onShowDetails: () -> Void
    
    private var stats: (successful: Int, failed: Int, duplicates: Int) {
        let successful = results.filter { $0.status == .success }.count
        let failed = results.filter { $0.status == .failed }.count
        let duplicates = results.filter { $0.status == .duplicate }.count
        return (successful, failed, duplicates)
    }
    
    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.green)
                
                Text("Download Complete!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.settingsText)
            }
            
            // Summary Stats
            HStack(spacing: 32) {
                CompletionStatView(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: stats.successful,
                    label: "Successful"
                )
                
                if stats.failed > 0 {
                    CompletionStatView(
                        icon: "xmark.circle.fill",
                        color: .red,
                        value: stats.failed,
                        label: "Failed"
                    )
                }
                
                if stats.duplicates > 0 {
                    CompletionStatView(
                        icon: "repeat.circle.fill",
                        color: .orange,
                        value: stats.duplicates,
                        label: "Duplicates"
                    )
                }
            }
            
            // Total processed
            Text("Processed \(results.count) files")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(AppTheme.settingsText.opacity(0.8))
            
            // Action Buttons
            HStack(spacing: 16) {
                Button("Show Details") {
                    onShowDetails()
                }
                .buttonStyle(OverlayButtonStyle(color: AppTheme.settingsResetIconBlue))
                
                Button("Done") {
                    onDismiss()
                }
                .buttonStyle(OverlayButtonStyle(color: .green))
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(AppTheme.settingsBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(.green.opacity(0.3), lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
        )
        .frame(maxWidth: 500)
    }
}

struct CompletionStatView: View {
    let icon: String
    let color: Color
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 24))
            
            Text("\(value)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(AppTheme.settingsText)
            
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.settingsText.opacity(0.7))
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Folder Picker View

struct FolderPickerView: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onFolderSelected: (URL) -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: [.folder],
            asCopy: false  // Important: Don't copy, we want direct access
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false // Only select one folder
        picker.modalPresentationStyle = .formSheet
        
        if #available(iOS 14.0, *) {
            picker.shouldShowFileExtensions = true
        }
        
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: FolderPickerView
        
        init(_ parent: FolderPickerView) {
            self.parent = parent
            super.init()
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.isPresented = false
            
            guard let folderURL = urls.first else {
                parent.onError(FilePickerError.processingFailed(reason: "No folder selected"))
                return
            }
            
            print("📁 Folder selected: \(folderURL.path)")
            parent.onFolderSelected(folderURL)
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
            print("📁 Folder selection cancelled")
        }
    }
}

// MARK: - Preview

// MARK: - AirPlay Picker Component

/// SwiftUI wrapper for AVRoutePickerView providing standard Apple AirPlay functionality
struct AirPlayPickerViewWrapper: UIViewRepresentable {
    
    func makeUIView(context: Context) -> AVRoutePickerView {
        let routePicker = AVRoutePickerView()
        
        // Configure the route picker appearance
        routePicker.backgroundColor = UIColor.clear
        routePicker.tintColor = UIColor.systemBlue
        
        // Set the priority for AirPlay routes
        routePicker.prioritizesVideoDevices = true
        
        return routePicker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        // No updates needed for this implementation
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
