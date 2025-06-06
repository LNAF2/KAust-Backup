//
//  ControlsPanelView.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import SwiftUI

struct ControlsPanelView: View {
    private let panelHeight = AppConstants.Layout.controlsPanelHeight
    private let cornerRadius = AppConstants.Layout.panelCornerRadius
    private let borderWidth = AppConstants.Layout.panelBorderWidth
    private let filterButtonWidth: CGFloat = 110
    private let innerGap: CGFloat = 2 // Half of panelGap
    private let panelGap: CGFloat = 8 // Must match left panel gap

    @State private var searchText: String = ""
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: innerGap) {
            // Filter Button
            CustomButton(
                title: "Filter",
                icon: "line.3.horizontal.decrease.circle",
                backgroundColor: AppTheme.leftPanelListBackground,
                accentColor: AppTheme.leftPanelAccent
            ) {
                // Filter action
            }
            .frame(width: filterButtonWidth, height: panelHeight * 0.8)

            // Search Bar
            CustomTextField(
                text: $searchText,
                placeholder: "Search",
                icon: "magnifyingglass",
                backgroundColor: AppTheme.leftPanelListBackground,
                accentColor: AppTheme.leftPanelAccent,
                isFocused: isSearchFocused
            )
            .frame(height: panelHeight * 0.8)
            .frame(maxWidth: .infinity)
            .padding(.trailing, panelGap) // <-- This ensures right edge matches left gap
        }
        .frame(height: panelHeight)
        .background(AppTheme.leftPanelBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.leftPanelAccent, lineWidth: borderWidth)
        )
        // No .padding(.horizontal) here!
    }
}
