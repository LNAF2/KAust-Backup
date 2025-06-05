import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            TitlePanelView()
            
            // Placeholder for other panels
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 