//
//  PerformanceOptimizationService.swift
//  KAust
//
//  Created by Modularization on 26/6/2025.
//

import Foundation
import Combine

// MARK: - Performance Optimization Protocol

/// Protocol defining performance optimization capabilities for ViewModels
@MainActor
protocol PerformanceOptimizationServiceProtocol: ObservableObject {
    // MARK: - Published Properties
    var isInPerformanceMode: Bool { get }
    var currentSearchDelayMs: Int { get }
    var areObserversSuspended: Bool { get }
    
    // MARK: - Search Delay Management
    func setScrollOptimizedSearchDelay()
    func restoreNormalSearchDelay()
    func getCurrentSearchDelay() -> Double
    
    // MARK: - Service Lifecycle
    func startObserving()
    func stopObserving()
}

// MARK: - Performance Optimization Service Implementation

/// Service responsible for managing performance optimizations during video playback and scroll operations
@MainActor
final class PerformanceOptimizationService: PerformanceOptimizationServiceProtocol {
    
    // MARK: - Published Properties
    @Published private(set) var isInPerformanceMode = false
    @Published private(set) var suspendedObservers = false
    
    // MARK: - Search Delay Properties
    private var currentSearchDelay: Double = 300.0 // Default 300ms
    private let normalSearchDelay: Double = 300.0
    private let scrollOptimizedDelay: Double = 100.0 // Reduced delay during scroll
    
    // MARK: - Observers
    private var observers: [NSObjectProtocol] = []
    
    // MARK: - Computed Properties
    var currentSearchDelayMs: Int {
        Int(currentSearchDelay)
    }
    
    // MARK: - Initialization
    
    init() {
        print("🎛️ PERFORMANCE: PerformanceOptimizationService initialized")
    }
    
    deinit {
        // Clean up observers on deinit (nonisolated)
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        print("🎛️ PERFORMANCE: PerformanceOptimizationService deinitialized")
    }
    
    // MARK: - Service Lifecycle
    
    func startObserving() {
        print("🎛️ PERFORMANCE: Starting performance optimization observers")
        setupPerformanceModeObserver()
        setupScrollOptimizationObservers()
    }
    
    func stopObserving() {
        print("🎛️ PERFORMANCE: Stopping performance optimization observers")
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
    }
    
    // MARK: - Search Delay Management
    
    func setScrollOptimizedSearchDelay() {
        print("⚡ SEARCH: Enabling scroll-optimized search (reduced debounce)")
        currentSearchDelay = scrollOptimizedDelay
    }
    
    func restoreNormalSearchDelay() {
        print("🔄 SEARCH: Restoring normal search delay")
        currentSearchDelay = normalSearchDelay
    }
    
    func getCurrentSearchDelay() -> Double {
        return currentSearchDelay
    }
    
    // MARK: - Performance Mode Observer Setup
    
