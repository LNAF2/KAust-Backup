// MARK: - NotificationService Protocol

/// Protocol for managing app notifications in a centralized, type-safe manner
protocol NotificationServiceProtocol {
    // MARK: - Observer Management
    func addObserver<T: AnyObject>(
        _ observer: T,
        selector: @escaping (T) -> () -> Void,
        for notificationName: AppNotification
    )
    
    func addObserver<T: AnyObject>(
        _ observer: T,
        handler: @escaping (T, Notification) -> Void,
        for notificationName: AppNotification
    )
    
    func removeObserver<T: AnyObject>(_ observer: T)
    func removeObserver<T: AnyObject>(_ observer: T, for notificationName: AppNotification)
    
    // MARK: - Publisher-based Observers (Combine)
    func publisher(for notificationName: AppNotification) -> NotificationCenter.Publisher
    func debouncedPublisher(for notificationName: AppNotification, delay: TimeInterval) -> AnyPublisher<Notification, Never>
    
    // MARK: - Posting Notifications
    func post(_ notification: AppNotification, object: Any?)
    func post(_ notification: AppNotification)
    
    // MARK: - Lifecycle Management
    func suspendObservers()
    func restoreObservers()
    var areObserversSuspended: Bool { get }
    
    // MARK: - Convenience Methods
    func addCoreDataObserver<T: AnyObject>(
        _ observer: T,
        onSuspend: @escaping (T) -> Void,
        onRestore: @escaping (T) -> Void
    )
    
    func addScrollOptimizationObserver<T: AnyObject>(
        _ observer: T,
        onScrollStart: @escaping (T) -> Void,
        onScrollStop: @escaping (T) -> Void
    )
    
    func addPerformanceModeObserver<T: AnyObject>(
        _ observer: T,
        onEnabled: @escaping (T) -> Void,
        onDisabled: @escaping (T) -> Void
    )
}

// MARK: - App Notification Types

/// Strongly-typed notification names for the app
enum AppNotification: String, CaseIterable {
    // MARK: - Performance Notifications
    case videoPerformanceModeEnabled = "VideoPerformanceModeEnabled"
    case videoPerformanceModeDisabled = "VideoPerformanceModeDisabled"
    case videoUltraPerformanceModeEnabled = "VideoUltraPerformanceModeEnabled"
    case videoUltraPerformanceModeDisabled = "VideoUltraPerformanceModeDisabled"
    
    case suspendCoreDataObservers = "SuspendCoreDataObservers"
    case restoreCoreDataObservers = "RestoreCoreDataObservers"
    
    // MARK: - Scroll Optimization Notifications
    case activeScrollingStarted = "ActiveScrollingStarted"
    case activeScrollingStopped = "ActiveScrollingStopped"
    case scrollOptimizationEnabled = "ScrollOptimizationEnabled"
    case scrollOptimizationDisabled = "ScrollOptimizationDisabled"
    
    // MARK: - Video Player Notifications
    case blockProgressBar = "BlockProgressBar"
    case allowProgressBar = "AllowProgressBar"
    case blockVideoDrag = "BlockVideoDrag"
    case allowVideoDrag = "AllowVideoDrag"
    case centerVideoPlayer = "centerVideoPlayer"
    
    // MARK: - App Feature Notifications
    case deleteSongFromPlaylist = "deleteSongFromPlaylist"
    case playbackFailed = "playbackFailed"
    case requestFolderPicker = "requestFolderPicker"
    case playNextSongFromPlaylist = "playNextSongFromPlaylist"
    case applyAppVolume = "ApplyAppVolume"
    
    // MARK: - System Notifications
    case appWillResignActive = "UIApplicationWillResignActiveNotification"
    case appDidEnterBackground = "UIApplicationDidEnterBackgroundNotification"
    case appWillEnterForeground = "UIApplicationWillEnterForegroundNotification"
    case appDidBecomeActive = "UIApplicationDidBecomeActiveNotification"
    case appWillTerminate = "UIApplicationWillTerminateNotification"
    
    case managedObjectContextDidSave = "NSManagedObjectContextDidSaveNotification"
    
    /// Convert to Notification.Name
    var notificationName: Notification.Name {
        switch self {
        case .appWillResignActive:
            return UIApplication.willResignActiveNotification
        case .appDidEnterBackground:
            return UIApplication.didEnterBackgroundNotification
        case .appWillEnterForeground:
            return UIApplication.willEnterForegroundNotification
        case .appDidBecomeActive:
            return UIApplication.didBecomeActiveNotification
        case .appWillTerminate:
            return UIApplication.willTerminateNotification
        case .managedObjectContextDidSave:
            return .NSManagedObjectContextDidSave
        default:
            return Notification.Name(rawValue)
        }
    }
}

// MARK: - NotificationService Implementation

import Foundation
import Combine
import UIKit
import CoreData

final class NotificationService: NotificationServiceProtocol {
    
    // MARK: - Properties
    private var observers: [NSObjectProtocol] = []
    private var suspendedObservers: [NSObjectProtocol] = []
    private(set) var areObserversSuspended = false
    
    // MARK: - Initialization
    
    init() {
        print("📡 NOTIFICATION: NotificationService initialized")
    }
    
