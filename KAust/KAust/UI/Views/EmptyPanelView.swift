//
//  EmptyPanelView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//


import SwiftUI

struct EmptyPanelView: View {
    // MARK: - Properties
    private let panelHeight: CGFloat = AppConstants.Layout.titlePanelHeight
    private let cornerRadiusAmount: CGFloat = AppConstants.Layout.panelCornerRadius
    
    // MARK: - Body
    var body: some View {
        // Empty panel with just the correct styling
        Rectangle()
            .fill(AppTheme.rightPanelBackground)
            .frame(height: panelHeight)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadiusAmount))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadiusAmount)
                    .stroke(AppTheme.appBackground, lineWidth: AppConstants.Layout.panelBorderWidth)
            )
    }
}

// MARK: - Preview
struct EmptyPanelView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyPanelView()
            .padding()
            .previewLayout(.sizeThatFits)
            .background(Color(UIColor.systemGray6))
    }
}
