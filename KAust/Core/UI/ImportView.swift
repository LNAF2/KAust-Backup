import SwiftUI
import UniformTypeIdentifiers

// MARK: - Import View

/// Main view for file import operations using the FileImportViewModel
struct ImportView: View {
    @StateObject private var importViewModel = FileImportViewModel()
    @State private var isShowingFilePicker = false
    @State private var isShowingResults = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: AppConstants.Layout.defaultSpacing) {
                
                // Header Section
                ImportHeaderView(viewModel: importViewModel)
                
                // Main Content
                if importViewModel.isImporting {
                    // Import in progress
                    ImportProgressView(viewModel: importViewModel)
                } else if importViewModel.hasResults {
                    // Results available
                    ImportResultsSummaryView(viewModel: importViewModel)
                } else {
                    // Ready to import
                    ImportReadyView(onSelectFiles: {
                        isShowingFilePicker = true
                    })
                }
                
                Spacer()
                
                // Action Buttons
                ImportActionButtonsView(
                    viewModel: importViewModel,
                    onSelectFiles: { isShowingFilePicker = true },
                    onShowResults: { isShowingResults = true }
                )
            }
            .padding()
            .background(AppTheme.appBackground)
            .navigationTitle("Import Files")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $isShowingFilePicker) {
            FilePickerView(
                isPresented: $isShowingFilePicker,
                onFilesSelected: { urls in
                    importViewModel.importFiles(urls)
                },
                onError: { error in
                    // Handle file picker errors
                    print("File picker error: \(error)")
                }
            )
        }
        .sheet(isPresented: $isShowingResults) {
            ImportResultsDetailView(viewModel: importViewModel)
        }
    }
}

// MARK: - Import Header View

struct ImportHeaderView: View {
    @ObservedObject var viewModel: FileImportViewModel
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: viewModel.isImporting ? "square.and.arrow.down" : "folder.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(viewModel.isImporting ? .blue : AppTheme.accent)
                .scaleEffect(viewModel.isImporting ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.3), value: viewModel.isImporting)
            
            Text("MP4 File Import")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.text)
            
            Text(viewModel.statusMessage)
                .font(.subheadline)
                .foregroundColor(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }
}

// MARK: - Import Ready View

struct ImportReadyView: View {
    let onSelectFiles: () -> Void
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            VStack(spacing: 12) {
                Text("Ready to Import")
                    .font(.headline)
                    .foregroundColor(AppTheme.text)
                
                Text("Select MP4 files to add to your karaoke library. Files must be between 5MB and 150MB.")
                    .font(.body)
                    .foregroundColor(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onSelectFiles) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                        .font(.title2)
                    Text("Select Files")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(AppTheme.accent)
                .cornerRadius(AppConstants.Layout.cornerRadius)
            }
            .padding(.horizontal, 32)
        }
    }
}

// MARK: - Import Progress View

struct ImportProgressView: View {
    @ObservedObject var viewModel: FileImportViewModel
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            
            // Current file progress
            if let progress = viewModel.importProgress {
                VStack(spacing: 12) {
                    Text("Processing Files")
                        .font(.headline)
                        .foregroundColor(AppTheme.text)
                    
                    Text(progress.progressText)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textSecondary)
                    
                    // Overall progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Overall Progress")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(Int(progress.overallProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        ProgressView(value: progress.overallProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.accent))
                            .scaleEffect(y: 2)
                    }
                    
                    // Current operation progress
                    VStack(spacing: 8) {
                        HStack {
                            Text("Current File")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(Int(progress.operationProgress * 100))%")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        
                        ProgressView(value: progress.operationProgress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .cornerRadius(AppConstants.Layout.cornerRadius)
            }
            
            // Cancel button
            if viewModel.canCancel {
                Button(action: {
                    viewModel.cancelImport()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Cancel Import")
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
                .padding(.horizontal, 32)
            }
        }
    }
}

// MARK: - Import Results Summary View

struct ImportResultsSummaryView: View {
    @ObservedObject var viewModel: FileImportViewModel
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            
            // Success icon
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("Import Complete")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.text)
            
            // Statistics
            let stats = viewModel.importStatistics
            VStack(spacing: 12) {
                HStack {
                    StatisticItem(
                        title: "Successful",
                        value: "\(stats.successful)",
                        color: .green
                    )
                    
                    Spacer()
                    
                    StatisticItem(
                        title: "Failed",
                        value: "\(stats.failed)",
                        color: stats.failed > 0 ? .red : AppTheme.textSecondary
                    )
                    
                    Spacer()
                    
                    StatisticItem(
                        title: "Success Rate",
                        value: stats.successRate,
                        color: AppTheme.accent
                    )
                }
                
                HStack {
                    StatisticItem(
                        title: "Total Time",
                        value: viewModel.processingTimeText,
                        color: AppTheme.textSecondary
                    )
                    
                    Spacer()
                    
                    StatisticItem(
                        title: "Total Files",
                        value: "\(stats.total)",
                        color: AppTheme.textSecondary
                    )
                    
                    Spacer()
                }
            }
            .padding()
            .background(AppTheme.cardBackground)
            .cornerRadius(AppConstants.Layout.cornerRadius)
        }
    }
}

