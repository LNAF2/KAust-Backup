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
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
                        // Role-based access control is now implemented!
                if isSignedIn {
                    ContentView()
                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                        .environmentObject(UserRoleManager(role: currentUserRole))
                } else {
                    LoginView(isSignedIn: $isSignedIn, currentUserRole: $currentUserRole)
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
    
    // Focus management for automatic cursor movement
    @FocusState private var focusedField: FocusField?
    
    enum FocusField {
        case username
        case password
    }
    
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
            
            // Login Form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Username")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter username", text: $username)
                        .textFieldStyle(.roundedBorder)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .username)
                        .onSubmit {
                            // Move to password field when Enter is pressed
                            focusedField = .password
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SecureField("Enter password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .password)
                        .onSubmit {
                            // Submit form when Enter is pressed in password field
                            if !username.isEmpty && !password.isEmpty {
                                signIn()
                            }
                        }
                }
                
                Button(action: signIn) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Sign In")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(username.isEmpty || password.isEmpty)
                
                if showError {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)
            
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
            // Automatically focus on username field when login view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .username
            }
        }
    }
    
    private func signIn() {
        // Clear focus when signing in
        focusedField = nil
        
        print("🔐 Sign in attempt: \(username) / \(password)")
        
        guard let expectedPassword = validCredentials[username.lowercased()],
              expectedPassword == password else {
            showError = true
            errorMessage = "Invalid username or password"
            print("❌ Invalid credentials")
            
            // Re-focus on username field for retry
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                focusedField = .username
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
