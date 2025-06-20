//
//  User.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import Foundation

// MARK: - User Role Definitions

/// User roles with hierarchical permissions
enum UserRole: String, CaseIterable, Comparable {
    case client = "client"
    case dev = "dev" 
    case admin = "admin"
    case owner = "owner"
    
    var displayName: String {
        switch self {
        case .client:
            return "Client"
        case .dev:
            return "Developer"
        case .admin:
            return "Administrator"
        case .owner:
            return "Owner"
        }
    }
    
    var description: String {
        switch self {
        case .client:
            return "Standard user access"
        case .dev:
            return "Developer access with debugging features"
        case .admin:
            return "Administrator access with system management"
        case .owner:
            return "Full owner access to all features"
        }
    }
    
    /// Hierarchy comparison for role-based permissions
    static func < (lhs: UserRole, rhs: UserRole) -> Bool {
        let hierarchy: [UserRole] = [.client, .dev, .admin, .owner]
        guard let lhsIndex = hierarchy.firstIndex(of: lhs),
              let rhsIndex = hierarchy.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
    
    /// Check if this role has permission for a feature requiring minimum role
    func hasPermission(for requiredRole: UserRole) -> Bool {
        return self >= requiredRole
    }
    
    // Settings access levels based on user specifications
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
        case .client: return false                       // Client: Only Airplay, Volume, App Info
        case .admin, .dev, .owner: return true          // Admin/Dev/Owner: Can see Admin settings
        }
    }
    
    var canAccessOwnerSettings: Bool {
        switch self {
        case .client, .admin: return false               // Client/Admin: Cannot see Owner settings
        case .dev, .owner: return true                   // Dev/Owner: Can see Owner settings
        }
    }
    
    var canAccessKioskModeSettings: Bool {
        switch self {
        case .client: return false                       // Client: Cannot see Kiosk Mode panel
        case .admin, .dev, .owner: return true          // Admin/Dev/Owner: Can see Kiosk Mode
        }
    }
    
    var canAccessProgrammerManagement: Bool {
        switch self {
        case .client, .admin, .owner: return false      // Client/Admin/Owner: Cannot see Programmer Management
        case .dev: return true                           // Only Developer: Can see Programmer Management
        }
    }
    
    var canAccessAllSettings: Bool {
        switch self {
        case .client, .admin: return false               // Client/Admin: Limited access
        case .dev, .owner: return true                   // Dev/Owner: Full access (but Owner excludes Programmer Management)
        }
    }
}

// MARK: - Authentication Models

/// Authentication credentials for password-based login
struct LoginCredentials {
    let username: String
    let password: String
    
    init(username: String, password: String) {
        self.username = username.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        self.password = password
    }
}

/// Current user session information
struct UserSession {
    let id: String
    let username: String
    let role: UserRole
    let displayName: String
    let loginDate: Date
    let loginMethod: LoginMethod
    
    var isValid: Bool {
        // Sessions expire after 24 hours for security
        return Date().timeIntervalSince(loginDate) < 86400
    }
}

/// Authentication method used for login
enum LoginMethod: String {
    case password = "password"
    case appleID = "apple_id"
    
    var displayName: String {
        switch self {
        case .password:
            return "Username & Password"
        case .appleID:
            return "Sign in with Apple"
        }
    }
}

// MARK: - Feature Permissions

/// Application features that require specific role permissions
enum FeaturePermission {
    case viewSongs
    case playSongs
    case managePlaylists
    case importFiles
    case deleteFiles
    case viewSettings
    case manageSettings
    case viewAnalytics
    case manageUsers
    case systemAdmin
    case developerTools
    
    var requiredRole: UserRole {
        switch self {
        case .viewSongs, .playSongs:
            return .client
        case .managePlaylists, .importFiles:
            return .client
        case .deleteFiles, .viewSettings:
            return .dev
        case .manageSettings, .viewAnalytics:
            return .admin
        case .manageUsers, .systemAdmin:
            return .admin
        case .developerTools:
            return .dev
        }
    }
    
    var description: String {
        switch self {
        case .viewSongs:
            return "View song library"
        case .playSongs:
            return "Play songs and manage queue"
        case .managePlaylists:
            return "Create and edit playlists"
        case .importFiles:
            return "Import new media files"
        case .deleteFiles:
            return "Delete songs and media"
        case .viewSettings:
            return "View application settings"
        case .manageSettings:
            return "Modify application settings"
        case .viewAnalytics:
            return "View usage analytics"
        case .manageUsers:
            return "Manage user accounts"
        case .systemAdmin:
            return "System administration"
        case .developerTools:
            return "Access developer debugging tools"
        }
    }
}

// MARK: - Authentication Errors

enum AuthenticationError: LocalizedError {
    case invalidCredentials
    case userNotFound
    case sessionExpired
    case insufficientPermissions(required: UserRole, current: UserRole)
    case accountLocked
    case networkError
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid username or password"
        case .userNotFound:
            return "User account not found"
        case .sessionExpired:
            return "Your session has expired. Please sign in again"
        case .insufficientPermissions(let required, let current):
            return "Access denied. Requires \(required.displayName) role, but you have \(current.displayName) role"
        case .accountLocked:
            return "Account is temporarily locked"
        case .networkError:
            return "Network connection error"
        case .unknownError:
            return "An unknown error occurred"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .invalidCredentials:
            return "Please check your username and password and try again"
        case .sessionExpired:
            return "Please sign in again to continue"
        case .insufficientPermissions:
            return "Contact an administrator to upgrade your access level"
        case .accountLocked:
            return "Wait a few minutes and try again, or contact support"
        case .networkError:
            return "Check your internet connection and try again"
        default:
            return "If the problem persists, contact support"
        }
    }
} 