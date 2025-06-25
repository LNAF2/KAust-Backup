import SwiftUI
import AVKit

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var roleManager: UserRoleManager
    @EnvironmentObject var userPreferencesService: UserPreferencesService
    @StateObject private var viewModel: SettingsViewModel
    let kioskModeService: KioskModeService
    @State private var showingClearSongsAlert = false
    
    init(kioskModeService: KioskModeService) {
        self.kioskModeService = kioskModeService
        // Initialize with a temporary service that will be replaced in onAppear
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(userPreferencesService: UserPreferencesService()))
    }
    
    var body: some View {
        let bgColor = AppTheme.settingsBackground
        
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                headerView
                    .padding(.horizontal, 32)
                
                HStack {
                    Spacer()
                    Text("SETTINGS")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 32)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Volume Control Section
                        SettingsSection(title: "Volume Control", icon: "speaker.wave.2") {
                            VStack(spacing: 8) {
                                // Volume Slider
                                HStack {
                                    Button(action: {
                                        viewModel.toggleMute()
                                    }) {
                                        Image(systemName: viewModel.volumeIconName)
                                            .foregroundColor(.blue)
                                            .font(.system(size: 20))
                                    }
                                    
                                    Slider(value: Binding(
                                        get: { viewModel.masterVolume },
                                        set: { viewModel.setMasterVolume($0) }
                                    ))
                                    .accentColor(.blue)
                                    
                                    Text("\(viewModel.volumePercentage)%")
                                        .foregroundColor(.gray)
                                        .font(.system(size: 14))
                                }
                            }
                        }
                        
                        // AirPlay Section (Available to all roles)
                        if roleManager.currentRole.canAccessAirplaySettings {
                            SettingsSection(title: "AirPlay", icon: "airplay") {
                                AirPlaySettingsContent()
                            }
                        }
                        
                        // Kiosk Mode Section (Admin, Dev, Owner)
                        if roleManager.currentRole.canAccessKioskModeSettings {
                            SettingsSection(title: "Kiosk Mode", icon: "lock.shield") {
                                VStack(spacing: 8) {
                                    KioskModeSettingsContent(kioskModeService: kioskModeService)
                                }
                            }
                        }
                        
                        // App Info Section
                        SettingsSection(title: "App Info", icon: "info.circle") {
                            VStack(spacing: 8) {
                                SettingRow(
                                    title: "Version",
                                    icon: "info.circle",
                                    accessoryType: .value(viewModel.appVersion)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            
            SettingsAlertViews(showingClearSongsAlert: $showingClearSongsAlert)
        }
        .onAppear {
            // Update ViewModel with the injected userPreferencesService
            viewModel.updateUserPreferencesService(userPreferencesService)
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("RESET") {
                Task {
                    viewModel.resetSettings()
                }
            }
            .font(.headline)
            .foregroundColor(.blue)
            
            Spacer()
            
            DoneButton {
                presentationMode.wrappedValue.dismiss()
            }
        }
        .padding(.top, 20)
        .padding(.bottom, 8)
    }
}

struct SettingsAlertViews: View {
    @Binding var showingClearSongsAlert: Bool
    @EnvironmentObject var viewModel: SettingsViewModel
    
    var body: some View {
        EmptyView()
            .alert(
                "Clear All Songs",
                isPresented: $showingClearSongsAlert
            ) {
                Button("Cancel", role: .cancel) {
                    showingClearSongsAlert = false
                }
                Button("Clear", role: .destructive) {
                    Task {
                        await viewModel.clearAllCoreDataSongs()
                    }
                }
            } message: {
                Text("This will permanently delete all songs from the database. This action cannot be undone.")
            }
    }
}

// MARK: - Settings Components

struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content
    
    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 28)
                
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

// MARK: - Preview Provider

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        let authService = AuthenticationService()
        let kioskModeService = KioskModeService(authService: authService)
        
        SettingsView(kioskModeService: kioskModeService)
            .environmentObject(UserRoleManager(role: .admin))
    }
} 