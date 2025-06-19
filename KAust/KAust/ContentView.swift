//
//  ContentView.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI
import AVKit
import Foundation
import UIKit

/// Custom Download Results View as requested by user
struct DownloadResultsView: View {
    let results: [FileProcessingResult]
    let onDismiss: () -> Void
    
    private var successfulResults: [FileProcessingResult] {
        results.filter { $0.status == .success }
    }
    
    private var failedResults: [FileProcessingResult] {
        results.filter { $0.status == .failed }
    }
    
    private var duplicateResults: [FileProcessingResult] {
        results.filter { $0.status == .duplicate }
    }
    
    var body: some View {
        ZStack {
            // Black background matching settings style
            AppTheme.settingsBackground.ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header with print icon, centered title, and DONE button
                HStack {
                    // Print icon in top left corner - BLUE
                    Button(action: printResults) {
                        Image(systemName: "printer")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    
                    Spacer()
                    
                    // Centered title - ALL CAPS
                    Text("DOWNLOAD RESULTS")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // DONE button in top right corner
                    Button("DONE") {
                        onDismiss()
                    }
                    .font(.headline)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 32)
                .padding(.top, 20)
                
                // Results sections - Successful, Failed, and Duplicates
                ScrollView {
                    VStack(spacing: 20) {
                        // Successful section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Successful")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                                Spacer()
                            }
                            
                            if successfulResults.isEmpty {
                                Text("0 songs were successfully downloaded")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.1))
                                    )
                            } else {
                                Text("\(successfulResults.count) songs were successfully downloaded")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.green.opacity(0.1))
                                    )
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Failed files section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Failed")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            
                            if failedResults.isEmpty {
                                Text("0 songs failed to download")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.red.opacity(0.1))
                                    )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(failedResults.indices, id: \.self) { index in
                                        FailedFileRow(result: failedResults[index])
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // Duplicate files section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Duplicates")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.orange)
                                Spacer()
                            }
                            
                            if duplicateResults.isEmpty {
                                Text("0 duplicate songs were downloaded")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.orange.opacity(0.1))
                                    )
                            } else {
                                LazyVStack(spacing: 8) {
                                    ForEach(duplicateResults.indices, id: \.self) { index in
                                        DuplicateFileRow(result: duplicateResults[index])
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 32)
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Print Functionality
    
    private func printResults() {
        print("🖨️ Printing download results...")
        
        let printController = UIPrintInteractionController.shared
        
        // Create print content
        let printContent = createPrintContent()
        
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Download Results Report"
        
        printController.printInfo = printInfo
        
        // Create a simple text formatter
        let formatter = UISimpleTextPrintFormatter(text: printContent)
        formatter.startPage = 0
        
        // Use modern perPageContentInsets
        if #available(iOS 10.0, *) {
            formatter.perPageContentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        } else {
            formatter.contentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        }
        formatter.maximumContentWidth = 6 * 72 // 6 inches
        
        printController.printFormatter = formatter
        
        // Present the print dialog from the topmost presented view controller
        DispatchQueue.main.async {
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                
                // Find the topmost presented view controller
                var topController = window.rootViewController
                while let presentedController = topController?.presentedViewController {
                    topController = presentedController
                }
                
                if let controller = topController {
                    print("🖨️ Presenting download results print dialog from: \(type(of: controller))")
                    
                    // Present the print controller
                    printController.present(animated: true, completionHandler: { (_, completed, error) in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("❌ Print error: \(error.localizedDescription)")
                            } else if completed {
                                print("✅ Download results print completed successfully")
                            } else {
                                print("🚫 Download results print cancelled by user")
                            }
                        }
                    })
                } else {
                    print("❌ Could not find a view controller to present print dialog from")
                }
            } else {
                print("❌ Could not find key window to present print dialog")
            }
        }
    }
    
    private func createPrintContent() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        dateFormatter.timeStyle = .short
        
        var content = """
        KARAOKE AUSTRALIA - DOWNLOAD RESULTS REPORT
        Generated: \(dateFormatter.string(from: Date()))
        
        ===================================================
        DOWNLOAD RESULTS
        ===================================================
        
        Total Files Processed: \(results.count)
        
        """
        
        // Add failed files section
        if !failedResults.isEmpty {
            content += """
            
            ===================================================
            FAILED FILES (\(failedResults.count))
            ===================================================
            
            """
            
            for (index, result) in failedResults.enumerated() {
                let errorMessage = result.error?.localizedDescription ?? "Unknown error"
                content += "\(index + 1). \(result.filename)\n"
                content += "   Error: \(errorMessage)\n\n"
            }
        }
        
        // Add duplicate files section
        if !duplicateResults.isEmpty {
            content += """
            
            ===================================================
            DUPLICATES (\(duplicateResults.count))
            ===================================================
            
            """
            
            for (index, result) in duplicateResults.enumerated() {
                content += "\(index + 1). \(result.filename)\n"
                content += "   Status: Already exists in your music library\n\n"
            }
        }
        
        content += """
        
        ===================================================
        END OF REPORT
        ===================================================
        
        This report was generated by KAust - Karaoke Australia
        """
        
        return content
    }
}

