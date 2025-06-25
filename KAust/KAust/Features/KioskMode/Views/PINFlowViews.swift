import SwiftUI

/// Flow for setting up a new PIN
struct PINSetupFlowView: View {
    @ObservedObject var kioskModeService: KioskModeService
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        PINEntryView(
            mode: .setup,
            onSuccess: { pin in
                Task {
                    do {
                        try await kioskModeService.createPIN(pin)
                        await MainActor.run {
                            onComplete()
                        }
                    } catch {
                        print("Failed to create PIN: \(error)")
                    }
                }
            },
            onCancel: onCancel
        )
    }
}

/// Flow for changing an existing PIN
struct PINChangeFlowView: View {
    @ObservedObject var kioskModeService: KioskModeService
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: PINChangeStep = .enterCurrent
    @State private var currentPIN = ""
    @State private var errorMessage: String?
    
    enum PINChangeStep {
        case enterCurrent
        case enterNew
        case success
    }
    
    var body: some View {
        Group {
            switch currentStep {
            case .enterCurrent:
                PINEntryView(
                    mode: .verify,
                    onSuccess: { pin in
                        currentPIN = pin
                        Task {
                            await verifyCurrent(pin)
                        }
                    },
                    onCancel: onCancel
                )
                
            case .enterNew:
                PINEntryView(
                    mode: .change(currentPIN: currentPIN),
                    onSuccess: { newPIN in
                        Task {
                            await changeToNewPIN(newPIN)
                        }
                    },
                    onCancel: onCancel
                )
                
            case .success:
                PINSuccessView(onComplete: onComplete)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    private func verifyCurrent(_ pin: String) async {
        do {
            let isValid = try await kioskModeService.verifyPIN(pin)
            if isValid {
                await MainActor.run {
                    withAnimation {
                        currentStep = .enterNew
                    }
                }
            } else {
                await MainActor.run {
                    errorMessage = "Incorrect PIN"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
    
    private func changeToNewPIN(_ newPIN: String) async {
        do {
            try await kioskModeService.changePIN(current: currentPIN, new: newPIN)
            await MainActor.run {
                withAnimation {
                    currentStep = .success
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }
    }
} 