// MARK: - Statistic Item

struct StatisticItem: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
    }
}

// MARK: - Import Action Buttons View

struct ImportActionButtonsView: View {
    @ObservedObject var viewModel: FileImportViewModel
    let onSelectFiles: () -> Void
    let onShowResults: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            
            // Select more files button
            if !viewModel.isImporting {
                Button(action: onSelectFiles) {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text(viewModel.hasResults ? "Import More Files" : "Select Files")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(AppTheme.accent)
                    .cornerRadius(AppConstants.Layout.cornerRadius)
                }
            }
            
            // Show detailed results button
            if viewModel.hasResults {
                Button(action: onShowResults) {
                    HStack {
                        Image(systemName: "list.bullet.clipboard")
                        Text("View Detailed Results")
                    }
                    .foregroundColor(AppTheme.accent)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius)
                            .stroke(AppTheme.accent, lineWidth: 1)
                    )
                }
            }
            
            // Clear results button
            if viewModel.hasResults && !viewModel.isImporting {
                Button(action: {
                    viewModel.clearResults()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Clear Results")
                    }
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.cornerRadius)
                            .stroke(Color.red, lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 32)
    }
}

// MARK: - Import Results Detail View

struct ImportResultsDetailView: View {
    @ObservedObject var viewModel: FileImportViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Summary section
                Section {
                    ImportSummaryCardView(viewModel: viewModel)
                } header: {
                    Text("Import Summary")
                }
                
                // Results section
                Section {
                    ForEach(Array(viewModel.fileResults.enumerated()), id: \.offset) { index, result in
                        ImportResultRowView(result: result, index: index + 1)
                    }
                } header: {
                    Text("File Details")
                }
                
                // Errors section (if any)
                if viewModel.hasErrors {
                    Section {
                        ForEach(Array(viewModel.failedImports.enumerated()), id: \.offset) { index, result in
                            ImportErrorRowView(result: result)
                        }
                    } header: {
                        Text("Failed Imports")
                    }
                }
            }
            .navigationTitle("Import Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Import Summary Card View

struct ImportSummaryCardView: View {
    @ObservedObject var viewModel: FileImportViewModel
    
    var body: some View {
        let stats = viewModel.importStatistics
        
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Success Rate")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(stats.successRate)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.accent)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("Processing Time")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(viewModel.processingTimeText)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.text)
                }
            }
            
            Divider()
            
            HStack {
                Label("\(stats.successful) successful", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                Spacer()
                
                if stats.failed > 0 {
                    Label("\(stats.failed) failed", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }
            .font(.subheadline)
        }
        .padding()
        .background(AppTheme.cardBackground)
        .cornerRadius(AppConstants.Layout.cornerRadius)
    }
}

// MARK: - Import Result Row View

struct ImportResultRowView: View {
    let result: FileImportResult
    let index: Int
    
    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            Image(systemName: result.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(result.success ? .green : .red)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index). \(result.fileName)")
                    .font(.headline)
                    .lineLimit(1)
                
                if result.success, let metadata = result.metadata {
                    Text("Duration: \(formatDuration(metadata.duration))")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                } else if let error = result.error {
                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            Text(String(format: "%.2fs", result.processingTime))
                .font(.caption)
                .foregroundColor(AppTheme.textSecondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Import Error Row View

struct ImportErrorRowView: View {
    let result: FileImportResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                
                Text(result.fileName)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            
            if let error = result.error {
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(.leading, 24)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - File Picker View (Reused from Settings)

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

// MARK: - Previews

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView()
    }
} 