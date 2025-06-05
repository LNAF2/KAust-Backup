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
    private let gap = AppConstants.Layout.defaultSpacing
    private let filterButtonWidth = AppConstants.Layout.filterButtonWidth

    @State private var searchText: String = ""

    var body: some View {
        HStack(spacing: gap) {
            // Filter Button
            Button(action: {
                // Filter action
            }) {
                HStack {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .foregroundColor(AppTheme.leftPanelAccent)
                    Text("Filter")
                        .foregroundColor(AppTheme.leftPanelAccent)
                }
                .frame(width: filterButtonWidth, height: panelHeight * 0.8)
            }
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.leftPanelListBackground) // <-- Light purple background
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.leftPanelAccent, lineWidth: borderWidth)
                    )
            )

            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppTheme.leftPanelAccent)
                TextField("Search", text: $searchText)
                    .foregroundColor(AppTheme.leftPanelAccent)
                    .accentColor(AppTheme.leftPanelAccent)
            }
            .padding(.horizontal, 8)
            .frame(height: panelHeight * 0.8)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(AppTheme.leftPanelListBackground) // <-- Light purple background
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(AppTheme.leftPanelAccent, lineWidth: borderWidth)
                    )
            )
        }
        .padding(.horizontal, gap)
        .frame(height: panelHeight)
        .background(AppTheme.leftPanelBackground)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(AppTheme.leftPanelAccent, lineWidth: borderWidth)
        )
    }
}
