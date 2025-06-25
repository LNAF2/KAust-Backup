/*
 * TEMPORARILY COMMENTED OUT - DO NOT DELETE
 * This file contains the file picker models that are currently disabled
 * but may be needed in the future.
 */

/*
import Foundation

// MARK: - File Processing Models

struct FilePickerError: Error {
    let reason: String
    
    static func processingFailed(reason: String) -> FilePickerError {
        FilePickerError(reason: reason)
    }
}

struct MediaMetadata {
    let duration: TimeInterval
    let size: Int64
    let resolution: CGSize
    let bitrate: Int
    let codec: String
}

struct ProcessingStats {
    let successful: Int
    let failed: Int
    let duplicates: Int
    let totalProcessingTime: TimeInterval
}

struct BatchProgress {
    let currentBatch: Int
    let totalBatches: Int
    let currentFile: Int
    let totalFiles: Int
    let progressText: String
}
*/ 