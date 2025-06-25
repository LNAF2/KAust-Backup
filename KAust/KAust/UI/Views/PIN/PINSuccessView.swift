import SwiftUI

/// View shown when PIN operations complete successfully
struct PINSuccessView: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 48))
            
            Text("Success!")
                .font(.headline)
                .foregroundColor(.white)
            
            Button("Done") {
                onComplete()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color.black)
    }
} 