//
//  VideoPlayerOverlayView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI

struct VideoPlayerOverlayView: View {
    // Sizing constants
    private let overlayWidthRatio: CGFloat = 0.7 // 70% of parent width
    private let overlayAspectRatio: CGFloat = 16.0 / 9.0 // Standard video aspect ratio
    private let cornerRadius: CGFloat = 16
    private let controlSize: CGFloat = 36
    private let progressBarHeight: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let overlayWidth = geometry.size.width * overlayWidthRatio
            let overlayHeight = overlayWidth / overlayAspectRatio

            ZStack {
                // Background (semi-transparent for now)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.7))

                VStack(spacing: 0) {
                    // Top row: Trash icon (delete/close) in top right
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: controlSize, height: controlSize)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                    Spacer()

                    // Center row: Video controls
                    HStack(spacing: 32) {
                        Image(systemName: "gobackward.10")
                        Image(systemName: "play.fill")
                        Image(systemName: "goforward.10")
                    }
                    .font(.system(size: controlSize, weight: .regular))
                    .foregroundColor(.white)
                    .padding(.bottom, 16)

                    // Progress bar
                    VStack(spacing: 4) {
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.3))
                                .frame(height: progressBarHeight)
                            Capsule()
                                .fill(Color.white)
                                .frame(width: overlayWidth * 0.3, height: progressBarHeight) // 30% progress for demo
                        }
                        // Time indicators (optional for maximized view)
                        HStack {
                            Text("00:42")
                            Spacer()
                            Text("03:15")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }
            }
            .frame(width: overlayWidth, height: overlayHeight)
            .shadow(radius: 12)
            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
        }
        .allowsHitTesting(false) // Overlay is static for Phase 1
    }
}

struct VideoPlayerOverlayView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VideoPlayerOverlayView()
        }
        .ignoresSafeArea()
    }
}
