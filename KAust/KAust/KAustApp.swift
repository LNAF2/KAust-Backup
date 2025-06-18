//
//  KAustApp.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI

@main
struct KAustApp: App {
    @State private var isSignedIn = false
    @State private var currentUserRole: UserRole = .client
    @StateObject private var focusManager = FocusManager()
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
                        // Role-based access control is now implemented!
                if isSignedIn {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(UserRoleManager(role: currentUserRole))
                        .environmentObject(focusManager)
                } else {
                    LoginView(isSignedIn: $isSignedIn, currentUserRole: $currentUserRole)
                        .environmentObject(focusManager)
                }
        }
        .backgroundTask(.appRefresh("keyboard-cleanup")) {
            // Force dismiss keyboards when app goes to background
            await MainActor.run {
                focusManager.forceKeyboardDismiss()
            }
        }
    }
}

private struct IsSignedInKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var isSignedIn: Binding<Bool> {
        get { self[IsSignedInKey.self] }
        set { self[IsSignedInKey.self] = newValue }
    }
}

enum UserRole: String, CaseIterable {
    case client = "client"
    case dev = "dev" 
    case admin = "admin"
    case owner = "owner"
    
    var displayName: String {
        switch self {
        case .client: return "Client"
        case .dev: return "Developer"
        case .admin: return "Admin"
        case .owner: return "Owner"
        }
    }
    
    // Settings access levels based on GitHub commit specifications
    var canAccessSettings: Bool {
        switch self {
        case .client, .dev, .admin, .owner: return true  // All roles can access settings panel
        }
    }
    
    var canAccessAirplaySettings: Bool {
        switch self {
        case .client, .dev, .admin, .owner: return true  // Everyone sees Airplay settings
        }
    }
    
    var canAccessAdministratorSettings: Bool {
        switch self {
        case .client: return false                       // Client: Only Airplay
        case .admin, .dev, .owner: return true          // Admin/Dev/Owner: Airplay + Admin settings
        }
    }
    
    var canAccessAllSettings: Bool {
        switch self {
        case .client, .admin: return false               // Client/Admin: Limited access
        case .dev, .owner: return true                   // Dev/Owner: See everything
        }
    }
}

class UserRoleManager: ObservableObject {
    @Published var currentRole: UserRole
    
    init(role: UserRole) {
        self.currentRole = role
    }
    
    var canAccessSettings: Bool {
        currentRole.canAccessSettings
    }
    
    var canAccessAirplaySettings: Bool {
        currentRole.canAccessAirplaySettings
    }
    
    var canAccessAdministratorSettings: Bool {
        currentRole.canAccessAdministratorSettings
    }
    
    var canAccessAllSettings: Bool {
        currentRole.canAccessAllSettings
    }
    
    var roleDisplayName: String {
        currentRole.displayName
    }
}

struct LoginView: View {
    @Binding var isSignedIn: Bool
    @Binding var currentUserRole: UserRole
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Sequential login state
    @State private var loginStep: LoginStep = .username
    
    enum LoginStep {
        case username
        case password
    }
    
    // Focus management for automatic cursor movement
    @EnvironmentObject var focusManager: FocusManager
    @FocusState private var isFieldFocused: Bool
    
    // Valid credentials
    private let validCredentials = [
        "owner": "qqq",
        "admin": "admin", 
        "dev": "dev",
        "client": "client"
    ]
    
    var body: some View {
        VStack(spacing: 30) {
            // Header
            VStack(spacing: 10) {
                Text("🏛️ KAUST")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                
                Text("Karaoke Australia")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                Text("Please sign in to continue")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            // Sequential Login Form
            VStack(spacing: 20) {
                // Progress indicator
                HStack(spacing: 8) {
                    Circle()
                        .fill(loginStep == .username ? Color.blue : Color.blue.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Circle()
                        .fill(loginStep == .password ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    
                    Spacer()
                    
                    Text("Step \(loginStep == .username ? 1 : 2) of 2")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 40)
                
                // Current field
                VStack(alignment: .leading, spacing: 8) {
                    if loginStep == .username {
                        Text("Username")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        TextField("Enter username", text: $username)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .autocorrectionDisabled()
                            .disableAutocorrection(true)
                            .textInputAutocapitalization(.never)
                            .keyboardType(.default)
                            .submitLabel(.next)
                            .focused($isFieldFocused)
                            .onSubmit {
                                proceedToNextStep()
                            }
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } else {
                        Text("Password")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        SecureField("Enter password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textInputAutocapitalization(.never)
                            .submitLabel(.go)
                            .focused($isFieldFocused)
                            .onSubmit {
                                signIn()
                            }
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: loginStep)
                
                // Action buttons
                VStack(spacing: 12) {
                    if loginStep == .username {
                        Button(action: proceedToNextStep) {
                            HStack {
                                Text("Next")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(username.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(username.isEmpty)
                    } else {
                        Button(action: signIn) {
                            HStack {
                                Image(systemName: "key.fill")
                                Text("Sign In")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(password.isEmpty ? Color.gray : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(password.isEmpty)
                        
                        Button(action: goBackToUsername) {
                            HStack {
                                Image(systemName: "arrow.left")
                                Text("Back")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.clear)
                            .foregroundColor(.blue)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.blue, lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 40)
                .animation(.easeInOut(duration: 0.3), value: loginStep)
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            // Credentials Helper
            VStack(spacing: 8) {
                Text("Valid Credentials:")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("owner / qqq")
                    Text("admin / admin") 
                    Text("dev / dev")
                    Text("client / client")
                }
                .font(.caption)
                .foregroundColor(.blue)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .onAppear {
            // Automatically focus on the current field when login view appears
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
        
        // Clear error when going back
        showError = false
    }
    
    private func signIn() {
        // Clear focus when signing in
        isFieldFocused = false
        focusManager.clearFocus()
        
        print("🔐 Sign in attempt: \(username) / \(password)")
        
        guard let expectedPassword = validCredentials[username.lowercased()],
              expectedPassword == password else {
            showError = true
            errorMessage = "Invalid username or password"
            print("❌ Invalid credentials")
            
            // Go back to username step for retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                goBackToUsername()
            }
            return
        }
        
        // Set the user's role based on their username
        if let role = UserRole(rawValue: username.lowercased()) {
            currentUserRole = role
            print("✅ Valid credentials - signing in as \(role.displayName)")
        } else {
            currentUserRole = .client
            print("⚠️ Unknown role, defaulting to client")
        }
        
        showError = false
        isSignedIn = true
    }
}
