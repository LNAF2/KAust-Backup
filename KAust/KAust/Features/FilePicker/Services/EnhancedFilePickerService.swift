/*
 * TEMPORARILY COMMENTED OUT - DO NOT DELETE
 * This file contains the enhanced file picker service that is currently disabled
 * but may be needed in the future.
 */

/*
import Foundation
import AVFoundation

@MainActor
class EnhancedFilePickerService: ObservableObject {
    // MARK: - Published Properties
    @Published private(set) var processingState: ProcessingState = .idle
    @Published private(set) var batchProgress = BatchProgress(currentBatch: 0, totalBatches: 0, currentFile: 0, totalFiles: 0, progressText: "")
    @Published private(set) var results: [FileProcessingResult] = []
    @Published private(set) var currentError: Error?
    
    // MARK: - Processing State
    enum ProcessingState {
        case idle
        case processing
        case paused
        case completed
        case cancelled
    }
    
    // MARK: - Private Properties
    private var processingTask: Task<Void, Never>?
    private var processingMode: ProcessingMode = .singleFile
    private var folderSecurityScope: URL?
    
    enum ProcessingMode {
        case singleFile
        case directFolderAccess
    }
    
    // MARK: - Public Methods
    
    func handleFileSelection(_ urls: [URL]) {
        guard processingState != .processing else { return }
        
        processingTask = Task {
            await processFiles(urls)
        }
    }
    
    func pauseProcessing() async {
        processingState = .paused
    }
    
    func resumeProcessing() async {
        processingState = .processing
    }
    
    func clearResults() {
        results = []
        currentError = nil
        batchProgress = BatchProgress(currentBatch: 0, totalBatches: 0, currentFile: 0, totalFiles: 0, progressText: "")
    }
    
    // MARK: - Private Methods
    
    private func processFiles(_ urls: [URL]) async {
        processingState = .processing
        currentError = nil
        
        for (index, url) in urls.enumerated() {
            guard processingState != .cancelled else { break }
            
            if processingState == .paused {
                await Task.yield()
                continue
            }
            
            batchProgress = BatchProgress(
                currentBatch: 1,
                totalBatches: 1,
                currentFile: index + 1,
                totalFiles: urls.count,
                progressText: "Processing \(url.lastPathComponent)"
            )
            
            do {
                let metadata = try await extractMetadata(from: url)
                let result = FileProcessingResult(
                    url: url,
                    metadata: metadata,
                    error: nil,
                    processingTime: 0.0
                )
                results.append(result)
            } catch {
                let result = FileProcessingResult(
                    url: url,
                    metadata: nil,
                    error: error,
                    processingTime: 0.0
                )
                results.append(result)
                currentError = error
            }
        }
        
        processingState = .completed
    }
    
    private func extractMetadata(from url: URL) async throws -> MediaMetadata {
        let asset = AVAsset(url: url)
        
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw FilePickerError.processingFailed(reason: "No video track found")
        }
        
        let duration = try await asset.load(.duration).seconds
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        let resolution = try await track.load(.naturalSize)
        let bitrate = try await track.load(.estimatedDataRate)
        let codec = try await track.load(.codecType).rawValue
        
        return MediaMetadata(
            duration: duration,
            size: Int64(size),
            resolution: resolution,
            bitrate: Int(bitrate),
            codec: codec
        )
    }
}
*/ 