import Foundation
import AVFoundation

// MARK: - Protocol Definition

protocol MediaMetadataServiceProtocol {
    func validateMP4File(at url: URL, processingMode: ProcessingMode) async throws
    func extractMetadata(from url: URL) async throws -> MediaMetadata
}

// MARK: - Service Implementation

final class MediaMetadataService: MediaMetadataServiceProtocol {
    private let fileManager: FileManager
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    func validateMP4File(at url: URL, processingMode: ProcessingMode = .filePickerCopy) async throws {
        // Check file size constraints based on processing mode
        try validateFileSize(at: url, processingMode: processingMode)
        
        // Verify it's a valid media file
        try await validateMediaFile(at: url)
    }
    
    func extractMetadata(from url: URL) async throws -> MediaMetadata {
        let asset = AVAsset(url: url)
        
        // Load basic properties
        let duration = try await asset.load(.duration)
        let tracks = try await asset.load(.tracks)
        
        // Get file size
        let fileSize = try getFileSize(at: url)
        
        // Extract track-specific metadata
        var metadata = MediaMetadata(
            duration: duration.seconds,
            fileSizeBytes: fileSize,
            audioBitRate: 0,
            videoBitRate: 0,
            totalBitRate: 0,
            audioChannelCount: 2,
            pixelWidth: 0,
            pixelHeight: 0,
            mediaTypes: []
        )
        
        // Process each track
        for track in tracks {
            let mediaType = track.mediaType
            metadata.mediaTypes.append(mediaType.rawValue)
            
            if mediaType == .audio {
                try await extractAudioMetadata(from: track, into: &metadata)
            } else if mediaType == .video {
                try await extractVideoMetadata(from: track, into: &metadata)
            }
        }
        
        metadata.totalBitRate = metadata.audioBitRate + metadata.videoBitRate
        
        return metadata
    }
    
    // MARK: - Private Helper Methods
    
    private func validateFileSize(at url: URL, processingMode: ProcessingMode) throws {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? Int64 else {
            throw MediaMetadataError.invalidFileSize
        }
        
        let minSize: Int64 = 5 * 1024 * 1024  // 5MB (keep for quality control)
        
        // Only apply max size limit when copying files to app storage
        if processingMode == .filePickerCopy {
            let maxSize: Int64 = 200 * 1024 * 1024  // 200MB
            guard fileSize >= minSize && fileSize <= maxSize else {
                throw MediaMetadataError.fileSizeOutOfRange(current: fileSize, min: minSize, max: maxSize)
            }
        } else {
            // For direct folder access, only check minimum size for quality
            guard fileSize >= minSize else {
                throw MediaMetadataError.fileSizeTooSmall(current: fileSize, min: minSize)
            }
        }
    }
    
    private func validateMediaFile(at url: URL) async throws {
        let asset = AVAsset(url: url)
        
        // Check if asset is readable
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            throw MediaMetadataError.unreadableFile
        }
        
        // Verify duration is valid
        let duration = try await asset.load(.duration)
        guard duration.seconds > 0 && duration.seconds.isFinite else {
            throw MediaMetadataError.invalidDuration
        }
        
        // Check for supported tracks
        let tracks = try await asset.load(.tracks)
        let hasValidTracks = tracks.contains { track in
            track.mediaType == .audio || track.mediaType == .video
        }
        
