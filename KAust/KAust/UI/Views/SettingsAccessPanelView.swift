//
//  SettingsAccessPanelView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI

struct SettingsAccessPanelView: View {
    var onSettingsTapped: () -> Void

    private let panelHeight: CGFloat = AppConstants.Layout.controlsPanelHeight
    private let cornerRadiusAmount: CGFloat = AppConstants.Layout.panelCornerRadius
    private let iconSize: CGFloat = 24.0
    private let iconPadding: CGFloat = 12.0

    var body: some View {
        HStack {
            Spacer()
            Button(action: onSettingsTapped) {
                Image(systemName: "gearshape")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: iconSize, height: iconSize)
                    .foregroundColor(AppTheme.rightPanelAccent)
                    .padding(.trailing, iconPadding)
                    .symbolRenderingMode(.monochrome)
            }
        }
        .frame(height: panelHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.rightPanelBackground)
    }
}

struct SettingsAccessPanelView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsAccessPanelView {
            // Preview action
        }
        .padding()
        .previewLayout(.sizeThatFits)
        .background(Color(UIColor.systemGray6))
    }
}