/// Row view for failed files in the custom results
struct FailedFileRow: View {
    let result: FileProcessingResult
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                
                Text(result.filename)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
            }
            
            if let error = result.error {
                Text("Reason: \(getDetailedErrorMessage(error))")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.leading, 24)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    private func getDetailedErrorMessage(_ error: Error) -> String {
        if let validationError = error as? FileValidationError {
            switch validationError {
            case .invalidFileSize:
                return "Invalid file size detected"
            case .fileSizeTooSmallForCopy:
                return "File too small for copying to app storage (minimum 5MB required)"
            case .fileSizeTooBigForCopy:
                return "File too large for copying to app storage (maximum 200MB to prevent storage bloat)"
            case .fileSizeTooSmallForQuality:
                return "File too small for quality standards (minimum 5MB required)"
            case .invalidFileType:
                return "Only MP4 files are supported"
            case .fileNotFound:
                return "File not found or was moved"
            case .permissionDenied:
                return "Permission denied - check file access rights"
            case .fileNotReadable:
                return "File is corrupted, damaged, or in an unsupported format"
            }
        } else {
            return error.localizedDescription
        }
    }
}

/// Row view for duplicate files in the custom results
struct DuplicateFileRow: View {
    let result: FileProcessingResult
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.orange)
                .font(.system(size: 16))
            
            Text(result.filename)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Text("Already in library")
                .font(.system(size: 14))
                .foregroundColor(.orange.opacity(0.8))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.1))
        )
    }
}

struct ContentView: View {
    @StateObject private var playlistViewModel: PlaylistViewModel
    @StateObject private var videoPlayerViewModel = VideoPlayerViewModel()
    @StateObject private var settingsViewModel = SettingsViewModel()  // Global settings view model
    @State private var showSettings = false
    @State private var showingDownloadProgressWindow = false  // Global download progress state
    @State private var showingCustomResults = false  // For showing download results
    
    // Layout constants
    private let outerPadding: CGFloat = 16
    private let centerGap: CGFloat = 16
    private let topPanelHeight: CGFloat = 60
    private let middlePanelHeight: CGFloat = 36
    
    init() {
        let videoPlayerVM = VideoPlayerViewModel()
        _videoPlayerViewModel = StateObject(wrappedValue: videoPlayerVM)
        
        let playlist = PlaylistViewModel(videoPlayerViewModel: videoPlayerVM)
        _playlistViewModel = StateObject(wrappedValue: playlist)
    }
    
    var body: some View {
        GeometryReader { geometry in
            let totalHeight = geometry.size.height
            let totalWidth = geometry.size.width
            let totalPadding = outerPadding * 2 + centerGap
            let columnWidth = (totalWidth - totalPadding) / 2
            
            ZStack {
                HStack(spacing: centerGap) {
                    leftColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                    rightColumn(totalHeight: totalHeight, columnWidth: columnWidth)
                }
                .padding(.horizontal, outerPadding)
                .padding(.vertical, outerPadding)
                .allowsHitTesting(!showingDownloadProgressWindow)  // Block ALL touches during download
                .opacity(showingDownloadProgressWindow ? 0.3 : 1.0)  // Gray out during download
                
                if videoPlayerViewModel.currentVideo != nil {
                    CustomVideoPlayerView(viewModel: videoPlayerViewModel)
                        .ignoresSafeArea()
                        .allowsHitTesting(!showingDownloadProgressWindow)  // Block video player touches too
                }
            }
            .background(AppTheme.appBackground.ignoresSafeArea())
        }

        .onChange(of: settingsViewModel.filePickerService.processingState) { _, newState in
            switch newState {
            case .processing, .paused:
                // Immediately show progress window and dismiss settings
                showingDownloadProgressWindow = true
                showSettings = false  // Close settings window
            case .completed, .cancelled:
                showingDownloadProgressWindow = true  // Keep showing until manually closed
            case .idle:
                showingDownloadProgressWindow = false
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(settingsViewModel)  // Pass shared settings view model
        }
        .sheet(isPresented: $settingsViewModel.isShowingFolderPicker) {
            FolderPickerView(
                isPresented: $settingsViewModel.isShowingFolderPicker,
                onFolderSelected: settingsViewModel.handleFolderSelected,
                onError: settingsViewModel.handleFilePickerError
            )
        }
        .sheet(isPresented: $showingCustomResults) {
            DownloadResultsView(
                results: settingsViewModel.filePickerService.results,
                onDismiss: {
                    showingCustomResults = false
                }
            )
        }
        .fullScreenCover(isPresented: $showingDownloadProgressWindow) {
            // GLOBAL DOWNLOAD PROGRESS WINDOW - Appears above EVERYTHING including sheets
            DownloadProgressWindow(
                progress: settingsViewModel.filePickerService.batchProgress,
                filePickerService: settingsViewModel.filePickerService,
                onDismiss: {
                    showingDownloadProgressWindow = false
                },
                onShowResults: {
                    showingCustomResults = true
                }
            )
            .background(Color.clear) // Transparent background since the window has its own
        }
        .environmentObject(videoPlayerViewModel)
        .onAppear {
            NotificationCenter.default.addObserver(
                forName: .deleteSongFromPlaylist,
                object: nil,
                queue: .main
            ) { notification in
                if let song = notification.object as? Song {
                    print("🗑️ ContentView - Removing song from playlist: \(song.title)")
                    Task {
                        await playlistViewModel.removeFromPlaylist(song)
                    }
                }
            }
            
            // Handle folder picker requests from Settings
            NotificationCenter.default.addObserver(
                forName: .requestFolderPicker,
                object: nil,
                queue: .main
            ) { _ in
                print("📁 ContentView - Folder picker requested - dismissing Settings and showing folder picker")
                showSettings = false  // Dismiss Settings first
                
                // Small delay to ensure Settings dismisses before presenting folder picker
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    settingsViewModel.isShowingFolderPicker = true
                }
            }
        }
    }
    
