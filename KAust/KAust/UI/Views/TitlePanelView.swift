//
//  TitlePanelView.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import SwiftUI

struct TitlePanelView: View {
    private let panelHeight = AppConstants.Layout.titlePanelHeight
    private let cornerRadius = AppConstants.Layout.panelCornerRadius
    private let borderWidth = AppConstants.Layout.panelBorderWidth
    private let panelGap: CGFloat = 8 // Match ControlsPanelView's panelGap
    private let starSize: CGFloat = 12.0
    private let logoFontName: String = "Helvetica" // Replace with your font if needed

    var textFontSize: CGFloat { panelHeight * 0.60 }
    private let kFontSize: CGFloat = 200 // Large on purpose, will be clipped/scaled

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            Text("REAL")
                .font(.custom(logoFontName, size: textFontSize))
                .foregroundColor(AppTheme.leftPanelAccent)

            // The "K" is huge, but clipped to panel height
            Text("K")
                .font(.custom(logoFontName, size: kFontSize))
                .foregroundColor(AppTheme.rightPanelAccent)
                .frame(height: panelHeight)
                .minimumScaleFactor(0.01)
                .lineLimit(1)
                .clipped() // Ensures no overflow

            Image(systemName: "star.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: starSize, height: starSize)
                .foregroundColor(AppTheme.rightPanelAccent)

            Text("ARAOKE")
                .font(.custom(logoFontName, size: textFontSize))
                .foregroundColor(AppTheme.leftPanelAccent)

            Spacer()
        }
        .padding(.horizontal, panelGap) // Use panelGap to match ControlsPanelView
        .frame(height: panelHeight)
        .background(AppTheme.leftPanelBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.appBackground, lineWidth: borderWidth)
        )
    }
}

struct TitlePanelView_Previews: PreviewProvider {
    static var previews: some View {
        TitlePanelView()
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color(UIColor.systemGray6))
    }
}
