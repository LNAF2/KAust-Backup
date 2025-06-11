import SwiftUI

/// Reusable error alert view that displays user-friendly error messages with retry options
struct ErrorAlertView: View {
    let error: Error
    let retryAction: (() -> Void)?
    let dismissAction: () -> Void
    
    private var errorInfo: ErrorDisplayInfo {
        ErrorDisplayInfo.from(error)
    }
    
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            // Error icon
            Image(systemName: errorInfo.iconName)
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(errorInfo.iconColor)
            
            // Title
            Text(errorInfo.title)
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.settingsText)
            
            // Description
            Text(errorInfo.description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(AppTheme.settingsText.opacity(0.8))
                .padding(.horizontal)
            
            // Recovery suggestion (if available)
            if let recoverySuggestion = errorInfo.recoverySuggestion {
                Text(recoverySuggestion)
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(AppTheme.settingsText.opacity(0.6))
                    .padding(.horizontal)
                    .padding(.top, 4)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                // Dismiss button
                Button("Cancel") {
                    dismissAction()
                }
                .buttonStyle(SecondaryButtonStyle())
                
                // Retry button (if retry action is provided)
                if let retryAction = retryAction, errorInfo.isRetryable {
                    Button("Try Again") {
                        retryAction()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(.top, 8)
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
        .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
    }
}

// MARK: - Error Display Information

private struct ErrorDisplayInfo {
    let title: String
    let description: String
    let recoverySuggestion: String?
    let iconName: String
    let iconColor: Color
    let isRetryable: Bool
    
    static func from(_ error: Error) -> ErrorDisplayInfo {
        // Handle MediaMetadataError specifically
        if let mediaError = error as? MediaMetadataError {
            return handleMediaMetadataError(mediaError)
        }
        
        // Handle other known error types
        if let nsError = error as NSError {
            return handleNSError(nsError)
        }
        
        // Generic error fallback
        return ErrorDisplayInfo(
            title: "Something Went Wrong",
            description: error.localizedDescription,
            recoverySuggestion: "Please try again in a few moments.",
            iconName: "exclamationmark.triangle",
            iconColor: .orange,
            isRetryable: true
        )
    }
    
    private static func handleMediaMetadataError(_ error: MediaMetadataError) -> ErrorDisplayInfo {
        switch error {
        case .invalidFileSize:
            return ErrorDisplayInfo(
                title: "File Size Issue",
                description: "Unable to determine the file size",
                recoverySuggestion: "Make sure the file is accessible and try selecting it again.",
                iconName: "doc.questionmark",
                iconColor: .orange,
                isRetryable: true
            )
            
        case .fileSizeOutOfRange(let current, let min, let max):
            let currentMB = current / (1024 * 1024)
            let minMB = min / (1024 * 1024)
            let maxMB = max / (1024 * 1024)
            return ErrorDisplayInfo(
                title: "File Size Out of Range",
                description: "File size (\(currentMB)MB) must be between \(minMB)MB and \(maxMB)MB",
                recoverySuggestion: "Please select a different MP4 file within the size limits.",
                iconName: "scale.3d",
                iconColor: .red,
                isRetryable: false
            )
            
        case .unreadableFile:
            return ErrorDisplayInfo(
                title: "File Cannot Be Read",
                description: "The selected file appears to be corrupted or in an unsupported format",
                recoverySuggestion: "Try selecting a different MP4 file or check if the original file works in other apps.",
                iconName: "doc.badge.exclamationmark",
                iconColor: .red,
                isRetryable: true
            )
            
        case .invalidDuration:
            return ErrorDisplayInfo(
                title: "Invalid Media Duration",
                description: "The media file has an invalid or corrupted duration",
                recoverySuggestion: "This file may be corrupted. Try selecting a different MP4 file.",
                iconName: "clock.badge.exclamationmark",
                iconColor: .orange,
                isRetryable: true
            )
            
        case .noValidTracks:
            return ErrorDisplayInfo(
                title: "No Valid Content Found",
                description: "The file doesn't contain valid audio or video tracks",
                recoverySuggestion: "Make sure you're selecting a valid MP4 video file with audio and video content.",
                iconName: "waveform.slash",
                iconColor: .red,
                isRetryable: true
            )
            
        case .metadataExtractionFailed:
            return ErrorDisplayInfo(
                title: "Metadata Extraction Failed",
                description: "Unable to extract information from the media file",
                recoverySuggestion: "The file may be corrupted or use an unsupported format. Try a different file.",
                iconName: "info.circle.and.exclamationmark",
                iconColor: .orange,
                isRetryable: true
            )
        }
    }
    
    private static func handleNSError(_ error: NSError) -> ErrorDisplayInfo {
        switch error.domain {
        case NSCocoaErrorDomain:
            if error.code == NSFileReadNoSuchFileError {
                return ErrorDisplayInfo(
                    title: "File Not Found",
                    description: "The selected file could not be found",
                    recoverySuggestion: "The file may have been moved or deleted. Please select another file.",
                    iconName: "doc.questionmark",
                    iconColor: .red,
                    isRetryable: true
                )
            } else if error.code == NSFileReadNoPermissionError {
                return ErrorDisplayInfo(
                    title: "Permission Denied",
                    description: "Unable to access the selected file",
                    recoverySuggestion: "Check file permissions or try selecting a file from a different location.",
                    iconName: "lock.circle",
                    iconColor: .red,
                    isRetryable: true
                )
            }
            
        case NSURLErrorDomain:
            return ErrorDisplayInfo(
                title: "Network Error",
                description: "Unable to access the file over the network",
                recoverySuggestion: "Check your internet connection and try again.",
                iconName: "wifi.exclamationmark",
                iconColor: .orange,
                isRetryable: true
            )
        }
        
        // Generic NSError handling
        return ErrorDisplayInfo(
            title: "File Access Error",
            description: error.localizedDescription,
            recoverySuggestion: "Please try selecting the file again.",
            iconName: "exclamationmark.triangle",
            iconColor: .orange,
            isRetryable: true
        )
    }
}

// MARK: - Button Styles

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(AppTheme.settingsText)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .stroke(AppTheme.settingsText.opacity(0.3), lineWidth: 1)
                    .background(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                            .fill(AppTheme.settingsText.opacity(configuration.isPressed ? 0.1 : 0.05))
                    )
            )
    }
}

// MARK: - Preview

struct ErrorAlertView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // File size error
            ErrorAlertView(
                error: MediaMetadataError.fileSizeOutOfRange(
                    current: 200 * 1024 * 1024,
                    min: 5 * 1024 * 1024,
                    max: 150 * 1024 * 1024
                ),
                retryAction: {},
                dismissAction: {}
            )
            .previewDisplayName("File Size Error")
            
            // Unreadable file error
            ErrorAlertView(
                error: MediaMetadataError.unreadableFile,
                retryAction: {},
                dismissAction: {}
            )
            .previewDisplayName("Unreadable File")
            
            // Generic error without retry
            ErrorAlertView(
                error: MediaMetadataError.noValidTracks,
                retryAction: nil,
                dismissAction: {}
            )
            .previewDisplayName("No Retry Action")
        }
        .padding()
        .background(Color.gray.opacity(0.3))
    }
} 