    private func leftColumn(totalHeight: CGFloat, columnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top Left Panel - TITLE
            TitlePanelView()
                .frame(height: topPanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.leftPanelBorderColor, lineWidth: 1)
                )
            
            // Bottom Left Panel - SONG LIST (now takes remaining space)
            SongListView(playlistViewModel: playlistViewModel)
                .frame(maxHeight: CGFloat.infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.purple, lineWidth: 1)
                )
        }
        .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
    }
    
    private func rightColumn(totalHeight: CGFloat, columnWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Top Right Panel - EMPTY with COG icon
            EmptyPanelView(onSettingsTapped: { showSettings = true })
                .frame(height: topPanelHeight)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(AppTheme.rightPanelBorderColor, lineWidth: 1)
                )
            
            // Bottom Right Panel - PLAYLIST (now takes remaining space)
            PlaylistView(
                viewModel: playlistViewModel,
                onSongSelected: { song in
                    print("🎬 ContentView.onSongSelected - Song tapped: '\(song.title)'")
                    playlistViewModel.playSong(song)
                }
            )
            .frame(maxHeight: CGFloat.infinity)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.red, lineWidth: 1)
            )
        }
        .frame(width: columnWidth, height: totalHeight - outerPadding * 2)
    }
    
    private func startPlayback(_ song: Song) {
        Task {
            await videoPlayerViewModel.play(song: song)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .previewInterfaceOrientation(.landscapeLeft)
    }
}

// MARK: - Custom Video Player View
struct CustomVideoPlayerView: View {
    @ObservedObject var viewModel: VideoPlayerViewModel
    @GestureState private var dragOffset = CGSize.zero
    @State private var basePosition = CGSize.zero
    
    // Constants following app patterns
    private let cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius
    private let minWidth: CGFloat = 640  // Doubled from 320
    private let maxWidth: CGFloat = 960  // Doubled from 480
    private let aspectRatio: CGFloat = 16.0 / 9.0
    
