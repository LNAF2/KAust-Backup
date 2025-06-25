//
//  EmptyPanelView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//


import SwiftUI

struct EmptyPanelView: View {
    let onSettingsTapped: () -> Void
    
    // MARK: - Properties
    private let panelHeight: CGFloat = AppConstants.Layout.titlePanelHeight
    private let cornerRadiusAmount: CGFloat = AppConstants.Layout.panelCornerRadius
    
    // COG icon properties
    private let iconSize: CGFloat = 24.0
    private let iconPadding: CGFloat = 8.0
    
    // MARK: - Body
    var body: some View {
        ZStack {
            Rectangle()
                .fill(AppTheme.rightPanelBackground)
                .frame(height: panelHeight)
                .frame(maxWidth: .infinity)
                .overlay(
                    Rectangle()
                        .stroke(AppTheme.rightPanelAccent, lineWidth: 1)
                )
            
            HStack {
                Spacer()
                
                // COG icon positioned on the right side
                Button(action: {
                    print("Settings icon tapped")
                    onSettingsTapped()
                }) {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: iconSize, height: iconSize)
                        .foregroundColor(AppTheme.rightPanelAccent)
                        .symbolRenderingMode(.monochrome)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.trailing, iconPadding)
            }
            .padding(.horizontal, 8)
        }
    }
}

// MARK: - Preview
struct EmptyPanelView_Previews: PreviewProvider {
    static var previews: some View {
        EmptyPanelView(onSettingsTapped: {
            // Preview action
            print("Settings tapped")
        })
        .padding()
        .previewLayout(.sizeThatFits)
        .background(Color(UIColor.systemGray6))
    }
}
