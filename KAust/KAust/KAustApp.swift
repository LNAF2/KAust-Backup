//
//  KAustApp.swift
//  KAust
//
//  Created by Erling Breaden on 30/5/2025.
//

import SwiftUI

@main
struct KAustApp: App {
    // Create an instance of our PersistenceController
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            // Your main view (e.g., ContentView or a more specific router view)
            // ContentView()
            // For now, let's assume ContentView is your starting point.
            // We will likely replace ContentView with a proper MainViewRouter later.
           
            ContentView()
                  .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
