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

    // @State private var searchText: String = "" // COMMENTED OUT - not needed
    // @FocusState private var isSearchFocused: Bool // COMMENTED OUT - not needed

    var body: some View {
        HStack(spacing: innerGap) {
            Spacer()
        }
        .frame(height: panelHeight)
        .frame(maxWidth: .infinity)
        .background(AppTheme.leftPanelBackground)
    }
}
