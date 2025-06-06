//
//  SettingsView.swift
//  KAust
//
//  Created by Erling Breaden on 3/6/2025.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode

    private let cornerRadius: CGFloat = 16
    private let iconSize: CGFloat = 28
    private let gap: CGFloat = 24

    var body: some View {
        ZStack {
            // Black background fills the whole screen
            Color.black.ignoresSafeArea()

            VStack(alignment: .leading, spacing: gap) {
                // Top row: RESET and DONE
                HStack {
                    Button(action: {
                        // Call your reset action here
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
                    DoneButton {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                .padding(.top, 32)
                .padding(.horizontal, 32)
                .padding(.bottom, 8)

                // Settings items (spaced out)
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
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
