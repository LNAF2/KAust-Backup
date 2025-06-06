//
//  CustomButton.swift
//  KAust
//
//  Created by Erling Breaden on 15/3/2024.
//

import SwiftUI

struct CustomButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let backgroundColor: Color
    let accentColor: Color
    let isSelected: Bool
    
    init(
        title: String,
        icon: String? = nil,
        backgroundColor: Color,
        accentColor: Color,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(accentColor)
                }
                Text(title)
                    .foregroundColor(accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(isSelected ? accentColor.opacity(0.15) : backgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .stroke(accentColor, lineWidth: AppConstants.Layout.panelBorderWidth)
            )
        }
    }
}
