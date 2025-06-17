//
//  SongsPlayedTableView.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import SwiftUI

struct SongsPlayedTableView: View {
    @StateObject private var viewModel = SongsPlayedTableViewModel()
    @Environment(\.presentationMode) var presentationMode
    
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
            // Print button (left side)
            Button(action: {
                presentPrintDialog()
            }) {
                Image(systemName: "printer")
                    .font(.title2)
                    .foregroundColor(.black)
            }
            .accessibilityLabel("Print")
            
            Spacer()
            
            // Title
            Text("SONGS PLAYED")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.black)
            
            Spacer()
            
            // Done button (right side)
            DoneButton {
                presentationMode.wrappedValue.dismiss()
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
        
        // Create a formatted string for printing
        var printContent = "SONGS PLAYED\n\n"
        printContent += String(format: "%-12s %-10s %-30s %-30s\n", "DATE", "TIME", "SONG", "ARTIST")
        printContent += String(repeating: "-", count: 84) + "\n"
        
        for item in printData {
            let formattedLine = String(format: "%-12s %-10s %-30s %-30s\n", 
                                     item.date, 
                                     item.time, 
                                     String(item.song.prefix(28)), 
                                     String(item.artist.prefix(28)))
            printContent += formattedLine
        }
        
        // Create print interaction
        let printController = UIPrintInteractionController.shared
        let printInfo = UIPrintInfo.printInfo()
        printInfo.outputType = .general
        printInfo.jobName = "Songs Played Table"
        
        printController.printInfo = printInfo
        
        // Create a simple text formatter
        let formatter = UISimpleTextPrintFormatter(text: printContent)
        formatter.startPage = 0
        formatter.contentInsets = UIEdgeInsets(top: 72, left: 72, bottom: 72, right: 72)
        formatter.maximumContentWidth = 6 * 72 // 6 inches
        
        printController.printFormatter = formatter
        
        // Present the print dialog
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            printController.present(animated: true, completionHandler: { (controller, completed, error) in
                if let error = error {
                    print("❌ Print error: \(error)")
                } else if completed {
                    print("✅ Print completed successfully")
                } else {
                    print("🚫 Print cancelled by user")
                }
            })
        }
    }
} 