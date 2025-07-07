//
//  MainView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

struct MainView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                if authManager.isEmailVerified {
                    HomeView()
                        .environmentObject(authManager)
                } else {
                    EmailVerificationView()
                        .environmentObject(authManager)
                }
            } else {
                ContentView()
                    .environmentObject(authManager)
            }
        }
        .onAppear {
            authManager.reloadUser { _ in }
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 