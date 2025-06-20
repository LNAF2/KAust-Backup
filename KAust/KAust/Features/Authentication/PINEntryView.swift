//
//  PINEntryView.swift
//  KAust
//
//  Created by Erling Breaden on 19/6/2025.
//

import SwiftUI

// MARK: - PIN Entry Mode

enum PINEntryMode: Equatable {
    case create
    case verify
    case change(currentPIN: String)
    
    var title: String {
        switch self {
        case .create:
            return "Create Kiosk Mode PIN"
        case .verify:
            return "Enter PIN to Access Admin Settings"
        case .change:
            return "Change Kiosk Mode PIN"
        }
    }
    
    var subtitle: String {
        switch self {
        case .create:
            return "Create a 4-6 digit PIN to secure Kiosk Mode"
        case .verify:
            return "Enter your Kiosk Mode PIN"
        case .change:
            return "Enter a new 4-6 digit PIN"
        }
    }
    
    var buttonText: String {
        switch self {
        case .create:
            return "Create PIN"
        case .verify:
            return "Verify PIN"
        case .change:
            return "Change PIN"
        }
    }
}

// MARK: - PIN Entry View

struct PINEntryView: View {
    let mode: PINEntryMode
    let onSuccess: (String) -> Void
    let onCancel: () -> Void
    
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isShowingConfirm = false
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    @FocusState private var isPINFocused: Bool
    @FocusState private var isConfirmFocused: Bool
    
    private let maxPINLength = 6
    private let minPINLength = 4
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onCancel()
                }
            
            // PIN Entry Card
            VStack(spacing: 0) {
                pinEntryCard
            }
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(32)
        }
        .onAppear {
            isPINFocused = true
        }
    }
    
    // MARK: - PIN Entry Card
    
    private var pinEntryCard: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                HStack {
                    Spacer()
                    Button("Cancel") {
                        onCancel()
                    }
                    .foregroundColor(.blue)
                }
                
                Image(systemName: "lock.shield")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)
                
                Text(mode.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text(mode.subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            
            // PIN Input Section
            VStack(spacing: 16) {
                if !isShowingConfirm {
                    // Primary PIN Entry
                    pinInputField(
                        title: isChangePIN ? "New PIN" : "PIN",
                        text: $pin,
                        isFocused: $isPINFocused
                    )
                } else {
                    // Confirm PIN Entry
                    pinInputField(
                        title: "Confirm PIN",
                        text: $confirmPin,
                        isFocused: $isConfirmFocused
                    )
                }
                
                // Error Message
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }
            }
            .padding(.horizontal, 20)
            
            // Action Buttons
            VStack(spacing: 12) {
                // Primary Action Button
                Button(action: handlePrimaryAction) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        }
                        
                        Text(isShowingConfirm ? "Confirm" : mode.buttonText)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isButtonEnabled ? .blue : .gray)
                    )
                }
                .disabled(!isButtonEnabled || isLoading)
                
                // Secondary Actions
                if isShowingConfirm {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingConfirm = false
                            confirmPin = ""
                            errorMessage = nil
                            isPINFocused = true
                        }
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - PIN Input Field
    
    private func pinInputField(title: String, text: Binding<String>, isFocused: FocusState<Bool>.Binding) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            HStack {
                SecureField("Enter \(minPINLength)-\(maxPINLength) digits", text: text)
                    .keyboardType(.numberPad)
                    .focused(isFocused)
                    .onChange(of: text.wrappedValue) { _, newValue in
                        // Limit to numeric characters and max length
                        let filtered = String(newValue.filter { $0.isNumber }.prefix(maxPINLength))
                        if filtered != newValue {
                            text.wrappedValue = filtered
                        }
                        
                        // Clear error when user types
                        errorMessage = nil
                    }
                    .onSubmit {
                        handlePrimaryAction()
                    }
                
                // PIN Length Indicator
                Text("\(text.wrappedValue.count)/\(maxPINLength)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isFocused.wrappedValue ? .blue : .clear, lineWidth: 2)
                    )
            )
        }
    }
    
    // MARK: - Computed Properties
    
    private var isChangePIN: Bool {
        if case .change = mode { return true }
        return false
    }
    
    private var isCreatePIN: Bool {
        if case .create = mode { return true }
        return false
    }
    
    private var isButtonEnabled: Bool {
        if isShowingConfirm {
            return confirmPin.count >= minPINLength && !isLoading
        } else {
            return pin.count >= minPINLength && !isLoading
        }
    }
    
    // MARK: - Actions
    
    private func handlePrimaryAction() {
        guard !isLoading else { return }
        
        if isCreatePIN && !isShowingConfirm {
            // Show confirm step for PIN creation
            if pin.count >= minPINLength {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingConfirm = true
                    isConfirmFocused = true
                }
            }
        } else if isShowingConfirm {
            // Verify PIN confirmation matches
            if pin == confirmPin {
                isLoading = true
                onSuccess(pin)
            } else {
                errorMessage = "PINs do not match"
                confirmPin = ""
            }
        } else {
            // Direct PIN verification or change
            if pin.count >= minPINLength {
                isLoading = true
                onSuccess(pin)
            }
        }
    }
}

// MARK: - PIN Setup Flow View

struct PINSetupFlowView: View {
    @ObservedObject var kioskModeService: KioskModeService
    let onComplete: () -> Void
    let onCancel: () -> Void
    
    @State private var currentStep: PINSetupStep = .create
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    enum PINSetupStep {
        case create
        case success
    }
    
    var body: some View {
        Group {
            switch currentStep {
            case .create:
                PINEntryView(
                    mode: .create,
                    onSuccess: { pin in
                        Task {
                            await createPIN(pin)
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
    
    private func createPIN(_ pin: String) async {
        do {
            try await kioskModeService.createPIN(pin)
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

// MARK: - PIN Success View

struct PINSuccessView: View {
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)
                
                Text("PIN Created Successfully")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("You can now activate Kiosk Mode from the settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Done") {
                    onComplete()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                )
                .padding(.top, 16)
            }
            .padding(32)
            .frame(maxWidth: 400)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
            )
            .padding(32)
        }
    }
}

// MARK: - Preview

struct PINEntryView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PINEntryView(
                mode: .create,
                onSuccess: { _ in },
                onCancel: { }
            )
            .previewDisplayName("Create PIN")
            
            PINEntryView(
                mode: .verify,
                onSuccess: { _ in },
                onCancel: { }
            )
            .previewDisplayName("Verify PIN")
        }
    }
} 