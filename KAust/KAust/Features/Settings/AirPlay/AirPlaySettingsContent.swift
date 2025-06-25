import SwiftUI
import AVKit

struct AirPlaySettingsContent: View {
    var body: some View {
        VStack(spacing: 8) {
            // AirPlay Button
            SettingRow(
                title: "Connect to Apple TV",
                icon: "airplay",
                accessoryType: .disclosure
            ) {
                // Show AirPlay menu
                let routePickerView = AVRoutePickerView()
                routePickerView.tintColor = .blue
                routePickerView.activeTintColor = .blue
                
                // Programmatically tap the AirPlay button
                if let airPlayButton = routePickerView.subviews.first(where: { $0 is UIButton }) as? UIButton {
                    airPlayButton.sendActions(for: .touchUpInside)
                }
            }
            
            // AirPlay Description
            SettingRow(
                title: "Stream to AirPlay devices",
                icon: "info.circle",
                accessoryType: .none
            )
        }
    }
}

#Preview {
    AirPlaySettingsContent()
        .padding()
        .background(AppTheme.settingsBackground)
} 