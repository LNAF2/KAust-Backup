import SwiftUI

/// The main content view for Kiosk mode settings
struct KioskModeSettingsContent: View {
    @ObservedObject var kioskModeService: KioskModeService
    @EnvironmentObject var roleManager: UserRoleManager
    
    @State private var showingPINSetup = false
    @State private var showingPINChange = false
    @State private var showingPINVerification = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
    var body: some View {
        VStack(spacing: 8) {
            if kioskModeService.isKioskModeActive {
                KioskModeActiveView(
                    showingPINVerification: $showingPINVerification,
                    onDeactivate: deactivateKioskMode
                )
            } else if roleManager.canAccessKioskModeSettings {
                KioskModeManagementView(
                    kioskModeService: kioskModeService,
                    isLoading: $isLoading,
                    showingPINSetup: $showingPINSetup,
                    showingPINChange: $showingPINChange,
                    onToggle: toggleKioskMode
                )
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { showingError = false }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func toggleKioskMode() async {
        await MainActor.run { isLoading = true }
        
        do {
            if kioskModeService.isKioskModeActive {
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
        
        await MainActor.run { isLoading = false }
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

/// View shown when Kiosk mode is active
private struct KioskModeActiveView: View {
    @Binding var showingPINVerification: Bool
    let onDeactivate: (String) async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Status Header
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
                    Task { await onDeactivate(pin) }
                },
                onCancel: { showingPINVerification = false }
            )
        }
    }
}

/// View shown for managing Kiosk mode settings
private struct KioskModeManagementView: View {
    @ObservedObject var kioskModeService: KioskModeService
    @Binding var isLoading: Bool
    @Binding var showingPINSetup: Bool
    @Binding var showingPINChange: Bool
    let onToggle: () async -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
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
            
            if !kioskModeService.isPINSet() {
                // Setup option
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
                // Management options
                VStack(spacing: 0) {
                    // Toggle
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
                                    Task { await onToggle() }
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
                    
                    // Change PIN
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
                onComplete: { showingPINSetup = false },
                onCancel: { showingPINSetup = false }
            )
        }
        .sheet(isPresented: $showingPINChange) {
            PINChangeFlowView(
                kioskModeService: kioskModeService,
                onComplete: { showingPINChange = false },
                onCancel: { showingPINChange = false }
            )
        }
    }
} 