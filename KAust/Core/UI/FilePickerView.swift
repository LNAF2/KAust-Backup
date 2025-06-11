import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

// MARK: - File Picker View

/// A comprehensive file picker view for selecting and processing MP4 files
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

// MARK: - File Processing Result

/// Result of file processing operation
struct FileProcessingResult {
    let url: URL
    let filename: String
    let isSuccess: Bool
    let metadata: MediaMetadata?
    let error: Error?
    let processingTime: TimeInterval
    
    init(url: URL, metadata: MediaMetadata?, error: Error?, processingTime: TimeInterval) {
        self.url = url
        self.filename = url.lastPathComponent
        self.isSuccess = error == nil
        self.metadata = metadata
        self.error = error
        self.processingTime = processingTime
    }
}

// MARK: - File Processing Progress

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

// MARK: - File Picker Service

/// Service for handling file picker operations and file processing
@MainActor
class FilePickerService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isProcessing = false
    @Published var progress = FileProcessingProgress(totalFiles: 0, processedFiles: 0)
    @Published var results: [FileProcessingResult] = []
    @Published var currentError: Error?
    
    // MARK: - Private Properties
    
    private let mediaMetadataService: MediaMetadataServiceProtocol
    private let dataProviderService: DataProviderServiceProtocol
    private let errorHandlingService: ErrorHandlingServiceProtocol
    
    // MARK: - Initialization
    
    init(
        mediaMetadataService: MediaMetadataServiceProtocol,
        dataProviderService: DataProviderServiceProtocol,
        errorHandlingService: ErrorHandlingServiceProtocol
    ) {
        self.mediaMetadataService = mediaMetadataService
        self.dataProviderService = dataProviderService
        self.errorHandlingService = errorHandlingService
    }
    
    // MARK: - File Processing
    
    /// Process selected files with metadata extraction and storage
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
    
    /// Process a single file
    private func processFile(_ url: URL, at index: Int) async {
        let startTime = Date()
        
        do {
            // Update progress: Starting validation
            updateCurrentProgress(0.1, for: index)
            
            // Validate file
            try await mediaMetadataService.validateFile(at: url)
            
            // Update progress: Extracting metadata
            updateCurrentProgress(0.4, for: index)
            
            // Extract metadata
            let metadata = try await mediaMetadataService.extractMetadata(from: url)
            
            // Update progress: Saving to database
            updateCurrentProgress(0.8, for: index)
            
            // Save metadata to database
            try await dataProviderService.saveMediaMetadata(metadata)
            
            // Update progress: Complete
            updateCurrentProgress(1.0, for: index)
            
            let processingTime = Date().timeIntervalSince(startTime)
            let result = FileProcessingResult(
                url: url,
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
    
    /// Update current file processing progress
    private func updateCurrentProgress(_ currentProgress: Double, for index: Int) {
        progress = FileProcessingProgress(
            totalFiles: progress.totalFiles,
            processedFiles: index,
            currentFileName: progress.currentFileName,
            currentProgress: currentProgress
        )
    }
    
    // MARK: - Helper Methods
    
    /// Get processing summary
    var processingStats: (successful: Int, failed: Int, totalTime: TimeInterval) {
        let successful = results.filter { $0.isSuccess }.count
        let failed = results.filter { !$0.isSuccess }.count
        let totalTime = results.reduce(0) { $0 + $1.processingTime }
        
        return (successful, failed, totalTime)
    }
    
    /// Clear processing results
    func clearResults() {
        results = []
        currentError = nil
        progress = FileProcessingProgress(totalFiles: 0, processedFiles: 0)
    }
}

// MARK: - File Processing Results View

/// View for displaying file processing results
struct FileProcessingResultsView: View {
    let results: [FileProcessingResult]
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section("Processing Summary") {
                    summaryView
                }
                
                // Results section
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

// MARK: - File Result Row

/// Individual file result row
struct FileResultRow: View {
    let result: FileProcessingResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status icon
                Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(result.isSuccess ? .green : .red)
                    .font(.system(size: 16))
                
                // Filename
                Text(result.filename)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                // Processing time
                Text(String(format: "%.2fs", result.processingTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if result.isSuccess, let metadata = result.metadata {
                // Success details
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
                // Error details
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