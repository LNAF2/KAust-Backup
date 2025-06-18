//
//  AccessControlService.swift
//  KAust
//
//  Created by Erling Breaden on 6/6/2025.
//

import SwiftUI
import Combine

// MARK: - Access Control Service Protocol

protocol AccessControlServiceProtocol {
    var currentUser: UserSession? { get }
    func hasPermission(for feature: FeaturePermission) -> Bool
    func requirePermission(for feature: FeaturePermission) throws
    func checkAccess(for feature: FeaturePermission) async throws
    func getAccessLevel(for feature: FeaturePermission) -> AccessLevel
}

// MARK: - Access Level Definition

enum AccessLevel {
    case granted
    case denied(reason: String)
    case conditionallyGranted(restrictions: [String])
    
    var isGranted: Bool {
        switch self {
        case .granted, .conditionallyGranted:
            return true
        case .denied:
            return false
        }
    }
    
    var message: String {
        switch self {
        case .granted:
            return "Access granted"
        case .denied(let reason):
            return reason
        case .conditionallyGranted(let restrictions):
            return "Access granted with restrictions: \(restrictions.joined(separator: ", "))"
        }
    }
}

// MARK: - Access Control Service Implementation

@MainActor
final class AccessControlService: ObservableObject, AccessControlServiceProtocol {
    
    @Published private(set) var accessLog: [AccessLogEntry] = []
    
    private let authService: AuthenticationService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(authService: AuthenticationService) {
        self.authService = authService
        setupObservers()
    }
    
    // MARK: - Protocol Implementation
    
    var currentUser: UserSession? {
        authService.currentUser
    }
    
    func hasPermission(for feature: FeaturePermission) -> Bool {
        guard let user = currentUser else {
            logAccess(feature: feature, granted: false, reason: "No authenticated user")
            return false
        }
        
        let hasAccess = user.role.hasPermission(for: feature.requiredRole)
        logAccess(feature: feature, granted: hasAccess, 
                 reason: hasAccess ? "Permission granted" : "Insufficient role permissions")
        
        return hasAccess
    }
    
    func requirePermission(for feature: FeaturePermission) throws {
        guard let user = currentUser else {
            logAccess(feature: feature, granted: false, reason: "Session expired")
            throw AuthenticationError.sessionExpired
        }
        
        guard user.role.hasPermission(for: feature.requiredRole) else {
            let error = AuthenticationError.insufficientPermissions(
                required: feature.requiredRole,
                current: user.role
            )
            logAccess(feature: feature, granted: false, reason: error.localizedDescription)
            throw error
        }
        
        logAccess(feature: feature, granted: true, reason: "Permission check passed")
    }
    
    func checkAccess(for feature: FeaturePermission) async throws {
        try requirePermission(for: feature)
    }
    
    func getAccessLevel(for feature: FeaturePermission) -> AccessLevel {
        guard let user = currentUser else {
            return .denied(reason: "Authentication required")
        }
        
        guard user.session.isValid else {
            return .denied(reason: "Session expired - please sign in again")
        }
        
        guard user.role.hasPermission(for: feature.requiredRole) else {
            return .denied(reason: "Requires \(feature.requiredRole.displayName) role or higher")
        }
        
        // Check for specific feature restrictions
        let restrictions = getFeatureRestrictions(feature: feature, userRole: user.role)
        
        if restrictions.isEmpty {
            return .granted
        } else {
            return .conditionallyGranted(restrictions: restrictions)
        }
    }
    
    // MARK: - Private Helpers
    
    private func setupObservers() {
        authService.$currentUser
            .sink { [weak self] user in
                if user == nil {
                    self?.clearAccessLog()
                }
            }
            .store(in: &cancellables)
    }
    
    private func logAccess(feature: FeaturePermission, granted: Bool, reason: String) {
        let entry = AccessLogEntry(
            feature: feature,
            userRole: currentUser?.role,
            granted: granted,
            reason: reason,
            timestamp: Date()
        )
        
        accessLog.append(entry)
        
        // Keep only last 100 entries to prevent memory issues
        if accessLog.count > 100 {
            accessLog.removeFirst(accessLog.count - 100)
        }
        
        print("🔐 ACCESS: \(feature) - \(granted ? "GRANTED" : "DENIED") - \(reason)")
    }
    
    private func clearAccessLog() {
        accessLog.removeAll()
    }
    
    private func getFeatureRestrictions(feature: FeaturePermission, userRole: UserRole) -> [String] {
        var restrictions: [String] = []
        
        // Add role-specific restrictions
        switch feature {
        case .deleteFiles:
            if userRole == .dev {
                restrictions.append("Limited to development files only")
            }
        case .manageSettings:
            if userRole == .admin {
                restrictions.append("Cannot modify owner-level settings")
            }
        case .importFiles:
            if userRole == .client {
                restrictions.append("File size limited to 50MB")
            }
        case .systemAdmin:
            if userRole == .admin {
                restrictions.append("Cannot access user management features")
            }
        default:
            break
        }
        
        return restrictions
    }
}

// MARK: - Access Log Entry

struct AccessLogEntry: Identifiable {
    let id = UUID()
    let feature: FeaturePermission
    let userRole: UserRole?
    let granted: Bool
    let reason: String
    let timestamp: Date
    
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter.string(from: timestamp)
    }
}

// MARK: - SwiftUI View Modifiers for Access Control

struct RequirePermission: ViewModifier {
    let feature: FeaturePermission
    let accessControl: AccessControlService
    let fallbackView: AnyView?
    
    init(feature: FeaturePermission, 
         accessControl: AccessControlService,
         fallback: (() -> AnyView)? = nil) {
        self.feature = feature
        self.accessControl = accessControl
        self.fallbackView = fallback?()
    }
    
    func body(content: Content) -> some View {
        Group {
            if accessControl.hasPermission(for: feature) {
                content
            } else if let fallback = fallbackView {
                fallback
            } else {
                AccessDeniedView(
                    feature: feature,
                    accessLevel: accessControl.getAccessLevel(for: feature)
                )
            }
        }
    }
}

// MARK: - Access Denied View

struct AccessDeniedView: View {
    let feature: FeaturePermission
    let accessLevel: AccessLevel
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.circle")
                .font(.system(size: 50))
                .foregroundColor(.red.opacity(0.7))
            
            Text("Access Denied")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(feature.description)
                .font(.headline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text(accessLevel.message)
                .font(.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if case .denied = accessLevel {
                Text("Contact your administrator to request access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.red.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.3), lineWidth: 1)
                )
        )
        .padding()
    }
}

// MARK: - View Extensions

extension View {
    func requirePermission(
        _ feature: FeaturePermission,
        accessControl: AccessControlService,
        fallback: (() -> AnyView)? = nil
    ) -> some View {
        modifier(RequirePermission(
            feature: feature,
            accessControl: accessControl,
            fallback: fallback
        ))
    }
    
    func requireRole(
        _ role: UserRole,
        authService: AuthenticationService,
        message: String = "Access denied"
    ) -> some View {
        Group {
            if let currentUser = authService.currentUser,
               currentUser.role.hasPermission(for: role) {
                self
            } else {
                VStack {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    
                    Text(message)
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

// MARK: - UserSession Extension

extension UserSession {
    var session: UserSession {
        return self
    }
} 