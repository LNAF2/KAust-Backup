//
//  SongsPlayedTableView.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import SwiftUI

struct SongsPlayedTableView: View {
    @StateObject private var viewModel = SongsPlayedTableViewModel()
    let onDismiss: () -> Void
    
    init(onDismiss: @escaping () -> Void = {}) {
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with print and done buttons
                headerView
                
                // Table content
                tableContent
            }
            .background(Color.white)
            .navigationTitle("SONGS PLAYED")
            .navigationBarHidden(true) // Hide default navigation bar since we have custom header
        }
        .alert("Error", isPresented: Binding<Bool>(
            get: { viewModel.error != nil },
            set: { _ in viewModel.clearError() }
        )) {
            Button("OK") {
                viewModel.clearError()
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            // Print button (left side) - Standard Apple blue print button
            Button(action: {
                presentPrintDialog()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "printer.fill")
                        .font(.system(size: 16, weight: .medium))
                    Text("Print")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue)
                )
            }
            .accessibilityLabel("Print songs played table")
            
            Spacer()
            
            // Title
            Text("SONGS PLAYED")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Spacer()
            
            // Done button (right side)
            DoneButton {
                onDismiss()
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    private var tableContent: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                VStack {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                    Text("Loading played songs...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                    Spacer()
                }
            } else if viewModel.playedSongs.isEmpty {
                // Empty state
                VStack {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 64))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No Songs Played")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.gray)
                        .padding(.top, 16)
                    Text("Songs will appear here when they are played from the playlist")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 8)
                    Spacer()
                }
            } else {
                // Table with data
                playedSongsTable
            }
        }
    }
    
    private var playedSongsTable: some View {
        VStack(spacing: 0) {
            // Table header
            tableHeader
            
            // Scrollable table content
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(viewModel.playedSongs.indices, id: \.self) { index in
                        let song = viewModel.playedSongs[index]
                        tableRow(for: song, isOdd: index % 2 == 1)
                    }
                }
            }
        }
    }
    
    private var tableHeader: some View {
        HStack(spacing: 0) {
            // DATE column
            Text("DATE")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            
            // TIME column
            Text("TIME")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            
            // SONG column
            Text("SONG")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            
            // ARTIST column
            Text("ARTIST")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 16)
        }
        .padding(.vertical, 12)
        .background(Color.gray.opacity(0.1))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.3)),
            alignment: .bottom
        )
    }
    
    private func tableRow(for song: PlayedSongEntity, isOdd: Bool) -> some View {
        HStack(spacing: 0) {
            // DATE column
            Text(viewModel.formatDate(song.playedDate ?? Date()))
                .font(.body)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 16)
            
            // TIME column
            Text(viewModel.formatTime(song.playedDate ?? Date()))
                .font(.body)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
            
            // SONG column
            Text(song.songTitleSnapshot ?? "Unknown")
                .font(.body)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .lineLimit(1)
            
            // ARTIST column
            Text(song.artistNameSnapshot ?? "Unknown")
                .font(.body)
                .foregroundColor(.black)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 8)
                .padding(.trailing, 16)
                .lineLimit(1)
        }
        .padding(.vertical, 12)
        .background(isOdd ? Color.gray.opacity(0.05) : Color.white)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray.opacity(0.1)),
            alignment: .bottom
        )
    }
    
    private func presentPrintDialog() {
        print("🖨️ Print button tapped - Opening print dialog")
        
        let printData = viewModel.getDataForPrinting()
        
        // Create a formatted string for printing using Swift string formatting
        var printContent = "SONGS PLAYED\n\n"
        
        // Create header row with proper spacing
        let headerLine = String(format: "%-12@ %-10@ %-30@ %-30@\n", "DATE", "TIME", "SONG", "ARTIST")
        printContent += headerLine
        printContent += String(repeating: "-", count: 84) + "\n"
        
        // Add data rows with proper formatting
        for item in printData {
            let truncatedSong = String(item.song.prefix(28))
            let truncatedArtist = String(item.artist.prefix(28))
            
            let formattedLine = String(format: "%-12@ %-10@ %-30@ %-30@\n", 
                                     item.date, 
                                     item.time, 
                                     truncatedSong,
                                     truncatedArtist)
            printContent += formattedLine
        }
        
        // Create print interaction
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Songs Played Table"
        
        printController.printInfo = printInfo
        
        // Create a simple text formatter with modern API
        let formatter = UISimpleTextPrintFormatter(text: printContent)
        formatter.startPage = 0
        
        // Use modern perPageContentInsets instead of deprecated contentInsets
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
                    print("🖨️ Presenting print dialog from: \(type(of: controller))")
                    
                    // Present the print controller
                    printController.present(animated: true, completionHandler: { (_, completed, error) in
                        DispatchQueue.main.async {
                            if let error = error {
                                print("❌ Print error: \(error.localizedDescription)")
                            } else if completed {
                                print("✅ Print completed successfully")
                            } else {
                                print("🚫 Print cancelled by user")
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
} 