    deinit {
        // Clean up all observers
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        suspendedObservers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        suspendedObservers.removeAll()
        print("📡 NOTIFICATION: NotificationService deinitialized")
    }
    
    // MARK: - Observer Management
    
    func addObserver<T: AnyObject>(
        _ observer: T,
        selector: @escaping (T) -> () -> Void,
        for notificationName: AppNotification
    ) {
        let nsObserver = NotificationCenter.default.addObserver(
            forName: notificationName.notificationName,
            object: nil,
            queue: .main
        ) { [weak observer] _ in
            guard let observer = observer else { return }
            selector(observer)()
        }
        
        observers.append(nsObserver)
        print("📡 NOTIFICATION: Added observer for \(notificationName.rawValue)")
    }
    
    func addObserver<T: AnyObject>(
        _ observer: T,
        handler: @escaping (T, Notification) -> Void,
        for notificationName: AppNotification
    ) {
        let nsObserver = NotificationCenter.default.addObserver(
            forName: notificationName.notificationName,
            object: nil,
            queue: .main
        ) { [weak observer] notification in
            guard let observer = observer else { return }
            handler(observer, notification)
        }
        
        observers.append(nsObserver)
        print("📡 NOTIFICATION: Added observer with handler for \(notificationName.rawValue)")
    }
    
    func removeObserver<T: AnyObject>(_ observer: T) {
        // Note: This implementation removes all observers
        // In a more sophisticated version, we could track observers by object
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.removeAll()
        print("📡 NOTIFICATION: Removed all observers")
    }
    
    func removeObserver<T: AnyObject>(_ observer: T, for notificationName: AppNotification) {
        // Note: This is a simplified implementation
        // A more sophisticated version would track individual observers
        print("📡 NOTIFICATION: Remove specific observer not implemented - use removeObserver(_:)")
    }
    
    // MARK: - Publisher-based Observers
    
    func publisher(for notificationName: AppNotification) -> NotificationCenter.Publisher {
        return NotificationCenter.default.publisher(for: notificationName.notificationName)
    }
    
    func debouncedPublisher(for notificationName: AppNotification, delay: TimeInterval) -> AnyPublisher<Notification, Never> {
        return NotificationCenter.default.publisher(for: notificationName.notificationName)
            .debounce(for: .milliseconds(Int(delay * 1000)), scheduler: RunLoop.main)
            .eraseToAnyPublisher()
    }
    
    // MARK: - Posting Notifications
    
    func post(_ notification: AppNotification, object: Any? = nil) {
        NotificationCenter.default.post(
            name: notification.notificationName,
            object: object
        )
        print("📡 NOTIFICATION: Posted \(notification.rawValue)")
    }
    
    func post(_ notification: AppNotification) {
        post(notification, object: nil)
    }
    
    // MARK: - Lifecycle Management
    
    func suspendObservers() {
        guard !areObserversSuspended else {
            print("📡 NOTIFICATION: Observers already suspended")
            return
        }
        
        print("⏸️ NOTIFICATION: Suspending observers")
        
        // Move active observers to suspended list
        suspendedObservers.append(contentsOf: observers)
        observers.removeAll()
        areObserversSuspended = true
        
        // Don't actually remove the observers from NotificationCenter
        // Just mark them as suspended for tracking
    }
    
    func restoreObservers() {
        guard areObserversSuspended else {
            print("📡 NOTIFICATION: Observers not suspended")
            return
        }
        
        print("▶️ NOTIFICATION: Restoring observers")
        
        // Move suspended observers back to active list
        observers.append(contentsOf: suspendedObservers)
        suspendedObservers.removeAll()
        areObserversSuspended = false
    }
}

// MARK: - Convenience Extensions

extension NotificationService {
    
    /// Add observer for performance mode changes
    func addPerformanceModeObserver<T: AnyObject>(
        _ observer: T,
        onEnabled: @escaping (T) -> Void,
        onDisabled: @escaping (T) -> Void
    ) {
        addObserver(observer, selector: { observer in { onEnabled(observer) } }, for: .videoPerformanceModeEnabled)
        addObserver(observer, selector: { observer in { onDisabled(observer) } }, for: .videoPerformanceModeDisabled)
    }
    
    /// Add observer for Core Data suspension/restoration
    func addCoreDataObserver<T: AnyObject>(
        _ observer: T,
        onSuspend: @escaping (T) -> Void,
        onRestore: @escaping (T) -> Void
    ) {
        addObserver(observer, selector: { observer in { onSuspend(observer) } }, for: .suspendCoreDataObservers)
        addObserver(observer, selector: { observer in { onRestore(observer) } }, for: .restoreCoreDataObservers)
    }
    
    /// Add observer for scroll optimization
    func addScrollOptimizationObserver<T: AnyObject>(
        _ observer: T,
        onScrollStart: @escaping (T) -> Void,
        onScrollStop: @escaping (T) -> Void
    ) {
        addObserver(observer, selector: { observer in { onScrollStart(observer) } }, for: .activeScrollingStarted)
        addObserver(observer, selector: { observer in { onScrollStop(observer) } }, for: .activeScrollingStopped)
    }
} 