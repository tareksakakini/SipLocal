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
        if authManager.isAuthenticated {
            // This would be your main app content view
            HomeView()
                .environmentObject(authManager)
        } else {
            ContentView()
                .environmentObject(authManager)
        }
    }
}

// Placeholder for the main content view after login
struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack {
            Text("Welcome!")
                .font(.largeTitle)
            Button("Sign Out", action: {
                authManager.signOut()
            })
            .padding()
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
} 