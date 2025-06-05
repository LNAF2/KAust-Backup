import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.isSignedIn) private var isSignedIn
    
    var body: some View {
        VStack {
            Spacer()
            
            Text("REAL K*ARAOKE")
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(AppTheme.leftPanelAccent)
            
            Spacer()
            
            SignInWithAppleButton(
                onRequest: { request in
                    request.requestedScopes = [.fullName, .email]
                },
                onCompletion: { result in
                    switch result {
                    case .success(_):
                        isSignedIn.wrappedValue = true
                    case .failure(let error):
                        print("Sign in failed: \(error.localizedDescription)")
                    }
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(width: 280, height: 50)
            .cornerRadius(8)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.appBackground)
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView()
            .environment(\.isSignedIn, .constant(false))
    }
} 