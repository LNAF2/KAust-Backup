//
//  PanelView.swift
//  KAust
//
//  Created by Erling Breaden on 15/3/2024.
//

import SwiftUI

struct PanelView<Content: View>: View {
    let content: Content
    let backgroundColor: Color
    let accentColor: Color
    let height: CGFloat?
    let cornerRadius: CGFloat
    let borderWidth: CGFloat
    
    init(
        backgroundColor: Color,
        accentColor: Color,
        height: CGFloat? = nil,
        cornerRadius: CGFloat = AppConstants.Layout.panelCornerRadius,
        borderWidth: CGFloat = AppConstants.Layout.panelBorderWidth,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.backgroundColor = backgroundColor
        self.accentColor = accentColor
        self.height = height
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
    }
    
    var body: some View {
        content
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(backgroundColor)
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(accentColor, lineWidth: borderWidth)
            )
    }
}
