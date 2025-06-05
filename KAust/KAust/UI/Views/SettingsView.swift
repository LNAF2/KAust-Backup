//
//  SettingsView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI

struct SettingsView: View {
    // For now, this is a static shell. Add @Environment(\.dismiss) var dismiss if you want to close it later.

    private let cornerRadius: CGFloat = 16
    private let iconSize: CGFloat = 28
    private let gap: CGFloat = 24

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Black background
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: gap) {
                // Top row: Blue RESET icon
                HStack {
                    Button(action: {
                        // Call your reset action here, e.g.:
                        // viewModel.resetSettings()
                    }) {
                        Text("RESET")
                            .font(.headline)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.clear)
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(.top, 32)
                .padding(.bottom, 8)

                // Settings items (static for now)
                Group {
                    Text("User Account")
                    Text("Manage Downloaded Songs")
                    Text("Audio Output")
                    Text("Volume")
                    Text("Notifications")
                    Text("App Version")
                }
                .font(.title3)
                .foregroundColor(.white)
                .padding(.vertical, 4)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
