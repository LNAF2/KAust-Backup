import SwiftUI

/// Simplified download progress window that shows basic download information
struct DownloadProgressWindow: View {
    let onDismiss: (() -> Void)?
    let onShowResults: (() -> Void)?
    
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
            
            // Main progress window
            VStack(spacing: 20) {
                // Window title
                Text("Downloading Files")
                    .font(.title)
                    .foregroundColor(.white)
                    .padding(.top, 20)
                
                // Placeholder text
                Text("Download functionality temporarily disabled")
                    .font(.headline)
                    .foregroundColor(.gray)
                    .padding(.vertical, 40)
                
                // Close button
                Button(action: {
                    onDismiss?()
                }) {
                    Text("Close")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(width: 120, height: 40)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black)
                    .shadow(color: .black.opacity(0.3), radius: 20)
            )
            .frame(width: 600, height: 300)
        }
    }
}

// MARK: - Preview Provider

struct DownloadProgressWindow_Previews: PreviewProvider {
    static var previews: some View {
        DownloadProgressWindow(
            onDismiss: {},
            onShowResults: {}
        )
    }
} 