    /// Setup performance mode observer to track video playback state
    private func setupPerformanceModeObserver() {
        // Video Performance Mode Enabled
        let performanceEnabledObserver = NotificationCenter.default.addObserver(
            forName: .init("VideoPerformanceModeEnabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🚀 PERFORMANCE: PerformanceOptimizationService entering performance mode")
            Task { @MainActor [weak self] in
                self?.isInPerformanceMode = true
            }
        }
        observers.append(performanceEnabledObserver)
        
        // Video Performance Mode Disabled
        let performanceDisabledObserver = NotificationCenter.default.addObserver(
            forName: .init("VideoPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 PERFORMANCE: PerformanceOptimizationService exiting performance mode")
            Task { @MainActor [weak self] in
                self?.isInPerformanceMode = false
            }
        }
        observers.append(performanceDisabledObserver)
        
        // ULTRA-PERFORMANCE: Additional observers for drag operations
        let ultraPerformanceEnabledObserver = NotificationCenter.default.addObserver(
            forName: .init("VideoUltraPerformanceModeEnabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🎯 ULTRA-PERFORMANCE: PerformanceOptimizationService entering ultra-performance mode")
            Task { @MainActor [weak self] in
                self?.isInPerformanceMode = true
            }
        }
        observers.append(ultraPerformanceEnabledObserver)
        
        let ultraPerformanceDisabledObserver = NotificationCenter.default.addObserver(
            forName: .init("VideoUltraPerformanceModeDisabled"),
            object: nil,
            queue: .main
        ) { _ in
            print("🎯 ULTRA-PERFORMANCE: PerformanceOptimizationService exiting ultra-performance mode")
            Task { @MainActor in
                // CRITICAL FIX: Don't exit performance mode immediately after ultra-performance ends
                // Video is likely still playing, so maintain performance mode until video stops
                print("🎯 ULTRA-PERFORMANCE: Maintaining performance mode - video likely still playing")
                // Keep performance mode active - let VideoPerformanceModeDisabled handle the final exit
            }
        }
        observers.append(ultraPerformanceDisabledObserver)
        
        // Core Data Observer Suspension
        let suspendObserver = NotificationCenter.default.addObserver(
            forName: .init("SuspendCoreDataObservers"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("⏸️ PERFORMANCE: PerformanceOptimizationService suspending observers for smooth video")
            Task { @MainActor [weak self] in
                self?.suspendedObservers = true
            }
        }
        observers.append(suspendObserver)
        
        let restoreObserver = NotificationCenter.default.addObserver(
            forName: .init("RestoreCoreDataObservers"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("▶️ PERFORMANCE: PerformanceOptimizationService restoring observers")
            Task { @MainActor [weak self] in
                self?.suspendedObservers = false
            }
        }
        observers.append(restoreObserver)
    }
    
    /// Setup scroll optimization observers to reduce operations during active scrolling
    private func setupScrollOptimizationObservers() {
        // Active Scrolling Started
        let scrollStartObserver = NotificationCenter.default.addObserver(
            forName: .init("ActiveScrollingStarted"),
            object: nil,
            queue: .main
        ) { _ in
            print("⚡ SCROLL: PerformanceOptimizationService reducing operations during active scrolling")
            // Notification sent - ViewModels can listen and respond accordingly
        }
        observers.append(scrollStartObserver)
        
        // Active Scrolling Stopped
        let scrollStopObserver = NotificationCenter.default.addObserver(
            forName: .init("ActiveScrollingStopped"),
            object: nil,
            queue: .main
        ) { _ in
            print("✅ SCROLL: PerformanceOptimizationService resuming normal operations after scrolling")
            // Notification sent - ViewModels can listen and respond accordingly
        }
        observers.append(scrollStopObserver)
        
        // Scroll Optimization Mode Enabled
        let scrollOptEnabledObserver = NotificationCenter.default.addObserver(
            forName: .init("ScrollOptimizationEnabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🚀 SCROLL: PerformanceOptimizationService entering scroll optimization mode")
            Task { @MainActor [weak self] in
                self?.setScrollOptimizedSearchDelay()
            }
        }
        observers.append(scrollOptEnabledObserver)
        
        // Scroll Optimization Mode Disabled
        let scrollOptDisabledObserver = NotificationCenter.default.addObserver(
            forName: .init("ScrollOptimizationDisabled"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            print("🔄 SCROLL: PerformanceOptimizationService exiting scroll optimization mode")
            Task { @MainActor [weak self] in
                self?.restoreNormalSearchDelay()
            }
        }
        observers.append(scrollOptDisabledObserver)
    }
}

// MARK: - Observer State Access

extension PerformanceOptimizationService {
    
    /// Check if observers are currently suspended
    var areObserversSuspended: Bool {
        suspendedObservers
    }
    
    /// Get current performance status for debugging
    var performanceStatus: String {
        return """
        Performance Mode: \(isInPerformanceMode ? "ACTIVE" : "INACTIVE")
        Observers Suspended: \(suspendedObservers ? "YES" : "NO")
        Search Delay: \(currentSearchDelayMs)ms
        """
    }
} 