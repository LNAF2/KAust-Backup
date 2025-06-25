import SwiftUI

/// View for entering a PIN code with different modes (setup, verify, change)
struct PINEntryView: View {
    enum Mode {
        case setup
        case verify
        case change(currentPIN: String)
    }
    
    let mode: Mode
    let onSuccess: (String) -> Void
    let onCancel: () -> Void
    
    @State private var pin = ""
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 24) {
            Text(titleForMode)
                .font(.headline)
                .foregroundColor(.white)
            
            SecureField("Enter PIN", text: $pin)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .padding(.horizontal)
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack(spacing: 16) {
                Button("Cancel", role: .cancel) {
                    onCancel()
                }
                .buttonStyle(.bordered)
                
                Button("Confirm") {
                    validateAndSubmit()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color.black)
    }
    
    private var titleForMode: String {
        switch mode {
        case .setup:
            return "Set Up PIN"
        case .verify:
            return "Enter PIN"
        case .change:
            return "Enter New PIN"
        }
    }
    
    private func validateAndSubmit() {
        guard pin.count >= 4 else {
            errorMessage = "PIN must be at least 4 digits"
            return
        }
        
        guard pin.count <= 6 else {
            errorMessage = "PIN must be no more than 6 digits"
            return
        }
        
        onSuccess(pin)
    }
} 