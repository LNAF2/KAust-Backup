//
//  KioskModeSettingsView.swift
//  KAust
//
//  Created by Erling Breaden on 19/6/2025.
//

import SwiftUI

// MARK: - Kiosk Mode Settings View

struct KioskModeSettingsView: View {
    @ObservedObject var kioskModeService: KioskModeService
    @EnvironmentObject var roleManager: UserRoleManager
    
    @State private var showingPINSetup = false
    @State private var showingPINChange = false
    @State private var showingPINVerification = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        Group {
            if kioskModeService.isKioskModeActive {
                // Kiosk Mode Active - Show limited options
                kioskActiveSection
            } else if roleManager.canAccessKioskModeSettings {
                // Admin/Dev/Owner - Show full Kiosk Mode management (Client cannot see)
                kioskManagementSection
            }
            // Clients and other roles see nothing
        }
    }
    
    // MARK: - Kiosk Mode Active Section
    
    private var kioskActiveSection: some View {
        VStack(spacing: 0) {
            // Kiosk Mode Status Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kiosk Mode Active")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Limited settings access")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Active indicator
                HStack(spacing: 6) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("ACTIVE")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
            
            Divider()
                .background(Color.gray)
            
            // Admin Access Button
            Button(action: { showingPINVerification = true }) {
                HStack {
                    Image(systemName: "key.horizontal")
                        .foregroundColor(.blue)
                        .frame(width: 24)
                    
                    Text("Admin Access")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color.black)
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingPINVerification) {
            PINEntryView(
                mode: .verify,
                onSuccess: { pin in
                    Task {
                        await deactivateKioskMode(with: pin)
                    }
                },
                onCancel: {
                    showingPINVerification = false
                }
            )
        }
    }
    
    // MARK: - Kiosk Management Section
    
    private var kioskManagementSection: some View {
        VStack(spacing: 0) {
            // Section Header
            HStack {
                Text("Kiosk Mode")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
            
            Divider()
                .background(Color.gray)
            
            // PIN Management
            if !kioskModeService.isPINSet() {
                // No PIN set - Show setup option
                Button(action: { showingPINSetup = true }) {
                    HStack {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Set Up Kiosk Mode PIN")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            
                            Text("Required to enable Kiosk Mode")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color.black)
            } else {
                // PIN is set - Show management options
                VStack(spacing: 0) {
                    // Kiosk Mode Toggle
                    HStack {
                        Image(systemName: "lock.shield")
                            .foregroundColor(.blue)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable Kiosk Mode")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            
                            Text("Restrict settings access")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: Binding(
                            get: { kioskModeService.isKioskModeActive },
                            set: { isOn in
                                if isOn {
                                    Task {
                                        await toggleKioskMode()
                                    }
                                }
                            }
                        ))
                        .labelsHidden()
                        .disabled(isLoading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black)
                    
                    Divider()
                        .background(Color.gray)
                    
                    // Change PIN Option
                    Button(action: { showingPINChange = true }) {
                        HStack {
                            Image(systemName: "key.horizontal")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            Text("Change PIN")
                                .foregroundColor(.white)
                                .font(.subheadline)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color.black)
                    .disabled(isLoading)
                }
            }
        }
        .background(Color.black)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
        )
        .sheet(isPresented: $showingPINSetup) {
            PINSetupFlowView(
                kioskModeService: kioskModeService,
                onComplete: {
                    showingPINSetup = false
                },
                onCancel: {
                    showingPINSetup = false
                }
            )
        }
        .sheet(isPresented: $showingPINChange) {
            PINChangeFlowView(
                kioskModeService: kioskModeService,
                onComplete: {
                    showingPINChange = false
                },
                onCancel: {
                    showingPINChange = false
                }
            )
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                showingError = false
            }
        } message: {
            Text(errorMessage)
        }
    }
    
    // MARK: - Actions
    
    private func toggleKioskMode() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            if kioskModeService.isKioskModeActive {
                // This shouldn't happen from the toggle since we only allow turning ON
                // But if it does, we'd need PIN verification for deactivation
                throw KioskModeError.authenticationRequired
            } else {
                try await kioskModeService.activateKioskMode()
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func deactivateKioskMode(with pin: String) async {
        do {
            try await kioskModeService.deactivateKioskMode(with: pin)
            await MainActor.run {
                showingPINVerification = false
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
                showingError = true
                showingPINVerification = false
            }
        }
    }
}

// MARK: - PIN Change Flow View

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

// MARK: - Preview

struct KioskModeSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let mockAuthService = MockAuthenticationService()
        let mockKioskService = KioskModeService(authService: mockAuthService)
        let mockRoleManager = UserRoleManager(role: .admin)
        
        VStack {
            KioskModeSettingsView(kioskModeService: mockKioskService)
                .environmentObject(mockRoleManager)
        }
        .background(Color.black)
        .previewDisplayName("Kiosk Mode Settings")
    }
} 