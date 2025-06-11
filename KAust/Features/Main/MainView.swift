import SwiftUI

struct MainView: View {
    var body: some View {
        VStack(spacing: AppConstants.Layout.defaultSpacing) {
            TitlePanelView()
            
            // Song List Display
            SongListDisplayView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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