import SwiftUI

// MARK: - Settings Section
/// A section container for grouping related settings items
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    init(
        title: String,
        icon: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .foregroundColor(.blue)
                        .font(.system(size: 16, weight: .medium))
                }
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.settingsText)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            
            // Section content
            content
        }
        .background(
            RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                .fill(AppTheme.settingsBackground.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                        .stroke(AppTheme.settingsText.opacity(0.2), lineWidth: 1)
                )
        )
    }
}

// MARK: - Setting Row
/// A row item for individual settings
struct SettingRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    let action: (() -> Void)?
    let accessoryType: AccessoryType
    
    enum AccessoryType {
        case none
        case disclosure
        case toggle(Binding<Bool>)
        case value(String)
        case custom(AnyView)
    }
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String,
        iconColor: Color = .blue,
        accessoryType: AccessoryType = .disclosure,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.accessoryType = accessoryType
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(AppTheme.settingsText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                // Accessory
                accessoryView
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(AppTheme.settingsText.opacity(0.05))
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(action == nil && !isInteractiveAccessory)
    }
    
    @ViewBuilder
    private var accessoryView: some View {
        switch accessoryType {
        case .none:
            EmptyView()
            
        case .disclosure:
            Image(systemName: "chevron.right")
                .foregroundColor(AppTheme.settingsText.opacity(0.5))
                .font(.system(size: 12, weight: .medium))
            
        case .toggle(let binding):
            Toggle("", isOn: binding)
                .toggleStyle(SwitchToggleStyle(tint: .blue))
            
        case .value(let value):
            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppTheme.settingsText.opacity(0.7))
            
        case .custom(let view):
            view
        }
    }
    
    private var isInteractiveAccessory: Bool {
        switch accessoryType {
        case .toggle(_):
            return true
        default:
            return false
        }
    }
}

// MARK: - File Picker Row
/// A specialized row for triggering file picker actions
struct FilePickerRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let isEnabled: Bool
    let isLoading: Bool
    let action: () -> Void
    
    init(
        title: String,
        subtitle: String? = nil,
        icon: String = "folder.badge.plus",
        isEnabled: Bool = true,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon with loading state
                ZStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: icon)
                            .foregroundColor(isEnabled ? .blue : AppTheme.settingsText.opacity(0.5))
                            .font(.system(size: 20, weight: .medium))
                    }
                }
                .frame(width: 28)
                
                // Text content
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isEnabled ? AppTheme.settingsText : AppTheme.settingsText.opacity(0.5))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.system(size: 14))
                            .foregroundColor(AppTheme.settingsText.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                
                Spacer()
                
                // Action indicator
                if !isLoading {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(isEnabled ? .green : AppTheme.settingsText.opacity(0.3))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                    .fill(isEnabled ? Color.blue.opacity(0.1) : AppTheme.settingsText.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppConstants.Layout.panelCornerRadius)
                            .stroke(isEnabled ? Color.blue.opacity(0.3) : AppTheme.settingsText.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

// MARK: - Settings Divider
/// A subtle divider for separating settings groups
struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppTheme.settingsText.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }
}

// MARK: - Preview

struct SettingsComponents_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 20) {
                SettingsSection(title: "File Management", icon: "folder") {
                    VStack(spacing: 8) {
                        FilePickerRow(
                            title: "Download MP4 Files",
                            subtitle: "Select MP4 files to download and process",
                            isEnabled: true,
                            isLoading: false
                        ) {
                            // Action
                        }
                        
                        SettingRow(
                            title: "Manage Downloads",
                            subtitle: "View and manage downloaded files",
                            icon: "doc.text.magnifyingglass",
                            accessoryType: .disclosure
                        ) {
                            // Action
                        }
                    }
                }
                
                SettingsSection(title: "Preferences", icon: "gearshape") {
                    VStack(spacing: 8) {
                        SettingRow(
                            title: "Notifications",
                            icon: "bell",
                            accessoryType: .toggle(.constant(true))
                        )
                        
                        SettingRow(
                            title: "App Version",
                            icon: "info.circle",
                            accessoryType: .value("1.0.0")
                        )
                    }
                }
            }
            .padding()
        }
        .background(AppTheme.settingsBackground)
        .preferredColorScheme(.dark)
    }
} 