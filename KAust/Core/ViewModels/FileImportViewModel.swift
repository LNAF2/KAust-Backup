import SwiftUI
import Combine
import CoreData
import AVFoundation
import UniformTypeIdentifiers

// MARK: - Import Operation Models

/// Represents the state of file import operation
enum ImportOperationState {
    case idle
    case validating
    case extractingMetadata
    case savingToDatabase
    case completed
    case cancelled
    case failed(Error)
    
    var isActive: Bool {
        switch self {
        case .idle, .completed, .cancelled, .failed:
            return false
        case .validating, .extractingMetadata, .savingToDatabase:
            return true
        }
    }
    
    var description: String {
        switch self {
        case .idle:
            return "Ready to import"
        case .validating:
            return "Validating files..."
        case .extractingMetadata:
            return "Extracting metadata..."
        case .savingToDatabase:
            return "Saving to database..."
        case .completed:
            return "Import completed"
        case .cancelled:
            return "Import cancelled"
        case .failed(let error):
            return "Import failed: \(error.localizedDescription)"
        }
    }
}

/// Progress information for file import operations
struct ImportProgress {
    let currentFile: Int
    let totalFiles: Int
    let fileName: String
    let operationProgress: Double // 0.0 to 1.0 for current operation
    let overallProgress: Double   // 0.0 to 1.0 for entire batch
    
    init(currentFile: Int, totalFiles: Int, fileName: String, operationProgress: Double = 0.0) {
        self.currentFile = currentFile
        self.totalFiles = totalFiles
        self.fileName = fileName
        self.operationProgress = operationProgress
        self.overallProgress = totalFiles > 0 ? 
            (Double(currentFile - 1) + operationProgress) / Double(totalFiles) : 0.0
    }
    
    var isComplete: Bool {
        currentFile >= totalFiles && operationProgress >= 1.0
    }
    
    var progressText: String {
        "Processing \(fileName) (\(currentFile) of \(totalFiles))"
    }
}

/// Result of individual file import
struct FileImportResult {
    let url: URL
    let fileName: String
    let success: Bool
    let metadata: MediaMetadata?
    let error: Error?
    let processingTime: TimeInterval
    let songEntity: SongEntity?
    
    init(
        url: URL, 
        metadata: MediaMetadata? = nil, 
        error: Error? = nil, 
        processingTime: TimeInterval,
        songEntity: SongEntity? = nil
    ) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.success = error == nil
        self.metadata = metadata
        self.error = error
        self.processingTime = processingTime
        self.songEntity = songEntity
    }
}

/// Summary of batch import operation
struct ImportBatchResult {
    let totalFiles: Int
    let successfulImports: Int
    let failedImports: Int
    let totalProcessingTime: TimeInterval
    let results: [FileImportResult]
    
    var successRate: Double {
        totalFiles > 0 ? Double(successfulImports) / Double(totalFiles) : 0.0
    }
    
    var averageProcessingTime: TimeInterval {
        successfulImports > 0 ? totalProcessingTime / Double(successfulImports) : 0.0
    }
}

// MARK: - File Import Errors

enum FileImportError: LocalizedError {
    case noFilesSelected
    case importInProgress
    case operationCancelled
    case batchProcessingFailed([Error])
    case coreDataTransactionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noFilesSelected:
            return "No files were selected for import"
        case .importInProgress:
            return "An import operation is already in progress"
        case .operationCancelled:
            return "Import operation was cancelled"
        case .batchProcessingFailed(let errors):
            return "Failed to process \(errors.count) files"
        case .coreDataTransactionFailed:
            return "Failed to save imported files to database"
        }
    }
}

// MARK: - File Import View Model

