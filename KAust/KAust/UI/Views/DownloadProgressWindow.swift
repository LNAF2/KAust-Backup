import SwiftUI

/// Comprehensive download progress window that shows all download information
/// while completely disabling the main UI and settings window
struct DownloadProgressWindow: View {
    let progress: BatchProgress
    @ObservedObject var filePickerService: EnhancedFilePickerService
    let onDismiss: (() -> Void)?
    let onShowResults: (() -> Void)?
    
    // Animation states
    @State private var progressRotation: Double = 0
    @State private var pulseAnimation: Double = 1.0
    
    var body: some View {
        ZStack {
            // Full screen overlay that completely blocks all interactions
            Rectangle()
                .fill(Color.black.opacity(0.85))
                .ignoresSafeArea(.all)
                .contentShape(Rectangle()) // Make entire area tappable to block touches
                .onTapGesture {
                    // Consume tap to prevent it from reaching background
                }
                .allowsHitTesting(true)
            
            // Main progress window - INCREASED HEIGHT from 800 to 850 to accommodate taller current file panel
            VStack(spacing: 20) {
                // Window title
                windowTitle
                
                // Header section
                headerSection
                
                // Central progress display
                centralProgressDisplay
                
                // Current file section
                currentFileSection
                
                // Statistics section
                statisticsSection
                
                // Bottom controls section
                bottomControlsSection
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.95))
                    .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    .shadow(color: Color.black.opacity(0.5), radius: 20, x: 0, y: 10)
            )
            .frame(maxWidth: 600, maxHeight: 850)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Window Title
    
    private var windowTitle: some View {
        HStack {
            Spacer()
            Text("DOWNLOAD PROGRESS")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Removed blue circle icon and "Download Progress" text and state text
            Spacer()
        }
    }
    
    // MARK: - Central Progress Display
    
    private var centralProgressDisplay: some View {
        VStack(spacing: 20) {
            // Circular progress indicator
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)
                
                Circle()
                    .trim(from: 0, to: CGFloat(progress.overallProgress))
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(progressRotation))
                
                VStack(spacing: 4) {
                    Text("\(Int(progress.overallProgress * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Complete")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Progress details
            VStack(spacing: 8) {
                HStack {
                    Text("Batch \(progress.currentBatch) of \(progress.totalBatches)")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Text("\(progress.completedFiles) / \(progress.totalFiles) files")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Progress bar
                ProgressView(value: progress.overallProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(y: 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.blue.opacity(0.1))
            )
        }
    }
    
    // MARK: - Current File Section
    
    private var currentFileSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                    .font(.system(size: 18))
                
                Text("Current File")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            if !filePickerService.currentFileName.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Fixed height text area that always accommodates 2 lines
                    Text(filePickerService.currentFileName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .frame(height: 44, alignment: .top)
                    
                    HStack {
                        Text(currentFileStatusText)
                            .font(.caption)
                            .foregroundColor(currentFileStatusColor)
                        
                        Spacer()
                        
                        Text("File \(filePickerService.currentFileCount + 1) of \(filePickerService.totalFileCount)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.orange.opacity(0.2), lineWidth: 1)
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Fixed height for "No file" message to match the filename area
                    Text("No file currently processing")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(height: 44, alignment: .top)
                    
                    // Empty spacer to match the status row height
                    HStack {
                        Text("")
                            .font(.caption)
                        Spacer()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Statistics Section
    
    private var statisticsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.purple)
                    .font(.system(size: 18))
                
                Text("Statistics")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            HStack(spacing: 20) {
                StatisticCard(
                    icon: "checkmark.circle.fill",
                    color: .green,
                    value: filePickerService.processingStats.successful,
                    label: "Successful"
                )
                
                StatisticCard(
                    icon: "xmark.circle.fill",
                    color: .red,
                    value: filePickerService.processingStats.failed,
                    label: "Failed"
                )
                
                StatisticCard(
                    icon: "minus.circle.fill",
                    color: .orange,
                    value: filePickerService.processingStats.duplicates,
                    label: "Duplicates"
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
        )
    }
    
    // MARK: - Bottom Controls Section
    
    private var bottomControlsSection: some View {
        VStack(spacing: 16) {
            // Control buttons
            HStack(spacing: 16) {
                // Pause/Resume button
                if filePickerService.canPause {
                    Button(action: {
                        filePickerService.pauseProcessing()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "pause.circle.fill")
                            Text("Pause")
                        }
                        .foregroundColor(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.orange, lineWidth: 1)
                        )
                    }
                }
                
                if filePickerService.canResume {
                    Button(action: {
                        Task {
                            await filePickerService.resumeProcessing()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "play.circle.fill")
                            Text("Resume")
                        }
                        .foregroundColor(.green)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.green, lineWidth: 1)
                        )
                    }
                }
                
                // Cancel button
                if filePickerService.processingState == .processing || filePickerService.processingState == .paused {
                    Button(action: {
                        filePickerService.cancelProcessing()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "stop.circle.fill")
                            Text("Cancel")
                        }
                        .foregroundColor(.red)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.red, lineWidth: 1)
                        )
                    }
                }
                
