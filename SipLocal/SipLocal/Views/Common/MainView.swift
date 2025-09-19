//
//  MainView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

/// Root navigation view that determines which flow to show based on authentication state
/// Navigation paths:
/// - Unauthenticated -> ContentView (login/signup)
/// - Authenticated but unverified -> EmailVerificationView
/// - Authenticated and verified -> HomeView (main app)
struct MainView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.isEmailVerified {
                    // Main app experience for verified users
                    HomeView()
                } else {
                    // Email verification flow for unverified users
                    EmailVerificationView()
                }
            } else {
                // Authentication flow for unauthenticated users
                ContentView()
            }
        }
        .onAppear {
            authManager.reloadUser { _ in }
        }
    }
}

// MARK: - Previews

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
            .environmentObject(AuthenticationManager())
    }
} 