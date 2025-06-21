//
//  KioskModeService.swift
//  KAust
//
//  Created by Erling Breaden on 19/6/2025.
//

import Foundation
import SwiftUI
import Security
import Combine

// MARK: - Kiosk Mode Service Protocol

@preconcurrency protocol KioskModeServiceProtocol {
    var isKioskModeActive: Bool { get }
    var isKioskModeActivePublisher: Published<Bool>.Publisher { get }
    
    func isPINSet() -> Bool
    func createPIN(_ pin: String) async throws
    func verifyPIN(_ pin: String) async throws -> Bool
    func changePIN(current: String, new: String) async throws
    func activateKioskMode() async throws
    func deactivateKioskMode(with pin: String) async throws
}

// MARK: - Kiosk Mode Errors

enum KioskModeError: LocalizedError {
    case pinTooShort
    case pinTooLong
    case invalidPIN
    case pinNotSet
    case pinAlreadySet
    case keychainError(String)
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .pinTooShort:
            return "PIN must be at least 4 digits"
        case .pinTooLong:
            return "PIN must be no more than 6 digits"
        case .invalidPIN:
            return "Incorrect PIN entered"
        case .pinNotSet:
            return "No PIN has been set for Kiosk Mode"
        case .pinAlreadySet:
            return "Kiosk Mode PIN is already configured"
        case .keychainError(let message):
            return "Keychain error: \(message)"
        case .authenticationRequired:
            return "Admin, Developer, or Owner access required to manage Kiosk Mode"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .pinTooShort, .pinTooLong:
            return "Please enter a PIN between 4-6 digits"
        case .invalidPIN:
            return "Please try entering the PIN again"
        case .pinNotSet:
            return "Set up a PIN first to use Kiosk Mode"
        case .pinAlreadySet:
            return "Use 'Change PIN' option to modify the existing PIN"
        case .keychainError:
            return "Try restarting the app or contact support"
        case .authenticationRequired:
            return "Sign in with Administrator, Developer, or Owner privileges"
        }
    }
}

// MARK: - Kiosk Mode Service Implementation

@MainActor
final class KioskModeService: ObservableObject, @preconcurrency KioskModeServiceProtocol {
    
    // MARK: - Published Properties
    
    @Published private(set) var isKioskModeActive: Bool = false
    
    var isKioskModeActivePublisher: Published<Bool>.Publisher {
        $isKioskModeActive
    }
    
    // MARK: - Private Properties
    
    private let authService: AuthenticationServiceProtocol
    private let userDefaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()
    
    // Keychain configuration
    private let kioskPINKey = "KAust.KioskMode.PIN"
    private let kioskModeActiveKey = "KAust.KioskMode.Active"
    
    // MARK: - Initialization
    
    init(authService: AuthenticationServiceProtocol) {
        self.authService = authService
        loadKioskModeState()
        setupObservers()
        
        // Set up default PIN if none exists
        Task {
            await setupDefaultPINIfNeeded()
        }
    }
    
    // MARK: - Private Setup
    
    private func loadKioskModeState() {
        isKioskModeActive = userDefaults.bool(forKey: kioskModeActiveKey)
        print("🔒 Loaded Kiosk Mode state: \(isKioskModeActive)")
    }
    
    private func setupObservers() {
        // Reset Kiosk Mode if user signs out
        authService.isAuthenticatedPublisher
            .sink { [weak self] isAuthenticated in
                if !isAuthenticated {
                    Task { @MainActor [weak self] in
                        self?.forceDeactivateKioskMode()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private nonisolated func setupDefaultPINIfNeeded() async {
        // Only set up default PIN if no PIN exists
        if getPINFromKeychain() == nil {
            do {
                let defaultPIN = "123456"
                try storePINInKeychain(defaultPIN)
                print("✅ Default Kiosk Mode PIN (123456) set up automatically")
            } catch {
                print("⚠️ Failed to set up default Kiosk Mode PIN: \(error)")
            }
        }
    }
    
    // MARK: - Public Methods
    
    nonisolated func isPINSet() -> Bool {
        return getPINFromKeychain() != nil
    }
    
    func createPIN(_ pin: String) async throws {
        try validatePINFormat(pin)
        
        // Check if PIN is already set
        if isPINSet() {
            throw KioskModeError.pinAlreadySet
        }
        
        // Require admin/owner privileges
        try requireAdminAccess()
        
        // Store PIN securely in Keychain
        try storePINInKeychain(pin)
        
        print("✅ Kiosk Mode PIN created successfully")
    }
    
    func verifyPIN(_ pin: String) async throws -> Bool {
        guard let storedPIN = getPINFromKeychain() else {
            throw KioskModeError.pinNotSet
        }
        
        return pin == storedPIN
    }
    
    func changePIN(current: String, new: String) async throws {
        // Verify current PIN first
        guard try await verifyPIN(current) else {
            throw KioskModeError.invalidPIN
        }
        
        // Validate new PIN format
        try validatePINFormat(new)
        
        // Require admin/owner privileges
        try requireAdminAccess()
        
        // Store new PIN
        try storePINInKeychain(new)
        
        print("✅ Kiosk Mode PIN changed successfully")
    }
    
    func activateKioskMode() async throws {
        // Require admin/owner privileges
        try requireAdminAccess()
        
        // Ensure PIN is set
        guard isPINSet() else {
            throw KioskModeError.pinNotSet
        }
        
        // Activate Kiosk Mode
        isKioskModeActive = true
        userDefaults.set(true, forKey: kioskModeActiveKey)
        
        print("🔒 Kiosk Mode activated")
    }
    
    func deactivateKioskMode(with pin: String) async throws {
        // Verify PIN
        guard try await verifyPIN(pin) else {
            throw KioskModeError.invalidPIN
        }
        
        // Deactivate Kiosk Mode
        isKioskModeActive = false
        userDefaults.set(false, forKey: kioskModeActiveKey)
        
        print("🔓 Kiosk Mode deactivated")
    }
    
    // MARK: - Private Helpers
    
    private func requireAdminAccess() throws {
        guard let currentUser = authService.currentUser else {
            throw KioskModeError.authenticationRequired
        }
        
        guard currentUser.role == UserRole.admin || currentUser.role == UserRole.dev || currentUser.role == UserRole.owner else {
            throw KioskModeError.authenticationRequired
        }
    }
    
    private func validatePINFormat(_ pin: String) throws {
        // Remove any non-numeric characters
        let numericPIN = pin.filter { $0.isNumber }
        
        guard numericPIN.count >= 4 else {
            throw KioskModeError.pinTooShort
        }
        
        guard numericPIN.count <= 6 else {
            throw KioskModeError.pinTooLong
        }
    }
    
    private func forceDeactivateKioskMode() {
        isKioskModeActive = false
        userDefaults.set(false, forKey: kioskModeActiveKey)
        print("🔓 Kiosk Mode force deactivated due to sign out")
    }
    
    // MARK: - Keychain Operations
    
    private nonisolated func storePINInKeychain(_ pin: String) throws {
        let pinData = pin.data(using: .utf8)!
        
        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kioskPINKey
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        
        // Add new item
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kioskPINKey,
            kSecValueData as String: pinData,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        
        if status != errSecSuccess {
            throw KioskModeError.keychainError("Failed to store PIN (status: \(status))")
        }
    }
    
    private nonisolated func getPINFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: kioskPINKey,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let pinData = result as? Data,
              let pin = String(data: pinData, encoding: .utf8) else {
            return nil
        }
        
        return pin
    }
} 