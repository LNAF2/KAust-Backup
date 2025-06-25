/*
 * TEMPORARILY COMMENTED OUT - DO NOT DELETE
 * This file contains the feature-specific file picker view that is currently disabled
 * but may be needed in the future.
 */

/*
import SwiftUI
import UniformTypeIdentifiers

struct FeatureFilePickerView: View {
    @Binding var isPresented: Bool
    let onFilesSelected: ([URL]) -> Void
    let onError: (Error) -> Void
    
    var body: some View {
        FilePickerView(
            isPresented: $isPresented,
            onFilesSelected: onFilesSelected,
            onError: onError
        )
    }
}
*/ 