import SwiftUI

/// Demo view showcasing error handling and user feedback components
struct ErrorHandlingDemoView: View {
    @StateObject private var viewModel = ErrorHandlingDemoViewModel()
    @EnvironmentObject private var toastManager: ToastManager
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            // Header
            VStack(spacing: 8) {
                Text("Error Handling & User Feedback Demo")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.settingsText)
                
                Text("Step 3: Testing all error scenarios and user feedback systems")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.settingsText.opacity(0.7))
            }
            .padding()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Test Section 1: Success Scenarios
                    testSection(
                        title: "Success Scenarios",
                        icon: "checkmark.circle.fill",
                        iconColor: .green
                    ) {
                        VStack(spacing: 12) {
                            testButton(
                                title: "Single File Success",
                                description: "Test successful file processing with progress",
                                icon: "doc.fill"
                            ) {
                                Task {
                                    await viewModel.testSingleFileSuccess()
                                }
                            }
                            
                            testButton(
                                title: "Batch Processing",
                                description: "Test multiple files with mixed results",
                                icon: "doc.on.doc.fill"
                            ) {
                                Task {
                                    await viewModel.testBatchProcessing()
                                }
                            }
                        }
                    }
                    
                    // Test Section 2: Error Scenarios
                    testSection(
                        title: "Error Scenarios",
                        icon: "exclamationmark.triangle.fill",
                        iconColor: .orange
                    ) {
                        VStack(spacing: 12) {
                            testButton(
                                title: "Single File Error",
                                description: "Test file validation failure with error alert",
                                icon: "doc.badge.exclamationmark"
                            ) {
                                Task {
                                    await viewModel.testSingleFileFailure()
                                }
                            }
                            
                            testButton(
                                title: "All Error Types",
                                description: "Test all possible error types with toast notifications",
                                icon: "list.bullet.circle"
                            ) {
                                viewModel.testAllErrorTypes()
                            }
                        }
                    }
                    
                    // Test Section 3: Manual Error Tests
                    testSection(
                        title: "Manual Error Tests",
                        icon: "hammer.fill",
                        iconColor: .blue
                    ) {
                        VStack(spacing: 12) {
                            manualErrorButton(
                                title: "File Size Error",
                                error: MediaMetadataError.fileSizeOutOfRange(
                                    current: 200 * 1024 * 1024,
                                    min: 5 * 1024 * 1024,
                                    max: 200 * 1024 * 1024
                                )
                            )
                            
                            manualErrorButton(
                                title: "Unreadable File Error",
                                error: MediaMetadataError.unreadableFile
                            )
                            
                            manualErrorButton(
                                title: "No Valid Tracks Error",
                                error: MediaMetadataError.noValidTracks
                            )
                        }
                    }
                    
                    // Test Section 4: Toast Notifications
                    testSection(
                        title: "Toast Notifications",
                        icon: "bell.fill",
                        iconColor: .purple
                    ) {
                        VStack(spacing: 12) {
                            HStack(spacing: 12) {
                                toastButton(
                                    title: "Success",
                                    color: .green,
                                    icon: "checkmark.circle"
                                ) {
                                    toastManager.showSuccess(
                                        title: "Import Successful",
                                        message: "File has been processed and added to your library."
                                    )
                                }
                                
                                toastButton(
                                    title: "Error",
                                    color: .red,
                                    icon: "xmark.circle"
                                ) {
                                    toastManager.showError(
                                        title: "Import Failed",
                                        message: "The file could not be processed due to format issues."
                                    )
                                }
                            }
                            
                            HStack(spacing: 12) {
                                toastButton(
                                    title: "Warning",
                                    color: .orange,
                                    icon: "exclamationmark.triangle"
                                ) {
                                    toastManager.showWarning(
                                        title: "Large File Detected",
                                        message: "This file is quite large and may take longer to process."
                                    )
                                }
                                
                                toastButton(
                                    title: "Info",
                                    color: .blue,
                                    icon: "info.circle"
                                ) {
                                    toastManager.showInfo(
                                        title: "Processing Started",
                                        message: "Your files are being analyzed for metadata extraction."
                                    )
                                }
                            }
                        }
                    }
                    
                    // Current Status
                    if !viewModel.currentOperation.isEmpty {
                        statusSection()
                    }
                    
                    // Processed Files List
                    if !viewModel.processedFiles.isEmpty {
                        processedFilesSection()
                    }
                }
                .padding()
            }
        }
        .background(AppTheme.appBackground)
        .sheet(isPresented: $viewModel.isShowingProgress) {
            if let config = viewModel.progressConfiguration {
                ProgressIndicatorView(configuration: config)
                    .padding()
            }
        }
        .alert("Error Occurred", isPresented: $viewModel.isShowingErrorAlert) {
            if let config = viewModel.errorAlertConfiguration {
                Button("Cancel", role: .cancel) {
                    viewModel.isShowingErrorAlert = false
                }
                
                if config.isRetryable, let retryAction = config.retryAction {
                    Button("Try Again") {
                        retryAction()
                        viewModel.isShowingErrorAlert = false
                    }
                }
            }
        } message: {
            if let config = viewModel.errorAlertConfiguration {
                Text(config.message)
            }
        }
    }
    
    // MARK: - Helper Views
    
    @ViewBuilder
    private func testSection<Content: View>(
        title: String,
        icon: String,
        iconColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
            }
            
            content()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsBackground.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func testButton(
        title: String,
        description: String,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.settingsText)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.settingsText.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(AppTheme.settingsText.opacity(0.5))
                    .font(.system(size: 12))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsBackground.opacity(0.5))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func manualErrorButton(title: String, error: Error) -> some View {
        Button(title) {
            let alertConfig = ErrorHandlingService().createErrorAlert(for: error, retryAction: nil)
            viewModel.errorAlertConfiguration = alertConfig
            viewModel.isShowingErrorAlert = true
        }
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(Color.red.opacity(0.8))
        )
    }
    
    @ViewBuilder
    private func toastButton(
        title: String,
        color: Color,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(color)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    @ViewBuilder
    private func statusSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(.blue)
                Text("Current Operation")
                    .font(.headline)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
            }
            
            Text(viewModel.currentOperation)
                .font(.body)
                .foregroundColor(AppTheme.settingsText.opacity(0.8))
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .fill(AppTheme.settingsBackground.opacity(0.5))
                )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(Color.blue.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
        )
    }
    
    @ViewBuilder
    private func processedFilesSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Processed Files (\(viewModel.processedFiles.count))")
                    .font(.headline)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
            }
            
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(Array(viewModel.processedFiles.enumerated()), id: \.offset) { index, file in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.green)
                            .font(.system(size: 12))
                        Text(file)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsText)
                        Spacer()
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsBackground.opacity(0.5))
            )
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(Color.green.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Preview

struct ErrorHandlingDemoView_Previews: PreviewProvider {
    static var previews: some View {
        ToastContainerView {
            ErrorHandlingDemoView()
        }
    }
} 