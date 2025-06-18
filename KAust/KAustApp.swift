import SwiftUI

@main
struct KAustApp: App {
    @State private var isSignedIn = false
    
    var body: some Scene {
        WindowGroup {
            VStack {
                Text("🔍 DEBUG: KAustApp.swift is running")
                    .foregroundColor(.red)
                    .padding()
                Text("🔍 DEBUG: isSignedIn = \(isSignedIn)")
                    .foregroundColor(.red)
                    .padding()
            }
            .background(Color.yellow)
            .onAppear {
                print("🔍 DEBUG: KAustApp appeared - isSignedIn = \(isSignedIn)")
            }
            
            if isSignedIn {
                ContentView()
                    .onAppear {
                        print("🔍 DEBUG: ContentView appeared because isSignedIn = true")
                    }
            } else {
                // Temporary simple login screen for debugging
                VStack(spacing: 20) {
                    Text("KAUST LOGIN REQUIRED")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Debugging: isSignedIn = \(isSignedIn)")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Button("Sign In") {
                        isSignedIn = true
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.gray.opacity(0.1))
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