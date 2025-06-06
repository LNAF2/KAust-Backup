//
//  DoneButton.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import SwiftUI

struct DoneButton: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text("DONE")
                .fontWeight(.bold)
                .foregroundColor(.blue) // Use your theme color if you prefer
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
        .background(Color.clear)
        .accessibilityLabel("DONE")
    }
}

// Preview
struct DoneButton_Previews: PreviewProvider {
    static var previews: some View {
        DoneButton { }
            .previewLayout(.sizeThatFits)
    }
}