                // RESULT button - show when there are results to display
                if !filePickerService.results.isEmpty {
                    Button(action: {
                        onShowResults?()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "doc.text.magnifyingglass")
                            Text("Result")
                        }
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.blue, lineWidth: 1)
                        )
                    }
                }
                
                Spacer()
                
                // Close button (only for completed states)
                if filePickerService.processingState == .completed || 
                   filePickerService.processingState == .cancelled {
                    Button(action: {
                        onDismiss?()
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                            Text("Close")
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(.blue)
                        )
                    }
                }
            }
            
            // Time information
            HStack {
                Text("Elapsed: \(formatElapsedTime())")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                
                Spacer()
                
                if filePickerService.processingState == .processing {
                    Text("Estimated remaining: \(formatEstimatedTime())")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    // MARK: - Helper Components
    
    private struct StatisticCard: View {
        let icon: String
        let color: Color
        let value: Int
        let label: String
        
        var body: some View {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 24))
                
                Text("\(value)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                Text(label)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Helper Properties
    
    private var processingStateText: String {
        switch filePickerService.processingState {
        case .idle:
            return "Ready to start"
        case .processing:
            return "Processing files..."
        case .paused:
            return "Processing paused"
        case .completed:
            return "Processing complete"
        case .cancelled:
            return "Processing cancelled"
        }
    }
    
    private var processingStateColor: Color {
        switch filePickerService.processingState {
        case .idle:
            return .gray
        case .processing:
            return .blue
        case .paused:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
    
    private var currentFileStatusText: String {
        switch filePickerService.processingState {
        case .processing:
            return "Processing..."
        case .paused:
            return "Paused"
        case .completed:
            return "Processing Completed"
        case .cancelled:
            return "Cancelled"
        case .idle:
            return "Ready"
        }
    }
    
    private var currentFileStatusColor: Color {
        switch filePickerService.processingState {
        case .processing:
            return .orange
        case .paused:
            return .orange
        case .completed:
            return .green
        case .cancelled:
            return .red
        case .idle:
            return .gray
        }
    }
    
    private var statusIndicator: some View {
        HStack {
            Circle()
                .fill(processingStateColor)
                .frame(width: 12, height: 12)
                .scaleEffect(pulseAnimation)
            
            Text(processingStateText)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
            
            Spacer()
            
            Text(formatElapsedTime())
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    // MARK: - Helper Methods
    
    private func startAnimations() {
        // Rotation animation for progress circle
        withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
            progressRotation = 360
        }
        
        // Pulse animation for status indicator
        withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
            pulseAnimation = 1.2
        }
    }
    
    private func formatElapsedTime() -> String {
        let elapsed = filePickerService.elapsedTime
        let hours = Int(elapsed) / 3600
        let minutes = Int(elapsed) % 3600 / 60
        let seconds = Int(elapsed) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formatEstimatedTime() -> String {
        guard let estimated = filePickerService.estimatedTimeRemaining else {
            return "--:--"
        }
        
        let hours = Int(estimated) / 3600
        let minutes = Int(estimated) % 3600 / 60
        let seconds = Int(estimated) % 60
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}

// MARK: - Preview

#Preview {
    DownloadProgressWindow(
        progress: BatchProgress(
            totalFiles: 50,
            completedFiles: 32,
            currentBatch: 2,
            totalBatches: 5,
            currentBatchProgress: 0.75,
            successfulFiles: 30,
            failedFiles: 2,
            duplicateFiles: 0,
            estimatedTimeRemaining: 120,
            currentFileName: "Sample Song.mp4"
        ),
        filePickerService: EnhancedFilePickerService(),
        onDismiss: nil,
        onShowResults: nil
    )
} 