    var body: some View {
        if viewModel.currentVideo != nil {
            GeometryReader { geometry in
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        
                        // SINGLE video player container - NO DUPLICATES
                        videoPlayerContainer(geometry)
                            .frame(
                                width: viewModel.isMinimized ? calculateMinimizedWidth(geometry) : geometry.size.width,
                                height: viewModel.isMinimized ? calculateMinimizedHeight(geometry) : geometry.size.height
                            )
                            .cornerRadius(viewModel.isMinimized ? cornerRadius : 0)
                            .offset(viewModel.isMinimized ? CGSize(width: basePosition.width + dragOffset.width, height: basePosition.height + dragOffset.height) : .zero)
                            .gesture(
                                viewModel.isMinimized ? dragGesture(in: geometry) : nil
                            )
                            
                        
                        Spacer()
                    }
                    Spacer()
                }
                .background(viewModel.isMinimized ? Color.clear : Color.black)
            }
            .onAppear {
                // Initialize local position from viewModel
                basePosition = viewModel.overlayOffset
            }
            .onChange(of: viewModel.overlayOffset) { _, newOffset in
                // Always sync local position with viewModel (especially when centering)
                basePosition = newOffset
                print("🔄 Synced basePosition to: \(newOffset)")
            }
        }
    }
    
    @ViewBuilder
    private func videoPlayerContainer(_ geometry: GeometryProxy) -> some View {
        ZStack {
            // ONLY ONE VideoPlayer instance - immediate load
            if let player = viewModel.player {
                VideoPlayer(player: player)
                    .disabled(!viewModel.isAirPlayActive) // Enable during AirPlay, disabled otherwise
                    .background(Color.black) // Ensure consistent background
            }
            
            // Only add our gesture overlay when NOT in AirPlay mode
            if !viewModel.isAirPlayActive {
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 1) {
                        if dragOffset == .zero {
                            print("👆 SINGLE TAP detected - showing controls")
                            viewModel.showControls()
                        }
                    }
                    .onTapGesture(count: 2) {
                        if dragOffset == .zero {
                            print("👆👆 DOUBLE TAP detected - toggling size")
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            viewModel.toggleSize()
                        }
                    }
                    .onTapGesture(count: 3) {
                        if dragOffset == .zero && viewModel.isMinimized {
                            print("👆👆👆 TRIPLE TAP detected - centering video")
                            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
                            impactFeedback.impactOccurred()
                            viewModel.centerVideo()
                        }
                    }
            }
            
            // Custom controls overlay - ALWAYS in the same container
            // Hide custom controls when AirPlay is active, let native controls take over
            if viewModel.areControlsVisible && !viewModel.isAirPlayActive {
                customControlsOverlay()
            }
            
            // Show AirPlay indicator when streaming
            if viewModel.isAirPlayActive {
                airPlayIndicator()
            }
        }
    }
    
    @ViewBuilder
    private func customControlsOverlay() -> some View {
        VStack {
            Spacer()
            
            VStack(spacing: 16) {
                // Play/Pause and Skip Controls
                HStack(spacing: 30) {
                    Button(action: { 
                        Task { await viewModel.skipBackward() }
                        viewModel.showControls()
                    }) {
                        Image(systemName: "gobackward.10")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                    
                    Button(action: { 
                        viewModel.togglePlayPause()
                        viewModel.showControls()
                    }) {
                        Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                            .foregroundColor(.white)
                            .font(.title)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                    
                    Button(action: { 
                        Task { await viewModel.skipForward() }
                        viewModel.showControls()
                    }) {
                        Image(systemName: "goforward.10")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                }
                
                // Progress bar with times and delete button
                HStack(spacing: 12) {
                    Text(viewModel.formattedCurrentTime)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Slider(value: Binding(
                        get: { viewModel.currentTime },
                        set: { newValue in
                            Task { await viewModel.seek(to: newValue) }
                            viewModel.showControls()
                        }
                    ), in: 0...max(viewModel.duration, 1))
                    .accentColor(.white)
                    
                    Text(viewModel.formattedTimeRemaining)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.white)
                    
                    Button(action: { 
                        viewModel.deleteSong()
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .buttonStyle(VideoControlButtonStyle())
                }
            }
            .padding(20)
            .background(Color.black.opacity(0.1))
        }
        .allowsHitTesting(true) // CRITICAL: Ensure controls are always tappable
    }
    
    @ViewBuilder
    private func airPlayIndicator() -> some View {
        VStack {
            Spacer()
            
            HStack(spacing: 12) {
                Image(systemName: "airplayvideo")
                    .foregroundColor(.white)
                    .font(.title2)
                
                Text("Streaming to AirPlay")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Delete button in AirPlay mode
                Button(action: { 
                    viewModel.deleteSong()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            .padding(20)
            .background(Color.black.opacity(0.7))
            .cornerRadius(12)
            .padding(.bottom, 40)
            .padding(.horizontal, 20)
        }
    }
    
    // ZERO @Published access during drag - pure smooth performance
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                // Pure local state - zero @Published property access
                state = value.translation
            }
            .onChanged { _ in
                // PERFORMANCE: Enter ultra-performance mode on first drag movement
                Task {
                    await viewModel.startDragging()
                }
            }
            .onEnded { value in
                // PERFORMANCE: Exit ultra-performance mode when drag ends
                Task {
                    await viewModel.stopDragging()
                }
                
                // Commit final position - update both local and viewModel
                basePosition = CGSize(
                    width: basePosition.width + value.translation.width,
                    height: basePosition.height + value.translation.height
                )
                viewModel.overlayOffset = basePosition
            }
    }
    
    // Helper methods
    private func calculateMinimizedWidth(_ geometry: GeometryProxy) -> CGFloat {
        let preferredWidth = geometry.size.width * 0.5  // Doubled from 0.25 to 0.5
        return max(minWidth, min(maxWidth, preferredWidth))
    }
    
    private func calculateMinimizedHeight(_ geometry: GeometryProxy) -> CGFloat {
        return calculateMinimizedWidth(geometry) / aspectRatio
    }
}

// MARK: - Custom button style to prevent gesture interference
struct VideoControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .allowsHitTesting(true)
    }
}
