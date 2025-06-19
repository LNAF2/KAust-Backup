import Foundation
import SwiftUI

// MARK: - Protocol Definition

protocol ErrorHandlingServiceProtocol {
    func handleFileProcessingError(_ error: Error, for fileName: String) -> ErrorRecoveryResult
    func createProgressConfiguration(for operation: FileOperation) -> ProgressConfiguration
    func createErrorAlert(for error: Error, retryAction: (() -> Void)?) -> ErrorAlertConfiguration
    func shouldRetryOperation(for error: Error) -> Bool
    func getRecoveryActions(for error: Error) -> [RecoveryAction]
}

// MARK: - Service Implementation

final class ErrorHandlingService: ErrorHandlingServiceProtocol {
    private let toastManager: ToastManager?
    
    init(toastManager: ToastManager? = nil) {
        self.toastManager = toastManager
    }
    
    func handleFileProcessingError(_ error: Error, for fileName: String) -> ErrorRecoveryResult {
        // Determine error severity and recovery options
        let severity = determineErrorSeverity(error)
        let recoveryActions = getRecoveryActions(for: error)
        
        // Log error for debugging
        logError(error, fileName: fileName)
        
        // Show appropriate user feedback
        showUserFeedback(for: error, fileName: fileName, severity: severity)
        
        return ErrorRecoveryResult(
            error: error,
            severity: severity,
            isRetryable: shouldRetryOperation(for: error),
            recoveryActions: recoveryActions,
            userMessage: createUserMessage(for: error, fileName: fileName)
        )
    }
    
    func createProgressConfiguration(for operation: FileOperation) -> ProgressConfiguration {
        switch operation {
        case .validation(let fileName):
            return .loading(
                title: "Validating File",
                description: "Checking '\(fileName)' for compatibility...",
                isCancellable: true
            )
            
        case .metadataExtraction(let fileName, let progress):
            return .fileProcessing(
                fileName: fileName,
                progress: progress,
                currentStep: "Extracting metadata...",
                isCancellable: true
            )
            
        case .batchProcessing(let currentFile, let totalFiles, let fileName, let progress):
            return .batchProcessing(
                currentFile: currentFile,
                totalFiles: totalFiles,
                fileName: fileName,
                progress: progress,
                isCancellable: true
            )
            
        case .saving(let fileName):
            return .loading(
                title: "Saving File",
                description: "Storing '\(fileName)' in the database...",
                isCancellable: false
            )
        }
    }
    
    func createErrorAlert(for error: Error, retryAction: (() -> Void)?) -> ErrorAlertConfiguration {
        let errorInfo = analyzeError(error)
        
        return ErrorAlertConfiguration(
            error: error,
            title: errorInfo.title,
            message: errorInfo.message,
            recoveryActions: getRecoveryActions(for: error),
            isRetryable: shouldRetryOperation(for: error),
            retryAction: retryAction
        )
    }
    
    func shouldRetryOperation(for error: Error) -> Bool {
        // Determine if the error is retryable
        if let mediaError = error as? MediaMetadataError {
            switch mediaError {
            case .fileSizeOutOfRange, .fileSizeTooSmall:
                return false // Can't retry, need different file
            case .invalidFileSize, .unreadableFile, .invalidDuration, .noValidTracks:
                return true // Might work with different file
            case .metadataExtractionFailed:
                return true // Could be temporary issue
            }
        }
        
        if let nsError = error as NSError {
            switch nsError.domain {
            case NSCocoaErrorDomain:
                // File system errors might be retryable
                return nsError.code != NSFileReadNoSuchFileError
            case NSURLErrorDomain:
                // Network errors are usually retryable
                return true
            default:
                return true
            }
        }
        
        return true // Default to retryable for unknown errors
    }
    
    func getRecoveryActions(for error: Error) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []
        
        if let mediaError = error as? MediaMetadataError {
            switch mediaError {
            case .fileSizeOutOfRange:
                actions.append(.selectDifferentFile)
                actions.append(.compressFile)
                
            case .fileSizeTooSmall:
                actions.append(.selectDifferentFile)
                
            case .unreadableFile, .noValidTracks:
                actions.append(.selectDifferentFile)
                actions.append(.checkFileFormat)
                
            case .invalidFileSize, .invalidDuration, .metadataExtractionFailed:
                actions.append(.retry)
                actions.append(.selectDifferentFile)
            }
        } else {
            // Generic recovery actions
            actions.append(.retry)
            actions.append(.selectDifferentFile)
        }
        
