import SwiftUI

@main
struct KAustApp: App {
    @State private var isSignedIn = false
    
    var body: some Scene {
        WindowGroup {
            if isSignedIn {
                MainView()
            } else {
                SignInView()
                    .environment(\.isSignedIn, $isSignedIn)
            }
        }
    }
}

private struct IsSignedInKey: EnvironmentKey {
    static let defaultValue: Binding<Bool> = .constant(false)
}

extension EnvironmentValues {
    var isSignedIn: Binding<Bool> {
        get { self[IsSignedInKey.self] }
        set { self[IsSignedInKey.self] = newValue }
    }
} 