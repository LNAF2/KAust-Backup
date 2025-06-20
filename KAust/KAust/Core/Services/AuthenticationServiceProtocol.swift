//
//  AuthenticationServiceProtocol.swift
//  KAust
//
//  Created by Erling Breaden on 2/6/2025.
//

import Foundation
import AuthenticationServices // For ASAuthorizationAppleIDCredential

// Protocol for handling authentication operations
protocol AuthenticationServiceProtocol {
    // Published property to observe authentication state
    var isAuthenticatedPublisher: Published<Bool>.Publisher { get }
    var isAuthenticated: Bool { get }
    var currentUser: UserSession? { get }

    // Function to initiate Sign in with Apple
    // The completion handler will receive the result of the authorization
    func signInWithApple(request: ASAuthorizationAppleIDRequest, nonce: String?) async throws -> ASAuthorizationAppleIDCredential

    // Function to handle the result of a successful Sign in with Apple authorization
    // This would typically involve validating the token and storing user identifiers
    func handleSignInWithAppleCompletion(credential: ASAuthorizationAppleIDCredential, nonce: String?) async throws

    // Function to check current authentication status (e.g., on app launch)
    func checkAuthenticationStatus() async

    // Function to sign out the current user
    func signOut() async
    
    // Function to get the current Apple User ID if authenticated
    func getCurrentAppleUserID() -> String?
}
