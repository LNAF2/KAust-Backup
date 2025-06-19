import SwiftUI

/// Toast notification view for displaying temporary success/failure messages
struct ToastNotificationView: View {
    let notification: ToastNotification
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    @State private var dragOffset: CGFloat = 0
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: notification.iconName)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(notification.iconColor)
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(notification.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppTheme.settingsText)
                
                if let message = notification.message {
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(AppTheme.settingsText.opacity(0.8))
                        .lineLimit(2)
                }
            }
            
            Spacer()
            
            // Action button (if provided)
            if let action = notification.action {
                Button(action.title) {
                    action.handler()
                    onDismiss()
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            // Dismiss button
            Button {
                dismissWithAnimation()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(AppTheme.settingsText.opacity(0.5))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(notification.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(notification.borderColor, lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        .offset(y: isVisible ? 0 : -100)
        .offset(y: dragOffset)
        .opacity(isVisible ? 1 : 0)
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.y < 0 {
                        dragOffset = value.translation.y
                    }
                }
                .onEnded { value in
                    if value.translation.y < -50 {
                        dismissWithAnimation()
                    } else {
                        withAnimation(.spring(response: 0.3)) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isVisible = true
            }
            
            // Auto-dismiss after duration
            if notification.duration > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + notification.duration) {
                    dismissWithAnimation()
                }
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3)) {
            isVisible = false
            dragOffset = -100
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Toast Notification Model

struct ToastNotification: Identifiable {
    let id = UUID()
    let type: ToastType
    let title: String
    let message: String?
    let duration: TimeInterval
    let action: ToastAction?
    
    var iconName: String {
        switch type {
        case .success:
            return "checkmark.circle.fill"
        case .error:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .info:
            return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .success:
            return .green
        case .error:
            return .red
        case .warning:
            return .orange
        case .info:
            return .blue
        }
    }
    
    var backgroundColor: Color {
        switch type {
        case .success:
            return AppTheme.settingsBackground.opacity(0.95)
        case .error:
            return AppTheme.settingsBackground.opacity(0.95)
        case .warning:
            return AppTheme.settingsBackground.opacity(0.95)
        case .info:
            return AppTheme.settingsBackground.opacity(0.95)
        }
    }
    
    var borderColor: Color {
        switch type {
        case .success:
            return Color.green.opacity(0.3)
        case .error:
            return Color.red.opacity(0.3)
        case .warning:
            return Color.orange.opacity(0.3)
        case .info:
            return Color.blue.opacity(0.3)
        }
    }
    
    init(
        type: ToastType,
        title: String,
        message: String? = nil,
        duration: TimeInterval = 4.0,
        action: ToastAction? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.duration = duration
        self.action = action
    }
}

enum ToastType {
    case success
    case error
    case warning
    case info
}

struct ToastAction {
    let title: String
    let handler: () -> Void
}

// MARK: - Toast Manager

@MainActor
class ToastManager: ObservableObject {
    @Published var notifications: [ToastNotification] = []
    
    func show(_ notification: ToastNotification) {
        notifications.append(notification)
    }
    
    func dismiss(_ notification: ToastNotification) {
        notifications.removeAll { $0.id == notification.id }
    }
    
    func dismissAll() {
        notifications.removeAll()
    }
}

// MARK: - Convenience Methods

extension ToastManager {
    func showSuccess(
        title: String,
        message: String? = nil,
        duration: TimeInterval = 3.0,
        action: ToastAction? = nil
    ) {
        let notification = ToastNotification(
            type: .success,
            title: title,
            message: message,
            duration: duration,
            action: action
        )
        show(notification)
    }
    
    func showError(
        title: String,
        message: String? = nil,
        duration: TimeInterval = 5.0,
        action: ToastAction? = nil
    ) {
        let notification = ToastNotification(
            type: .error,
            title: title,
            message: message,
            duration: duration,
            action: action
        )
        show(notification)
    }
    
    func showWarning(
        title: String,
        message: String? = nil,
        duration: TimeInterval = 4.0,
        action: ToastAction? = nil
    ) {
        let notification = ToastNotification(
            type: .warning,
            title: title,
            message: message,
            duration: duration,
            action: action
        )
        show(notification)
    }
    
    func showInfo(
        title: String,
        message: String? = nil,
        duration: TimeInterval = 4.0,
        action: ToastAction? = nil
    ) {
        let notification = ToastNotification(
            type: .info,
            title: title,
            message: message,
            duration: duration,
            action: action
        )
        show(notification)
    }
    
    func showFileProcessingSuccess(fileName: String) {
        showSuccess(
            title: "File Processed Successfully",
            message: "'\(fileName)' has been imported and is ready to use.",
            duration: 3.0
        )
    }
    
    func showBatchProcessingComplete(fileCount: Int) {
        showSuccess(
            title: "Import Complete",
            message: "Successfully imported \(fileCount) MP4 file\(fileCount == 1 ? "" : "s").",
            duration: 4.0
        )
    }
    
    func showFileProcessingError(fileName: String, error: Error) {
        let retryAction = ToastAction(title: "Retry") {
            // Retry logic would be handled by the caller
        }
        
        showError(
            title: "Failed to Process File",
            message: "Could not import '\(fileName)': \(error.localizedDescription)",
            duration: 6.0,
            action: retryAction
        )
    }
}

// MARK: - Toast Container View

struct ToastContainerView<Content: View>: View {
    @StateObject private var toastManager = ToastManager()
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            content
                .environmentObject(toastManager)
            
            // Toast notifications overlay
            VStack {
                ForEach(toastManager.notifications) { notification in
                    ToastNotificationView(
                        notification: notification,
                        onDismiss: {
                            toastManager.dismiss(notification)
                        }
                    )
                    .padding(.horizontal, 16)
                    .transition(.asymmetric(
                        insertion: .move(edge: .top).combined(with: .opacity),
                        removal: .move(edge: .top).combined(with: .opacity)
                    ))
                }
                
                Spacer()
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: toastManager.notifications.count)
        }
    }
}

// MARK: - Preview

struct ToastNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Success notification
            ToastNotificationView(
                notification: ToastNotification(
                    type: .success,
                    title: "File Imported Successfully",
                    message: "'Ed Sheeran - Azizam - ck.mp4' has been processed.",
                    duration: 0 // Don't auto-dismiss in preview
                ),
                onDismiss: {}
            )
            .previewDisplayName("Success")
            
            // Error notification with action
            ToastNotificationView(
                notification: ToastNotification(
                    type: .error,
                    title: "Import Failed",
                    message: "File size exceeds the 200MB limit.",
                    duration: 0,
                    action: ToastAction(title: "Select Different File") {}
                ),
                onDismiss: {}
            )
            .previewDisplayName("Error with Action")
            
            // Warning notification
            ToastNotificationView(
                notification: ToastNotification(
                    type: .warning,
                    title: "Processing Slow",
                    message: "Large file detected. This may take a while.",
                    duration: 0
                ),
                onDismiss: {}
            )
            .previewDisplayName("Warning")
        }
        .padding()
        .background(Color.gray.opacity(0.2))
    }
} 