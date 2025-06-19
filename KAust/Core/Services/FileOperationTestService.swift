import Foundation
import SwiftUI

// MARK: - Protocol Definition

protocol FileOperationTestServiceProtocol {
    func simulateFileValidation(fileName: String, shouldFail: Bool) async throws
    func simulateMetadataExtraction(fileName: String, shouldFail: Bool, progressCallback: ((Double) -> Void)?) async throws -> MediaMetadata
    func simulateBatchProcessing(fileNames: [String], progressCallback: ((Int, String, Double) -> Void)?) async throws -> [MediaMetadata]
    func createTestErrors() -> [Error]
}

// MARK: - Test Service Implementation

final class FileOperationTestService: FileOperationTestServiceProtocol {
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let toastManager: ToastManager?
    
    init(errorHandlingService: ErrorHandlingServiceProtocol, toastManager: ToastManager? = nil) {
        self.errorHandlingService = errorHandlingService
        self.toastManager = toastManager
    }
    
    func simulateFileValidation(fileName: String, shouldFail: Bool) async throws {
        // Show progress
        let progressConfig = errorHandlingService.createProgressConfiguration(
            for: .validation(fileName: fileName)
        )
        
        // Simulate validation delay
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        
        if shouldFail {
            let error = createRandomValidationError(for: fileName)
            let recoveryResult = errorHandlingService.handleFileProcessingError(error, for: fileName)
            throw error
        }
        
        // Success feedback
        toastManager?.showSuccess(
            title: "Validation Complete",
            message: "'\(fileName)' is ready for processing.",
            duration: 2.0
        )
    }
    
    func simulateMetadataExtraction(
        fileName: String,
        shouldFail: Bool,
        progressCallback: ((Double) -> Void)?
    ) async throws -> MediaMetadata {
        // Simulate progressive metadata extraction
        let steps = 10
        for step in 1...steps {
            let progress = Double(step) / Double(steps)
            progressCallback?(progress)
            
            // Simulate processing time
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            
            // Fail at random point if requested
            if shouldFail && step == 7 {
                let error = MediaMetadataError.metadataExtractionFailed
                let recoveryResult = errorHandlingService.handleFileProcessingError(error, for: fileName)
                throw error
            }
        }
        
        // Return mock metadata
        let metadata = MediaMetadata(
            duration: 180.0,
            fileSizeBytes: 45 * 1024 * 1024, // 45MB
            audioBitRate: 192000,
            videoBitRate: 2500000,
            totalBitRate: 2692000,
            audioChannelCount: 2,
            pixelWidth: 1920,
            pixelHeight: 1080,
            mediaTypes: ["vide", "soun"]
        )
        
        // Success feedback
        toastManager?.showFileProcessingSuccess(fileName: fileName)
        
        return metadata
    }
    
    func simulateBatchProcessing(
        fileNames: [String],
        progressCallback: ((Int, String, Double) -> Void)?
    ) async throws -> [MediaMetadata] {
        var results: [MediaMetadata] = []
        
        for (index, fileName) in fileNames.enumerated() {
            let currentFile = index + 1
            
            // Simulate per-file processing
            let fileSteps = 5
            for step in 1...fileSteps {
                let fileProgress = Double(step) / Double(fileSteps)
                progressCallback?(currentFile, fileName, fileProgress)
                
                try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                
                // Randomly fail some files for testing
                if fileName.contains("corrupted") && step == 3 {
                    let error = MediaMetadataError.unreadableFile
                    let recoveryResult = errorHandlingService.handleFileProcessingError(error, for: fileName)
                    
                    // Continue with next file instead of throwing
                    toastManager?.showWarning(
                        title: "Skipped Corrupted File",
                        message: "'\(fileName)' could not be processed and was skipped.",
                        duration: 3.0
                    )
                    break
                }
            }
            
            // Add successful result if not corrupted
            if !fileName.contains("corrupted") {
                let metadata = createMockMetadata(for: fileName, index: index)
                results.append(metadata)
            }
        }
        
        // Show batch completion
        toastManager?.showBatchProcessingComplete(fileCount: results.count)
        
        return results
    }
    
    func createTestErrors() -> [Error] {
        return [
            MediaMetadataError.fileSizeOutOfRange(
                current: 200 * 1024 * 1024,
                min: 5 * 1024 * 1024,
                max: 200 * 1024 * 1024
            ),
            MediaMetadataError.unreadableFile,
            MediaMetadataError.noValidTracks,
            MediaMetadataError.invalidDuration,
            MediaMetadataError.metadataExtractionFailed,
            NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoSuchFileError, userInfo: [
                NSLocalizedDescriptionKey: "File not found"
            ]),
            NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet, userInfo: [
                NSLocalizedDescriptionKey: "No internet connection"
            ])
        ]
    }
    
    // MARK: - Private Helper Methods
    
    private func createRandomValidationError(for fileName: String) -> Error {
        let errors: [MediaMetadataError] = [
            .fileSizeOutOfRange(
                current: 200 * 1024 * 1024,
                min: 5 * 1024 * 1024,
                max: 200 * 1024 * 1024
            ),
            .invalidFileSize,
            .unreadableFile
        ]
        
        return errors.randomElement() ?? MediaMetadataError.invalidFileSize
    }
    
    private func createMockMetadata(for fileName: String, index: Int) -> MediaMetadata {
        // Create varied metadata based on file name and index
        let baseDuration = 120.0 + Double(index * 30)
        let baseSize = (30 + index * 10) * 1024 * 1024 // 30MB+
        
        return MediaMetadata(
            duration: baseDuration,
            fileSizeBytes: Int64(baseSize),
            audioBitRate: 160000 + Int32(index * 32000),
            videoBitRate: 2000000 + Int32(index * 500000),
            totalBitRate: 2160000 + Int32(index * 532000),
            audioChannelCount: 2,
            pixelWidth: 1920,
            pixelHeight: 1080,
            mediaTypes: ["vide", "soun"]
        )
    }
}