        actions.append(.contactSupport)
        return actions
    }
    
    // MARK: - Private Helper Methods
    
    private func determineErrorSeverity(_ error: Error) -> ErrorSeverity {
        if let mediaError = error as? MediaMetadataError {
            switch mediaError {
            case .fileSizeOutOfRange, .fileSizeTooSmall:
                return .warning // User can select different file
            case .unreadableFile, .noValidTracks:
                return .error // File is problematic
            case .invalidFileSize, .invalidDuration, .metadataExtractionFailed:
                return .warning // Might be temporary
            }
        }
        
        return .error // Default to error for unknown issues
    }
    
    private func logError(_ error: Error, fileName: String) {
        // In a real implementation, this would log to a logging service
        print("🚨 Error processing file '\(fileName)': \(error.localizedDescription)")
        
        if let mediaError = error as? MediaMetadataError {
            print("   MediaMetadataError: \(mediaError)")
        }
    }
    
    private func showUserFeedback(for error: Error, fileName: String, severity: ErrorSeverity) {
        guard let toastManager = toastManager else { return }
        
        switch severity {
        case .warning:
            toastManager.showWarning(
                title: "File Processing Issue",
                message: "Problem with '\(fileName)': \(error.localizedDescription)",
                action: ToastAction(title: "Details") {
                    // Show detailed error information
                }
            )
            
        case .error:
            toastManager.showFileProcessingError(fileName: fileName, error: error)
            
        case .critical:
            toastManager.showError(
                title: "Critical Error",
                message: "Unable to process '\(fileName)'. Please contact support.",
                duration: 8.0
            )
        }
    }
    
    private func analyzeError(_ error: Error) -> (title: String, message: String) {
        if let mediaError = error as? MediaMetadataError {
            switch mediaError {
            case .fileSizeOutOfRange(let current, let min, let max):
                let currentMB = current / (1024 * 1024)
                let minMB = min / (1024 * 1024)
                let maxMB = max / (1024 * 1024)
                return (
                    "File Size Issue",
                    "The selected file is \(currentMB)MB, but must be between \(minMB)MB and \(maxMB)MB for copied files."
                )
                
            case .fileSizeTooSmall(let current, let min):
                let currentMB = current / (1024 * 1024)
                let minMB = min / (1024 * 1024)
                return (
                    "File Too Small",
                    "The selected file is \(currentMB)MB, but must be at least \(minMB)MB for quality assurance."
                )
                
            case .unreadableFile:
                return (
                    "Corrupted File",
                    "The selected file appears to be corrupted or uses an unsupported format."
                )
                
            case .noValidTracks:
                return (
                    "Invalid Media Content",
                    "The file doesn't contain valid audio or video tracks for karaoke use."
                )
                
            case .invalidDuration:
                return (
                    "Duration Problem",
                    "The media file has an invalid duration and cannot be processed."
                )
                
            case .invalidFileSize:
                return (
                    "File Access Issue",
                    "Unable to determine the file size. The file may be inaccessible."
                )
                
            case .metadataExtractionFailed:
                return (
                    "Processing Failed",
                    "Could not extract information from the media file."
                )
            }
        }
        
        return (
            "Processing Error",
            error.localizedDescription
        )
    }
    
    private func createUserMessage(for error: Error, fileName: String) -> String {
        let analysis = analyzeError(error)
        return "\(analysis.title): \(analysis.message)"
    }
}

// MARK: - Supporting Types

enum FileOperation {
    case validation(fileName: String)
    case metadataExtraction(fileName: String, progress: Double)
    case batchProcessing(currentFile: Int, totalFiles: Int, fileName: String, progress: Double)
    case saving(fileName: String)
}

enum ErrorSeverity {
    case warning   // User can take action to resolve
    case error     // Requires user intervention
    case critical  // System-level issue
}

enum RecoveryAction {
    case retry
    case selectDifferentFile
    case compressFile
    case checkFileFormat
    case contactSupport
    
    var title: String {
        switch self {
        case .retry:
            return "Try Again"
        case .selectDifferentFile:
            return "Select Different File"
        case .compressFile:
            return "Compress File"
        case .checkFileFormat:
            return "Check File Format"
        case .contactSupport:
            return "Contact Support"
        }
    }
    
    var description: String {
        switch self {
        case .retry:
            return "Attempt to process the file again"
        case .selectDifferentFile:
            return "Choose a different MP4 file"
        case .compressFile:
            return "Reduce the file size and try again"
        case .checkFileFormat:
            return "Verify the file is a valid MP4"
        case .contactSupport:
            return "Get help from our support team"
        }
    }
}

struct ErrorRecoveryResult {
    let error: Error
    let severity: ErrorSeverity
    let isRetryable: Bool
    let recoveryActions: [RecoveryAction]
    let userMessage: String
}

struct ErrorAlertConfiguration {
    let error: Error
    let title: String
    let message: String
    let recoveryActions: [RecoveryAction]
    let isRetryable: Bool
    let retryAction: (() -> Void)?
}

// MARK: - Enhanced Error Types

extension MediaMetadataError {
    var recoverySuggestion: String? {
        switch self {
        case .fileSizeOutOfRange(let current, let min, let max):
            let currentMB = current / (1024 * 1024)
            let maxMB = max / (1024 * 1024)
            if currentMB > maxMB {
                return "Try compressing the file or selecting a smaller one, or use folder access mode for larger files."
            } else {
                return "The file is too small. Please select a larger MP4 file."
            }
            
        case .fileSizeTooSmall(let current, let min):
            let minMB = min / (1024 * 1024)
            return "Select a larger MP4 file (minimum \(minMB)MB). Small files may not provide adequate quality for karaoke use."
            
        case .unreadableFile:
            return "Verify the file isn't corrupted by playing it in another app first."
            
        case .noValidTracks:
            return "Make sure you're selecting a valid MP4 video file with both audio and video."
            
        case .invalidDuration:
            return "This usually indicates a corrupted file. Try a different MP4 file."
            
        case .invalidFileSize:
            return "Check that the file is accessible and try selecting it again."
            
        case .metadataExtractionFailed:
            return "The file may use an unsupported codec. Try converting it to a standard MP4 format."
        }
    }
} 