/// Main view model for orchestrating file import workflow
@MainActor
class FileImportViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current state of the import operation
    @Published private(set) var operationState: ImportOperationState = .idle
    
    /// Progress information for current import batch
    @Published private(set) var importProgress: ImportProgress?
    
    /// Results of individual file imports
    @Published private(set) var fileResults: [FileImportResult] = []
    
    /// Summary of completed batch import
    @Published private(set) var batchResult: ImportBatchResult?
    
    /// Flag indicating if cancellation was requested
    @Published private(set) var cancellationRequested = false
    
    /// Current error if any
    @Published private(set) var currentError: Error?
    
    // MARK: - Computed Properties
    
    /// Whether an import operation is currently active
    var isImporting: Bool {
        operationState.isActive
    }
    
    /// Whether import can be cancelled
    var canCancel: Bool {
        isImporting && !cancellationRequested
    }
    
    /// Whether results are available to display
    var hasResults: Bool {
        !fileResults.isEmpty
    }
    
    /// Current status message for UI display
    var statusMessage: String {
        if let progress = importProgress {
            return progress.progressText
        }
        return operationState.description
    }
    
    // MARK: - Dependencies
    
    private let dataProviderService: DataProviderServiceProtocol
    private let mediaMetadataService: MediaMetadataServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Private Properties
    
    private var currentImportTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(
        dataProviderService: DataProviderServiceProtocol = DataProviderService(),
        mediaMetadataService: MediaMetadataServiceProtocol = MediaMetadataService(),
        errorHandlingService: ErrorHandlingServiceProtocol = ErrorHandlingService()
    ) {
        self.dataProviderService = dataProviderService
        self.mediaMetadataService = mediaMetadataService
        self.errorHandlingService = errorHandlingService
    }
    
    deinit {
        currentImportTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Start importing selected files
    func importFiles(_ fileURLs: [URL]) {
        guard !fileURLs.isEmpty else {
            currentError = FileImportError.noFilesSelected
            return
        }
        
        guard !isImporting else {
            currentError = FileImportError.importInProgress
            return
        }
        
        // Reset state for new import
        resetImportState()
        
        // Start import operation
        currentImportTask = Task {
            await performBatchImport(fileURLs)
        }
    }
    
    /// Cancel current import operation
    func cancelImport() {
        guard canCancel else { return }
        
        cancellationRequested = true
        currentImportTask?.cancel()
        operationState = .cancelled
    }
    
    /// Clear import results and reset state
    func clearResults() {
        resetImportState()
        fileResults.removeAll()
        batchResult = nil
    }
    
    // MARK: - Private Import Pipeline
    
    /// Main batch import orchestrator
    private func performBatchImport(_ fileURLs: [URL]) async {
        let startTime = Date()
        var results: [FileImportResult] = []
        
        operationState = .validating
        
        for (index, fileURL) in fileURLs.enumerated() {
            // Check for cancellation
            if cancellationRequested {
                operationState = .cancelled
                return
            }
            
            // Update progress
            importProgress = ImportProgress(
                currentFile: index + 1,
                totalFiles: fileURLs.count,
                fileName: fileURL.lastPathComponent
            )
            
            // Process individual file
            let result = await importSingleFile(fileURL, fileIndex: index + 1, totalFiles: fileURLs.count)
            results.append(result)
            fileResults.append(result)
        }
        
        // Create batch result summary
        let totalTime = Date().timeIntervalSince(startTime)
        let successful = results.filter { $0.success }.count
        let failed = results.count - successful
        
        batchResult = ImportBatchResult(
            totalFiles: fileURLs.count,
            successfulImports: successful,
            failedImports: failed,
            totalProcessingTime: totalTime,
            results: results
        )
        
        operationState = .completed
        importProgress = nil
    }
    
    /// Import a single file through the complete pipeline
    private func importSingleFile(_ fileURL: URL, fileIndex: Int, totalFiles: Int) async -> FileImportResult {
        let startTime = Date()
        let fileName = fileURL.lastPathComponent
        
        do {
            // Step 1: File validation
            updateOperationProgress(0.1, for: fileIndex, of: totalFiles, fileName: fileName)
            operationState = .validating
            
            try await validateFile(fileURL)
            
            // Check cancellation
            if cancellationRequested {
                throw FileImportError.operationCancelled
            }
            
            // Step 2: Metadata extraction
            updateOperationProgress(0.4, for: fileIndex, of: totalFiles, fileName: fileName)
            operationState = .extractingMetadata
            
            let metadata = try await mediaMetadataService.extractMetadata(from: fileURL)
            
            // Check cancellation
            if cancellationRequested {
                throw FileImportError.operationCancelled
            }
            
            // Step 3: Core Data transaction
            updateOperationProgress(0.8, for: fileIndex, of: totalFiles, fileName: fileName)
            operationState = .savingToDatabase
            
            let songEntity = try await saveToDatabase(metadata: metadata, fileURL: fileURL)
            
            // Complete
            updateOperationProgress(1.0, for: fileIndex, of: totalFiles, fileName: fileName)
            
            let processingTime = Date().timeIntervalSince(startTime)
            return FileImportResult(
                url: fileURL,
                metadata: metadata,
                processingTime: processingTime,
                songEntity: songEntity
            )
            
        } catch {
            let processingTime = Date().timeIntervalSince(startTime)
            return FileImportResult(
                url: fileURL,
                error: error,
                processingTime: processingTime
            )
        }
    }
    
    /// Validate file before processing
    private func validateFile(_ fileURL: URL) async throws {
        // File size validation (5MB - 150MB)
        let fileSize = try getFileSize(fileURL)
        let minSize: Int64 = 5 * 1024 * 1024  // 5MB
        let maxSize: Int64 = 150 * 1024 * 1024  // 150MB
        
        guard fileSize >= minSize && fileSize <= maxSize else {
            throw MediaMetadataError.fileSizeOutOfRange(actual: fileSize, min: minSize, max: maxSize)
        }
        
        // File type validation
        guard fileURL.pathExtension.lowercased() == "mp4" else {
            throw MediaMetadataError.unreadableFile
        }
        
        // File accessibility validation
        guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw MediaMetadataError.unreadableFile
        }
    }
    
    /// Save extracted metadata to Core Data
    private func saveToDatabase(metadata: MediaMetadata, fileURL: URL) async throws -> SongEntity {
        // Extract title and artist from metadata or filename
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let title = metadata.title ?? fileName
        let artist = metadata.artist ?? "Unknown Artist"
        
        // Create song entity with metadata
        let songEntity = try await dataProviderService.importSong(
            title: title,
            artist: artist,
            duration: Float(metadata.duration),
            filePath: fileURL.path,
            lrcFilePath: nil,
            year: metadata.year,
            language: metadata.language,
            event: nil,
            genres: metadata.genres ?? []
        )
        
        return songEntity
    }
    
    // MARK: - Helper Methods
    
    /// Update operation progress
    private func updateOperationProgress(_ progress: Double, for fileIndex: Int, of totalFiles: Int, fileName: String) {
        importProgress = ImportProgress(
            currentFile: fileIndex,
            totalFiles: totalFiles,
            fileName: fileName,
            operationProgress: progress
        )
    }
    
    /// Get file size in bytes
    private func getFileSize(_ fileURL: URL) throws -> Int64 {
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    /// Reset import state
    private func resetImportState() {
        operationState = .idle
        importProgress = nil
        cancellationRequested = false
        currentError = nil
    }
}

// MARK: - View Model Extensions

extension FileImportViewModel {
    
    /// Get summary statistics for display
    var importStatistics: (successful: Int, failed: Int, total: Int, successRate: String) {
        let successful = fileResults.filter { $0.success }.count
        let failed = fileResults.filter { !$0.success }.count
        let total = fileResults.count
        let rate = total > 0 ? (Double(successful) / Double(total)) * 100 : 0
        let rateString = String(format: "%.1f%%", rate)
        
        return (successful, failed, total, rateString)
    }
    
    /// Get processing time summary
    var processingTimeText: String {
        let totalTime = fileResults.reduce(0) { $0 + $1.processingTime }
        if totalTime > 60 {
            let minutes = Int(totalTime) / 60
            let seconds = Int(totalTime) % 60
            return "\(minutes)m \(seconds)s"
        } else {
            return String(format: "%.1fs", totalTime)
        }
    }
    
    /// Check if there are any errors to display
    var hasErrors: Bool {
        fileResults.contains { !$0.success }
    }
    
    /// Get list of failed imports for error display
    var failedImports: [FileImportResult] {
        fileResults.filter { !$0.success }
    }
} 