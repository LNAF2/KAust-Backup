//
//  AuthenticationService.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation
import AuthenticationServices
import Combine

/// Main authentication service implementation
@MainActor
final class AuthenticationService: ObservableObject, AuthenticationServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: UserSession?
    @Published private(set) var authenticationError: AuthenticationError?
    
    // MARK: - Protocol Requirements
    
    var isAuthenticatedPublisher: Published<Bool>.Publisher {
        $isAuthenticated
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let dataProvider: DataProviderServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    // Hardcoded credentials for role-based authentication
    private let roleCredentials: [String: (password: String, role: UserRole)] = [
        "owner": ("qqq", .owner),
        "admin": ("admin", .admin), 
        "client": ("client", .client),
        "dev": ("dev", .dev)
    ]
    
    // MARK: - Session Management Keys
    
    private enum SessionKeys {
        static let isAuthenticated = "isAuthenticated"
        static let userId = "currentUserId"
        static let username = "currentUsername"
        static let userRole = "currentUserRole"
        static let displayName = "currentUserDisplayName"
        static let loginDate = "currentLoginDate"
        static let loginMethod = "currentLoginMethod"
    }
    
    // MARK: - Initialization
    
    init(dataProvider: DataProviderServiceProtocol = DataProviderService()) {
        self.dataProvider = dataProvider
        setupSessionObservers()
        Task {
            await checkAuthenticationStatus()
        }
    }
    
    // MARK: - Private Setup
    
    private func setupSessionObservers() {
        // Monitor authentication state changes
        $isAuthenticated
            .sink { [weak self] authenticated in
                print("🔐 Authentication state changed: \(authenticated)")
                if !authenticated {
                    self?.clearCurrentUser()
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Password-Based Authentication
    
    /// Authenticate user with username and password
    func signIn(with credentials: LoginCredentials) async throws {
        print("🔐 Attempting password-based login for user: \(credentials.username)")
        
        // Clear any previous error
        authenticationError = nil
        
        // Validate credentials against hardcoded roles
        guard let userInfo = roleCredentials[credentials.username],
              userInfo.password == credentials.password else {
            let error = AuthenticationError.invalidCredentials
            await handleAuthenticationError(error)
            throw error
        }
        
        // Create user session
        let session = UserSession(
            id: UUID().uuidString,
            username: credentials.username,
            role: userInfo.role,
            displayName: userInfo.role.displayName,
            loginDate: Date(),
            loginMethod: .password
        )
        
        // Save session and update state
        await createUserSession(session)
        
        // Log successful authentication
        print("✅ Password authentication successful for \(credentials.username) with role \(userInfo.role.displayName)")
    }
    
    // MARK: - Apple ID Authentication (Legacy Support)
    
    func signInWithApple(request: ASAuthorizationAppleIDRequest, nonce: String?) async throws -> ASAuthorizationAppleIDCredential {
        // This maintains compatibility with existing Apple Sign In flow
        print("🍎 Apple Sign In requested - delegating to system")
        
        // For Apple Sign In, we need to handle this through the completion handler
        // This is maintained for protocol compatibility
        throw AuthenticationError.networkError
    }
    
    func handleSignInWithAppleCompletion(credential: ASAuthorizationAppleIDCredential, nonce: String?) async throws {
        print("🍎 Handling Apple Sign In completion")
        
        guard let appleUserID = credential.user.isEmpty ? nil : credential.user else {
            throw AuthenticationError.invalidCredentials
        }
        
        // Create or fetch user from database
        let userName = credential.fullName?.formatted() ?? "Apple User"
        let userEntity = try await dataProvider.fetchOrCreateUser(
            appleUserID: appleUserID,
            userName: userName,
            role: UserRole.client.rawValue // Default to client role for Apple Sign In
        )
        
        // Create session for Apple user
        let session = UserSession(
            id: appleUserID,
            username: userName,
            role: UserRole(rawValue: userEntity.role) ?? .client,
            displayName: userName,
            loginDate: Date(),
            loginMethod: .appleID
        )
        
        await createUserSession(session)
        print("✅ Apple Sign In successful for user: \(userName)")
    }
    
    // MARK: - Session Management
    
    func checkAuthenticationStatus() async {
        print("🔍 Checking authentication status...")
        
        // Check if we have a saved session
        guard userDefaults.bool(forKey: SessionKeys.isAuthenticated),
              let userId = userDefaults.string(forKey: SessionKeys.userId),
              let username = userDefaults.string(forKey: SessionKeys.username),
              let roleString = userDefaults.string(forKey: SessionKeys.userRole),
              let role = UserRole(rawValue: roleString),
              let displayName = userDefaults.string(forKey: SessionKeys.displayName),
              let loginDateData = userDefaults.object(forKey: SessionKeys.loginDate) as? Date,
              let loginMethodString = userDefaults.string(forKey: SessionKeys.loginMethod),
              let loginMethod = LoginMethod(rawValue: loginMethodString) else {
            print("❌ No valid saved session found")
            await signOut()
            return
        }
        
        // Recreate session
        let session = UserSession(
            id: userId,
            username: username,
            role: role,
            displayName: displayName,
            loginDate: loginDateData,
            loginMethod: loginMethod
        )
        
        // Check if session is still valid
        if session.isValid {
            currentUser = session
            isAuthenticated = true
            print("✅ Restored valid session for \(username) with role \(role.displayName)")
        } else {
            print("⏰ Session expired for \(username)")
            await signOut()
        }
    }
    
    func signOut() async {
        print("🚪 Signing out current user")
        
        // Clear session data
        userDefaults.removeObject(forKey: SessionKeys.isAuthenticated)
        userDefaults.removeObject(forKey: SessionKeys.userId)
        userDefaults.removeObject(forKey: SessionKeys.username)
        userDefaults.removeObject(forKey: SessionKeys.userRole)
        userDefaults.removeObject(forKey: SessionKeys.displayName)
        userDefaults.removeObject(forKey: SessionKeys.loginDate)
        userDefaults.removeObject(forKey: SessionKeys.loginMethod)
        
        // Update state
        currentUser = nil
        isAuthenticated = false
        authenticationError = nil
        
        print("✅ User signed out successfully")
    }
    
    func getCurrentAppleUserID() -> String? {
        guard let user = currentUser,
              user.loginMethod == .appleID else {
            return nil
        }
        return user.id
    }
    
    // MARK: - Permission Checking
    
    /// Check if current user has permission for a feature
    func hasPermission(for feature: FeaturePermission) -> Bool {
        guard let user = currentUser else {
            return false
        }
        
        return user.role.hasPermission(for: feature.requiredRole)
    }
    
    /// Require permission for a feature, throwing error if insufficient
    func requirePermission(for feature: FeaturePermission) throws {
        guard let user = currentUser else {
            throw AuthenticationError.sessionExpired
        }
        
        guard user.role.hasPermission(for: feature.requiredRole) else {
            throw AuthenticationError.insufficientPermissions(
                required: feature.requiredRole,
                current: user.role
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private func createUserSession(_ session: UserSession) async {
        // Save session to UserDefaults
        userDefaults.set(true, forKey: SessionKeys.isAuthenticated)
        userDefaults.set(session.id, forKey: SessionKeys.userId)
        userDefaults.set(session.username, forKey: SessionKeys.username)
        userDefaults.set(session.role.rawValue, forKey: SessionKeys.userRole)
        userDefaults.set(session.displayName, forKey: SessionKeys.displayName)
        userDefaults.set(session.loginDate, forKey: SessionKeys.loginDate)
        userDefaults.set(session.loginMethod.rawValue, forKey: SessionKeys.loginMethod)
        
        // Update current state
        currentUser = session
        isAuthenticated = true
        authenticationError = nil
        
        print("💾 Session saved for \(session.username)")
    }
    
    private func clearCurrentUser() {
        currentUser = nil
    }
    
    private func handleAuthenticationError(_ error: AuthenticationError) async {
        authenticationError = error
        print("❌ Authentication error: \(error.localizedDescription)")
    }
}

// MARK: - Helper Extensions

extension AuthenticationService {
    
    /// Get user-friendly role description
    var currentUserRoleDescription: String {
        currentUser?.role.description ?? "Not authenticated"
    }
    
    /// Check if current user is admin or higher
    var isAdminOrHigher: Bool {
        guard let user = currentUser else { return false }
        return user.role.hasPermission(for: .admin)
    }
    
    /// Check if current user is owner
    var isOwner: Bool {
        currentUser?.role == .owner
    }
    
    /// Get available features for current user
    var availableFeatures: [FeaturePermission] {
        guard let user = currentUser else { return [] }
        
        return FeaturePermission.allCases.filter { feature in
            user.role.hasPermission(for: feature.requiredRole)
        }
    }
}

// MARK: - FeaturePermission Extension for AllCases

extension FeaturePermission: CaseIterable {
    static let allCases: [FeaturePermission] = [
        .viewSongs, .playSongs, .managePlaylists, .importFiles,
        .deleteFiles, .viewSettings, .manageSettings, .viewAnalytics,
        .manageUsers, .systemAdmin, .developerTools
    ]
} 