// MARK: - Demo View Model

@MainActor
class ErrorHandlingDemoViewModel: ObservableObject {
    @Published var isShowingProgress = false
    @Published var progressConfiguration: ProgressConfiguration?
    @Published var isShowingErrorAlert = false
    @Published var errorAlertConfiguration: ErrorAlertConfiguration?
    @Published var processedFiles: [String] = []
    @Published var currentOperation: String = ""
    
    private let testService: FileOperationTestServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    private let toastManager: ToastManager
    
    init(
        testService: FileOperationTestServiceProtocol? = nil,
        errorHandlingService: ErrorHandlingServiceProtocol? = nil,
        toastManager: ToastManager = ToastManager()
    ) {
        self.toastManager = toastManager
        self.errorHandlingService = errorHandlingService ?? ErrorHandlingService(toastManager: toastManager)
        self.testService = testService ?? FileOperationTestService(errorHandlingService: self.errorHandlingService, toastManager: toastManager)
    }
    
    // MARK: - Test Methods
    
    func testSingleFileSuccess() async {
        let fileName = "Ed Sheeran - Azizam - ck.mp4"
        currentOperation = "Processing \(fileName)"
        
        do {
            // Show validation progress
            progressConfiguration = errorHandlingService.createProgressConfiguration(
                for: .validation(fileName: fileName)
            )
            isShowingProgress = true
            
            try await testService.simulateFileValidation(fileName: fileName, shouldFail: false)
            
            // Show metadata extraction progress
            progressConfiguration = errorHandlingService.createProgressConfiguration(
                for: .metadataExtraction(fileName: fileName, progress: 0.0)
            )
            
            let metadata = try await testService.simulateMetadataExtraction(
                fileName: fileName,
                shouldFail: false,
                progressCallback: { progress in
                    Task { @MainActor in
                        self.progressConfiguration = self.errorHandlingService.createProgressConfiguration(
                            for: .metadataExtraction(fileName: fileName, progress: progress)
                        )
                    }
                }
            )
            
            processedFiles.append(fileName)
            isShowingProgress = false
            currentOperation = ""
            
        } catch {
            handleError(error, fileName: fileName)
        }
    }
    
    func testSingleFileFailure() async {
        let fileName = "corrupted-file.mp4"
        currentOperation = "Processing \(fileName)"
        
        do {
            progressConfiguration = errorHandlingService.createProgressConfiguration(
                for: .validation(fileName: fileName)
            )
            isShowingProgress = true
            
            try await testService.simulateFileValidation(fileName: fileName, shouldFail: true)
            
        } catch {
            handleError(error, fileName: fileName)
        }
    }
    
    func testBatchProcessing() async {
        let fileNames = [
            "Ed Sheeran - Azizam - ck.mp4",
            "Mental As Anything - Come Around - zoom.mp4",
            "corrupted-file.mp4", // This will fail
            "Lady Gaga - Abracadabra - zoom.mp4"
        ]
        
        currentOperation = "Processing \(fileNames.count) files"
        isShowingProgress = true
        
        do {
            let results = try await testService.simulateBatchProcessing(
                fileNames: fileNames,
                progressCallback: { currentFile, fileName, progress in
                    Task { @MainActor in
                        self.progressConfiguration = self.errorHandlingService.createProgressConfiguration(
                            for: .batchProcessing(
                                currentFile: currentFile,
                                totalFiles: fileNames.count,
                                fileName: fileName,
                                progress: progress
                            )
                        )
                    }
                }
            )
            
            processedFiles.append(contentsOf: results.map { _ in "Processed file" })
            isShowingProgress = false
            currentOperation = ""
            
        } catch {
            handleError(error, fileName: "batch")
        }
    }
    
    func testAllErrorTypes() {
        let errors = testService.createTestErrors()
        
        for (index, error) in errors.enumerated() {
            let fileName = "test-file-\(index).mp4"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 1.5) {
                let recoveryResult = self.errorHandlingService.handleFileProcessingError(error, for: fileName)
                print("Error \(index): \(recoveryResult.userMessage)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func handleError(_ error: Error, fileName: String) {
        isShowingProgress = false
        currentOperation = ""
        
        let alertConfig = errorHandlingService.createErrorAlert(for: error) {
            // Retry action
            Task {
                await self.testSingleFileSuccess()
            }
        }
        
        errorAlertConfiguration = alertConfig
        isShowingErrorAlert = true
    }
} 