        guard hasValidTracks else {
            throw MediaMetadataError.noValidTracks
        }
    }
    
    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func extractAudioMetadata(from track: AVAssetTrack, into metadata: inout MediaMetadata) async throws {
        // Get estimated data rate
        let estimatedDataRate = try await track.load(.estimatedDataRate)
        metadata.audioBitRate = Int32(estimatedDataRate)
        
        // Extract audio format details
        let formatDescriptions = try await track.load(.formatDescriptions)
        
        for formatDescription in formatDescriptions {
            if let audioFormat = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)?.pointee {
                metadata.audioChannelCount = Int16(audioFormat.mChannelsPerFrame)
                
                // Calculate more accurate bitrate if possible
                let sampleRate = audioFormat.mSampleRate
                let bitsPerChannel = audioFormat.mBitsPerChannel
                let channels = audioFormat.mChannelsPerFrame
                
                if sampleRate > 0 && bitsPerChannel > 0 && channels > 0 {
                    let calculatedBitrate = Int32(sampleRate * Double(bitsPerChannel) * Double(channels))
                    if calculatedBitrate > 0 {
                        metadata.audioBitRate = calculatedBitrate
                    }
                }
            }
        }
    }
    
    private func extractVideoMetadata(from track: AVAssetTrack, into metadata: inout MediaMetadata) async throws {
        // Get estimated data rate
        let estimatedDataRate = try await track.load(.estimatedDataRate)
        metadata.videoBitRate = Int32(estimatedDataRate)
        
        // Get video dimensions
        let naturalSize = try await track.load(.naturalSize)
        metadata.pixelWidth = Int32(naturalSize.width)
        metadata.pixelHeight = Int32(naturalSize.height)
        
        // Extract additional video format details
        let formatDescriptions = try await track.load(.formatDescriptions)
        
        for formatDescription in formatDescriptions {
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            if dimensions.width > 0 && dimensions.height > 0 {
                metadata.pixelWidth = dimensions.width
                metadata.pixelHeight = dimensions.height
            }
        }
    }
}

// MARK: - Supporting Types

struct MediaMetadata {
    let duration: Double
    let fileSizeBytes: Int64
    var audioBitRate: Int32
    var videoBitRate: Int32
    var totalBitRate: Int32
    var audioChannelCount: Int16
    var pixelWidth: Int32
    var pixelHeight: Int32
    var mediaTypes: [String]
    
    init(duration: Double = 0,
         fileSizeBytes: Int64 = 0,
         audioBitRate: Int32 = 0,
         videoBitRate: Int32 = 0,
         totalBitRate: Int32 = 0,
         audioChannelCount: Int16 = 2,
         pixelWidth: Int32 = 0,
         pixelHeight: Int32 = 0,
         mediaTypes: [String] = []) {
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
        self.audioBitRate = audioBitRate
        self.videoBitRate = videoBitRate
        self.totalBitRate = totalBitRate
        self.audioChannelCount = audioChannelCount
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.mediaTypes = mediaTypes
    }
}

enum MediaMetadataError: Error, LocalizedError {
    case invalidFileSize
    case fileSizeOutOfRange(current: Int64, min: Int64, max: Int64)
    case fileSizeTooSmall(current: Int64, min: Int64)
    case unreadableFile
    case invalidDuration
    case noValidTracks
    case metadataExtractionFailed
    case fileSizeTooSmall(current: Int64, min: Int64)
    
    var errorDescription: String? {
        switch self {
        case .invalidFileSize:
            return "Unable to determine file size"
        case .fileSizeOutOfRange(let current, let min, let max):
            let currentMB = current / (1024 * 1024)
            let minMB = min / (1024 * 1024)
            let maxMB = max / (1024 * 1024)
            return "File size (\(currentMB)MB) must be between \(minMB)MB and \(maxMB)MB"
        case .fileSizeTooSmall(let current, let min):
            let currentMB = current / (1024 * 1024)
            let minMB = min / (1024 * 1024)
            return "File size (\(currentMB)MB) must be at least \(minMB)MB for quality assurance"
        case .unreadableFile:
            return "The media file cannot be read or is corrupted"
        case .invalidDuration:
            return "The media file has an invalid duration"
        case .noValidTracks:
            return "No valid audio or video tracks found in the file"
        case .metadataExtractionFailed:
            return "Failed to extract metadata from the media file"
        case .fileSizeTooSmall(let current, let min):
            let currentMB = current / (1024 * 1024)
            let minMB = min / (1024 * 1024)
            return "File size (\(currentMB)MB) must be at least \(minMB)MB"
        }
    }
} 