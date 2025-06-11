import SwiftUI

/// Reusable progress indicator view for file operations and long-running tasks
struct ProgressIndicatorView: View {
    let configuration: ProgressConfiguration
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            // Progress indicator
            progressIndicator
            
            // Title
            Text(configuration.title)
                .font(.headline)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.settingsText)
            
            // Description
            if let description = configuration.description {
                Text(description)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.settingsText.opacity(0.7))
            }
            
            // Progress details
            if case .determinate(let progress, let details) = configuration.type {
                progressDetails(progress: progress, details: details)
            }
            
            // Cancel button (if cancellable)
            if configuration.isCancellable, let cancelAction = configuration.cancelAction {
                Button("Cancel") {
                    cancelAction()
                }
                .buttonStyle(CancelButtonStyle())
                .padding(.top, 8)
            }
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var progressIndicator: some View {
        switch configuration.type {
        case .indeterminate:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(1.5)
                .frame(height: 60)
            
        case .determinate(let progress, _):
            VStack(spacing: 8) {
                // Circular progress
                ZStack {
                    Circle()
                        .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 4)
                        .frame(width: 60, height: 60)
                    
                    Circle()
                        .trim(from: 0, to: min(progress, 1.0))
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progress)
                    
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppTheme.settingsText)
                }
                
                // Linear progress bar
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
            }
        }
    }
    
    @ViewBuilder
    private func progressDetails(progress: Double, details: ProgressDetails?) -> some View {
        if let details = details {
            VStack(spacing: 4) {
                // File info
                if let fileName = details.fileName {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundColor(.blue)
                        Text(fileName)
                            .font(.caption)
                            .foregroundColor(AppTheme.settingsText)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                
                // Processing status
                if let currentStep = details.currentStep {
                    Text(currentStep)
                        .font(.caption)
                        .foregroundColor(AppTheme.settingsText.opacity(0.6))
                }
                
                // Speed/ETA info
                HStack(spacing: 16) {
                    if let speed = details.processingSpeed {
                        Label(speed, systemImage: "speedometer")
                            .font(.caption2)
                            .foregroundColor(AppTheme.settingsText.opacity(0.5))
                    }
                    
                    if let eta = details.estimatedTimeRemaining {
                        Label(eta, systemImage: "clock")
                            .font(.caption2)
                            .foregroundColor(AppTheme.settingsText.opacity(0.5))
                    }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Configuration Types

struct ProgressConfiguration {
    let type: ProgressType
    let title: String
    let description: String?
    let isCancellable: Bool
    let cancelAction: (() -> Void)?
    
    init(
        type: ProgressType,
        title: String,
        description: String? = nil,
        isCancellable: Bool = false,
        cancelAction: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.description = description
        self.isCancellable = isCancellable
        self.cancelAction = cancelAction
    }
}

enum ProgressType {
    case indeterminate
    case determinate(progress: Double, details: ProgressDetails?)
}

struct ProgressDetails {
    let fileName: String?
    let currentStep: String?
    let processingSpeed: String?
    let estimatedTimeRemaining: String?
    
    init(
        fileName: String? = nil,
        currentStep: String? = nil,
        processingSpeed: String? = nil,
        estimatedTimeRemaining: String? = nil
    ) {
        self.fileName = fileName
        self.currentStep = currentStep
        self.processingSpeed = processingSpeed
        self.estimatedTimeRemaining = estimatedTimeRemaining
    }
}

// MARK: - Convenience Initializers

extension ProgressConfiguration {
    /// Simple indeterminate progress for basic loading
    static func loading(
        title: String,
        description: String? = nil,
        isCancellable: Bool = false,
        cancelAction: (() -> Void)? = nil
    ) -> ProgressConfiguration {
        ProgressConfiguration(
            type: .indeterminate,
            title: title,
            description: description,
            isCancellable: isCancellable,
            cancelAction: cancelAction
        )
    }
    
    /// File processing progress with detailed information
    static func fileProcessing(
        fileName: String,
        progress: Double,
        currentStep: String,
        isCancellable: Bool = true,
        cancelAction: (() -> Void)? = nil
    ) -> ProgressConfiguration {
        let details = ProgressDetails(
            fileName: fileName,
            currentStep: currentStep
        )
        
        return ProgressConfiguration(
            type: .determinate(progress: progress, details: details),
            title: "Processing File",
            description: "Extracting metadata and validating content...",
            isCancellable: isCancellable,
            cancelAction: cancelAction
        )
    }
    
    /// Batch file processing progress
    static func batchProcessing(
        currentFile: Int,
        totalFiles: Int,
        fileName: String,
        progress: Double,
        isCancellable: Bool = true,
        cancelAction: (() -> Void)? = nil
    ) -> ProgressConfiguration {
        let details = ProgressDetails(
            fileName: fileName,
            currentStep: "File \(currentFile) of \(totalFiles)"
        )
        
        return ProgressConfiguration(
            type: .determinate(progress: progress, details: details),
            title: "Processing Files",
            description: "Importing MP4 files and extracting metadata...",
            isCancellable: isCancellable,
            cancelAction: cancelAction
        )
    }
}

// MARK: - Button Style

private struct CancelButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.red)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .stroke(Color.red.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                            .fill(Color.red.opacity(configuration.isPressed ? 0.1 : 0.05))
                    )
            )
    }
}

// MARK: - Preview

struct ProgressIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Indeterminate progress
            ProgressIndicatorView(
                configuration: .loading(
                    title: "Loading Files",
                    description: "Please wait while we prepare your files...",
                    isCancellable: true,
                    cancelAction: {}
                )
            )
            .previewDisplayName("Indeterminate")
            
            // File processing progress
            ProgressIndicatorView(
                configuration: .fileProcessing(
                    fileName: "Ed Sheeran - Azizam - ck.mp4",
                    progress: 0.65,
                    currentStep: "Extracting metadata...",
                    isCancellable: true,
                    cancelAction: {}
                )
            )
            .previewDisplayName("File Processing")
            
            // Batch processing progress
            ProgressIndicatorView(
                configuration: .batchProcessing(
                    currentFile: 3,
                    totalFiles: 5,
                    fileName: "Lady Gaga - Abracadabra - zoom.mp4",
                    progress: 0.8,
                    isCancellable: true,
                    cancelAction: {}
                )
            )
            .previewDisplayName("Batch Processing")
        }
        .padding()
        .background(Color.gray.opacity(0.3))
    }
} 