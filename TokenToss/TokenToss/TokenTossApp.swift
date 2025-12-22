//
//  TokenTossApp.swift
//  TokenToss
//
//  Created by Cole Doolittle on 12/22/25.
//

import SwiftUI

@main
struct TokenTossApp: App {
    @StateObject private var authVM = AuthViewModel()
    
    var body: some Scene {
        WindowGroup {
            // If logged in, show the main tabs. If not, show the Login screen.
            if authVM.isAuthenticated {
                MainTabView()
                    .environmentObject(authVM)
            } else {
                AuthView()
                    .environmentObject(authVM)
            }
        }
    }
}
