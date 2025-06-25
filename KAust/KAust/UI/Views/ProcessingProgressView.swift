/*
 * TEMPORARILY COMMENTED OUT - DO NOT DELETE
 * This file contains processing progress view functionality that is currently disabled
 * but may be needed in the future.
 */

/*
import SwiftUI

// MARK: - Processing Progress View

struct ProcessingProgressView: View {
    let progress: BatchProgress
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        Text("Processing Progress View - Temporarily Disabled")
    }
}

// MARK: - Status View
private struct ProcessingStatusView: View {
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        HStack {
            statusIcon
            Text(statusText)
                .font(.headline)
                .foregroundColor(AppTheme.settingsText)
            Spacer()
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch filePickerService.processingState {
        case .processing:
            Image(systemName: "arrow.down.circle.fill")
                .foregroundColor(.blue)
                .font(.system(size: 20))
        case .paused:
            Image(systemName: "pause.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 20))
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 20))
        case .cancelled:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 20))
        default:
            Image(systemName: "circle")
                .foregroundColor(.gray)
                .font(.system(size: 20))
        }
    }
    
    private var statusText: String {
        switch filePickerService.processingState {
        case .processing: return "Processing Files..."
        case .paused: return "Processing Paused"
        case .completed: return "Processing Complete"
        case .cancelled: return "Processing Cancelled"
        default: return "Ready"
        }
    }
}

// MARK: - Progress Section View
private struct ProcessingProgressSectionView: View {
    let progress: BatchProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Overall Progress")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.settingsText)
                Spacer()
                Text(progress.progressText)
                    .font(.caption)
                    .foregroundColor(AppTheme.settingsText.opacity(0.7))
            }
            
            ProgressView(value: max(0, min(1, progress.overallProgress)))
                .progressViewStyle(LinearProgressViewStyle(tint: AppTheme.settingsResetIconBlue))
                .scaleEffect(y: 1.5)
            
            HStack {
                Text("\(Int(progress.overallProgress * 100))% Complete")
                    .font(.caption)
                    .foregroundColor(AppTheme.settingsText.opacity(0.8))
                Spacer()
                if let timeRemaining = progress.estimatedTimeRemaining {
                    Text("~\(formatTimeRemaining(timeRemaining)) remaining")
                        .font(.caption)
                        .foregroundColor(AppTheme.settingsText.opacity(0.6))
                }
            }
        }
    }
    
    private func formatTimeRemaining(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) % 3600 / 60
        let seconds = Int(time) % 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        } else {
            return "\(seconds)s"
        }
    }
}

// MARK: - Batch Progress Section View
private struct BatchProgressSectionView: View {
    let progress: BatchProgress
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(progress.batchText)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.settingsText.opacity(0.9))
                Spacer()
                Text("\(Int(progress.currentBatchProgress * 100))% of current batch")
                    .font(.caption2)
                    .foregroundColor(AppTheme.settingsText.opacity(0.6))
            }
            
            ProgressView(value: max(0, min(1, progress.currentBatchProgress)))
                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                .scaleEffect(y: 1.0)
        }
    }
}

// MARK: - Stats View
private struct ProcessingStatsView: View {
    let progress: BatchProgress
    
    var body: some View {
        HStack(spacing: 16) {
            StatView(icon: "checkmark.circle.fill", color: .green, 
                    value: progress.successfulFiles, label: "Success")
            StatView(icon: "xmark.circle.fill", color: .red, 
                    value: progress.failedFiles, label: "Failed")
            StatView(icon: "repeat.circle.fill", color: .yellow, 
                    value: progress.duplicateFiles, label: "Duplicates")
        }
    }
}

// MARK: - Controls View
private struct ProcessingControlsView: View {
    @ObservedObject var filePickerService: EnhancedFilePickerService
    
    var body: some View {
        HStack(spacing: 12) {
            if filePickerService.canPause {
                Button("Pause") {
                    Task {
                        await filePickerService.pauseProcessing()
                    }
                }
                .buttonStyle(ControlButtonStyle(color: .orange))
            }
            
            if filePickerService.canResume {
                Button("Resume") {
                    Task {
                        await filePickerService.resumeProcessing()
                    }
                }
                .buttonStyle(ControlButtonStyle(color: .blue))
            }
            
            if filePickerService.canRestart {
                Button("Restart") {
                    Task {
                        await filePickerService.restartProcessing()
                    }
                }
                .buttonStyle(ControlButtonStyle(color: .green))
            }
            
            Button(filePickerService.processingState == .processing ? "Cancel" : "Clear") {
                Task {
                    if filePickerService.processingState == .processing {
                        await filePickerService.cancelProcessing()
                    } else {
                        await filePickerService.resetAndClearFiles()
                    }
                }
            }
            .buttonStyle(ControlButtonStyle(color: .red))
            
            Spacer()
        }
    }
}

// MARK: - Stat View
private struct StatView: View {
    let icon: String
    let color: Color
    let value: Int
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text("\(value)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.settingsText)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(AppTheme.settingsText.opacity(0.6))
        }
    }
}
*/ 