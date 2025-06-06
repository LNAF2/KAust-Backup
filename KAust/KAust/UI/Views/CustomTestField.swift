//
//  CustomTextField.swift
//  KAust
//
//  Created by Erling Breaden on 15/3/2024.
//

import SwiftUI

struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let backgroundColor: Color
    let accentColor: Color
    let isFocused: Bool
    
    init(
        text: Binding<String>,
        placeholder: String,
        icon: String? = nil,
        backgroundColor: Color,
        accentColor: Color,
        isFocused: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.isFocused = isFocused
    }
    
    var body: some View {
        HStack {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundColor(accentColor)
            }
            
            TextField(placeholder, text: $text)
                .foregroundColor(accentColor)
                .accentColor(accentColor)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(accentColor.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(backgroundColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .stroke(isFocused ? accentColor : accentColor.opacity(0.5),
                       lineWidth: isFocused ? 2 : AppConstants.Layout.panelBorderWidth)
        )
    }
}
