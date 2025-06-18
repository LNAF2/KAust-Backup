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
                // Beautiful new purple login screen with large title!
                BeautifulLoginView(isSignedIn: $isSignedIn, currentUserRole: $currentUserRole)
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

// MARK: - Beautiful Purple Login Screen

struct BeautifulLoginView: View {
    @Binding var isSignedIn: Bool
    @Binding var currentUserRole: UserRole
    @State private var username = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isLoading = false
    
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
    
    private let cornerRadius: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Beautiful darker purple background - rich and dramatic
                Color(red: 0.35, green: 0.08, blue: 0.40)  // Deep purple
                    .ignoresSafeArea()
                
                // Main content
                VStack(spacing: 40) {
                    Spacer()
                    
                    // Large stylized title - exactly as requested!
                    HStack(alignment: .center, spacing: 8) {
                        // "REAL" in white (no bold)
                        Text("REAL")
                            .font(.system(size: 72, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                        
                        // "K" in red (large, no bold)
                        Text("K")
                            .font(.system(size: 120, weight: .regular, design: .rounded))
                            .foregroundColor(.red)
                        
                        // Star in red
                        Image(systemName: "star.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 32, height: 32)
                            .foregroundColor(.red)
                        
                        // "ARAOKE" in white (no bold)
                        Text("ARAOKE")
                            .font(.system(size: 72, weight: .regular, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: .black.opacity(0.3), radius: 4, x: 2, y: 2)
                    
                    // Compact login card
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
                                        .onSubmit(signIn)
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
                                        signIn()
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
                        
                        if showError {
                            Text(errorMessage)
                                .foregroundColor(.red)
                                .font(.caption)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 400)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.ultraThinMaterial)
                            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
                    )
                    
                    Spacer()
                }
                .padding(.horizontal, 32)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
        .onDisappear {
            isFieldFocused = false
            focusManager.forceKeyboardDismiss()
        }
        .onChange(of: loginStep) { _, _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFieldFocused = true
            }
        }
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
        
        showError = false
        isLoading = false
    }
    
    private func signIn() {
        isFieldFocused = false
        focusManager.clearFocus()
        isLoading = true
        
        guard let expectedPassword = validCredentials[username.lowercased()],
              expectedPassword == password else {
            showError = true
            errorMessage = "Invalid username or password"
            isLoading = false
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                goBackToUsername()
            }
            return
        }
        
        if let role = UserRole(rawValue: username.lowercased()) {
            currentUserRole = role
        } else {
            currentUserRole = .client
        }
        
        showError = false
        isLoading = false
        isSignedIn = true
    }
}
