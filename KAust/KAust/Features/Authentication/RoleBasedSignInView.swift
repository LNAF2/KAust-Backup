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
                // Background
                AppTheme.appBackground
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 32) {
                    Spacer()
                    
                    // App title
                    titleSection
                    
                    // Login methods
                    VStack(spacing: 24) {
                        passwordLoginSection
                        
                        dividerSection
                        
                        appleSignInSection
                    }
                    .padding(.horizontal, 40)
                    
                    // Role info button
                    roleInfoButton
                    
                    Spacer()
                    
                    // Current user info (if any)
                    if let user = authService.currentUser {
                        currentUserInfo(user)
                    }
                }
                
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
    
    private var titleSection: some View {
        VStack(spacing: 8) {
            Text("REAL K*ARAOKE")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(AppTheme.leftPanelAccent)
            
            Text("Role-Based Access System")
                .font(.title3)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
        }
    }
    
    private var passwordLoginSection: some View {
        VStack(spacing: 16) {
            Text("Sign In with Role Credentials")
                .font(.headline)
                .foregroundColor(AppTheme.leftPanelAccent)
            
            // Progress indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(loginStep == .username ? AppTheme.leftPanelAccent : AppTheme.leftPanelAccent.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Circle()
                    .fill(loginStep == .password ? AppTheme.leftPanelAccent : Color.gray.opacity(0.3))
                    .frame(width: 8, height: 8)
                
                Spacer()
                
                Text("Step \(loginStep == .username ? 1 : 2) of 2")
                    .font(.caption)
                    .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
            }
            .padding(.horizontal, 16)
            
            VStack(spacing: 12) {
                // Current field
                if loginStep == .username {
                    HStack {
                        Image(systemName: "person.circle")
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                            .frame(width: 20)
                        
                        TextField("Username (owner, admin, dev, client)", text: $username)
                            .textFieldStyle(.plain)
                            .focused($isFieldFocused)
                            .autocorrectionDisabled()
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.default)
                            .submitLabel(.next)
                            .onSubmit {
                                proceedToNextStep()
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(AppTheme.leftPanelAccent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .leading).combined(with: .opacity))
                } else {
                    HStack {
                        Image(systemName: "lock.circle")
                            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                            .frame(width: 20)
                        
                        SecureField("Password", text: $password)
                            .textFieldStyle(.plain)
                            .focused($isFieldFocused)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.go)
                            .onSubmit {
                                Task {
                                    await performPasswordLogin()
                                }
                            }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(AppTheme.leftPanelAccent.opacity(0.3), lineWidth: 1)
                            )
                    )
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
                
                // Action buttons
                VStack(spacing: 8) {
                    if loginStep == .username {
                        Button(action: proceedToNextStep) {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(username.isEmpty ? Color.gray : AppTheme.leftPanelAccent)
                            )
                        }
                        .disabled(username.isEmpty)
                    } else {
                        Button(action: {
                            Task {
                                await performPasswordLogin()
                            }
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                }
                                
                                Text(isLoading ? "Signing In..." : "Sign In")
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .fill(password.isEmpty ? Color.gray : AppTheme.leftPanelAccent)
                            )
                        }
                        .disabled(isLoading || password.isEmpty)
                        
                        Button(action: goBackToUsername) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                            .font(.headline)
                            .foregroundColor(AppTheme.leftPanelAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .stroke(AppTheme.leftPanelAccent, lineWidth: 1)
                            )
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: loginStep)
        }
    }
    
    private var dividerSection: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.3))
            
            Text("OR")
                .font(.caption)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
                .padding(.horizontal, 16)
            
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.3))
        }
    }
    
    private var appleSignInSection: some View {
        VStack(spacing: 12) {
            Text("Sign In with Apple ID")
                .font(.headline)
                .foregroundColor(AppTheme.leftPanelAccent)
            
            Text("(Default: Client Role)")
                .font(.caption)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
            
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    Task {
                        await handleAppleSignIn(result)
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50)
            .cornerRadius(cornerRadius)
        }
    }
    
    private var roleInfoButton: some View {
        Button(action: {
            showingRoleInfo = true
        }) {
            HStack {
                Image(systemName: "info.circle")
                Text("View Role Information")
            }
            .font(.caption)
            .foregroundColor(AppTheme.leftPanelAccent.opacity(0.7))
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
    
    private func currentUserInfo(_ user: UserSession) -> some View {
        VStack(spacing: 4) {
            Text("Current User")
                .font(.caption)
                .foregroundColor(AppTheme.leftPanelAccent.opacity(0.6))
            
            Text("\(user.displayName) (\(user.role.displayName))")
                .font(.subheadline)
                .foregroundColor(AppTheme.leftPanelAccent)
            
            Button("Sign Out") {
                Task {
                    await authService.signOut()
                }
            }
            .font(.caption)
            .foregroundColor(.red)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(AppTheme.leftPanelAccent.opacity(0.1))
        )
        .padding(.horizontal, 40)
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