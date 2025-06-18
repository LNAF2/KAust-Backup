//
//  RoleBasedSignInView.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import SwiftUI
import AuthenticationServices

struct RoleBasedSignInView: View {
    @StateObject private var authService = AuthenticationService()
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isSignedIn) private var isSignedIn
    @EnvironmentObject private var focusManager: FocusManager
    
    // Form state
    @State private var username = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var showError = false
    @State private var showingRoleInfo = false
    
    // Sequential login state
    @State private var loginStep: LoginStep = .username
    
    enum LoginStep {
        case username
        case password
    }
    
    @FocusState private var isFieldFocused: Bool
    
    private let cornerRadius: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Beautiful purple background using the dark purple from assets
                AppTheme.leftPanelBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 60) {
                    // Large beautiful title above login
                    VStack(spacing: 8) {
                        HStack(spacing: 8) {
                            // "REAL" in white (no bold)
                            Text("REAL")
                                .font(.system(size: 72, weight: .regular))
                                .foregroundColor(.white)
                            
                            // Large "K" in red (no bold)
                            Text("K")
                                .font(.system(size: 120, weight: .regular))
                                .foregroundColor(.red)
                            
                            // Red star
                            Image(systemName: "star.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                            
                            // "ARAOKE" in white (no bold)
                            Text("ARAOKE")
                                .font(.system(size: 72, weight: .regular))
                                .foregroundColor(.white)
                        }
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.top, 40)
                    
                    // Compact login card
                    compactLoginCard
                        .frame(maxWidth: 400)
                    
                    Spacer()
                    
                    // Role info button
                    roleInfoButton
                }
                .padding(.horizontal, 32)
                
                // Loading overlay
                if isLoading {
                    loadingOverlay
                }
            }
        }
        .alert("Authentication Error", isPresented: $showError) {
            Button("OK") {
                showError = false
            }
        } message: {
            if let error = authService.authenticationError {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error.localizedDescription)
                    if let recovery = error.recoverySuggestion {
                        Text(recovery)
                            .font(.caption)
                    }
                }
            }
        }
        .sheet(isPresented: $showingRoleInfo) {
            roleInfoSheet
        }
        .onReceive(authService.$isAuthenticated) { authenticated in
            if authenticated {
                isSignedIn.wrappedValue = true
            }
        }
        .onReceive(authService.$authenticationError) { error in
            if error != nil {
                showError = true
                isLoading = false
            }
        }
        .onAppear {
            // Set initial focus to current field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
        .onDisappear {
            // Force dismiss keyboard to prevent constraint conflicts
            isFieldFocused = false
            focusManager.forceKeyboardDismiss()
        }
        .onChange(of: loginStep) { _, _ in
            // Auto-focus when changing steps
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
    }
    
    // MARK: - View Components
    
    private var compactLoginCard: some View {
        VStack(spacing: 20) {
            // Card header
            VStack(spacing: 8) {
                Text("Sign In")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("Role-Based Access")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Progress dots
                HStack(spacing: 8) {
                    Circle()
                        .fill(loginStep == .username ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(loginStep == .password ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            
            // Sequential input field
            VStack(spacing: 12) {
                if loginStep == .username {
                    // Username field
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        TextField("Username", text: $username)
                            .textFieldStyle(.plain)
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .submitLabel(.next)
                            .onSubmit(proceedToNextStep)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    // Password field
                    HStack {
                        Image(systemName: "lock.circle.fill")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .focused($isFieldFocused)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.go)
                            .onSubmit {
                                Task { await performPasswordLogin() }
                            }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color(.systemGray6))
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
                
                // Action buttons
                HStack(spacing: 12) {
                    if loginStep == .password {
                        // Back button
                        Button(action: goBackToUsername) {
                            Image(systemName: "arrow.left")
                                .font(.headline)
                                .foregroundColor(.blue)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .stroke(Color.blue, lineWidth: 1.5)
                                )
                        }
                    }
                    
                    // Main action button
                    Button(action: {
                        if loginStep == .username {
                            proceedToNextStep()
                        } else {
                            Task { await performPasswordLogin() }
                        }
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            
                            Text(buttonText)
                                .fontWeight(.semibold)
                            
                            if loginStep == .username && !isLoading {
                                Image(systemName: "arrow.right")
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .fill(buttonColor)
                        )
                    }
                    .disabled(isButtonDisabled)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: loginStep)
            
            // Divider
            HStack {
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
                
                Text("OR")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                
                Rectangle()
                    .frame(height: 1)
                    .foregroundColor(.gray.opacity(0.3))
            }
            
            // Apple Sign In (compact)
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task { await handleAppleSignIn(result) }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 44)
            .cornerRadius(cornerRadius)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
    }
    
    private var buttonText: String {
        if isLoading {
            return "Signing In..."
        } else if loginStep == .username {
            return "Next"
        } else {
            return "Sign In"
        }
    }
    
    private var buttonColor: Color {
        if isButtonDisabled {
            return .gray
        } else {
            return .blue
        }
    }
    
    private var isButtonDisabled: Bool {
        if isLoading {
            return true
        } else if loginStep == .username {
            return username.isEmpty
        } else {
            return password.isEmpty
        }
    }
    
    private var roleInfoButton: some View {
        Button(action: { showingRoleInfo = true }) {
            HStack {
                Image(systemName: "info.circle")
                Text("Role Information")
            }
            .font(.caption)
            .foregroundColor(.white.opacity(0.8))
        }
    }
    
    private var loadingOverlay: some View {
        Color.black.opacity(0.3)
            .ignoresSafeArea()
            .overlay(
                VStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Authenticating...")
                        .foregroundColor(.white)
                        .padding(.top, 8)
                }
            )
    }
    
    private var roleInfoSheet: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Role Information")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    ForEach(UserRole.allCases, id: \.self) { role in
                        RoleInfoRow(role: role)
                    }
                }
                .padding()
                
                Spacer()
                
                Text("Contact your administrator for role changes")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.bottom)
            }
            .navigationTitle("User Roles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showingRoleInfo = false
                    }
                }
            }
        }
    }
    
    // MARK: - Sequential Login Helpers
    
    private func proceedToNextStep() {
        guard !username.isEmpty else { return }
        
        isFieldFocused = false
        focusManager.clearFocus()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            loginStep = .password
        }
    }
    
    private func goBackToUsername() {
        isFieldFocused = false
        focusManager.clearFocus()
        
        withAnimation(.easeInOut(duration: 0.3)) {
            loginStep = .username
        }
        
        // Clear any loading state when going back
        isLoading = false
    }
    
    // MARK: - Actions
    
    private func performPasswordLogin() async {
        guard !username.isEmpty && !password.isEmpty else { return }
        
        isLoading = true
        isFieldFocused = false
        focusManager.clearFocus() // Properly dismiss keyboard
        
        do {
            let credentials = LoginCredentials(username: username, password: password)
            try await authService.signIn(with: credentials)
        } catch {
            // Error is handled by the authService and will trigger the alert
            print("Login failed: \(error)")
            
            // Go back to username step for retry on authentication failure
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                goBackToUsername()
            }
        }
        
        isLoading = false
    }
    
    private func handleAppleSignIn(_ result: Result<ASAuthorization, Error>) async {
        isLoading = true
        
        switch result {
        case .success(let authorization):
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                do {
                    try await authService.handleSignInWithAppleCompletion(credential: credential, nonce: nil)
                } catch {
                    print("Apple Sign In failed: \(error)")
                }
            }
        case .failure(let error):
            print("Apple Sign In failed: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
}

// MARK: - Role Info Row Component

struct RoleInfoRow: View {
    let role: UserRole
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Role icon
            Image(systemName: roleIcon)
                .font(.title3)
                .foregroundColor(roleColor)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(role.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(role.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("Access Level: \(accessLevel)")
                    .font(.caption)
                    .foregroundColor(roleColor)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(roleColor.opacity(0.1))
        )
    }
    
    private var roleIcon: String {
        switch role {
        case .client:
            return "person.circle"
        case .dev:
            return "hammer.circle"
        case .admin:
            return "gear.circle"
        case .owner:
            return "crown.circle"
        }
    }
    
    private var roleColor: Color {
        switch role {
        case .client:
            return .blue
        case .dev:
            return .green
        case .admin:
            return .orange
        case .owner:
            return .purple
        }
    }
    
    private var accessLevel: String {
        switch role {
        case .client:
            return "Basic"
        case .dev:
            return "Development"
        case .admin:
            return "Administrative"
        case .owner:
            return "Full Access"
        }
    }
}

// MARK: - Preview

struct RoleBasedSignInView_Previews: PreviewProvider {
    static var previews: some View {
        RoleBasedSignInView()
            .environment(\.isSignedIn, .constant(false))
            .environmentObject(FocusManager())
    }
} 