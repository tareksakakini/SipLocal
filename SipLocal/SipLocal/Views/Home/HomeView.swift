//
//  HomeView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Tab Configuration

/// Tab indices for the main app navigation
private enum TabIndex: Int, CaseIterable {
    case explore = 0
    case favorites = 1
    case order = 2
    case passport = 3
    case profile = 4
}

// MARK: - Home View

/// Main tab bar navigation for authenticated and verified users
/// Contains the primary app experience with five main sections
struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = TabIndex.explore.rawValue
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Explore Tab - Discover local coffee shops
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(TabIndex.explore.rawValue)
            
            // Favorites Tab - User's favorite coffee shops
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .tag(TabIndex.favorites.rawValue)
            
            // Order Tab - Place orders and view order history
            OrderView()
                .tabItem {
                    Label("Order", systemImage: "cup.and.saucer")
                }
                .tag(TabIndex.order.rawValue)
            
            // Passport Tab - Loyalty stamps and rewards
            PassportView()
                .tabItem {
                    Label("Passport", systemImage: "book")
                }
                .tag(TabIndex.passport.rawValue)
            
            // Profile Tab - User settings and account management
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(TabIndex.profile.rawValue)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExploreTab"))) { _ in
            // Handle deep link navigation to explore tab
            selectedTab = TabIndex.explore.rawValue
        }
    }
}

// MARK: - Previews

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationManager())
    }
} 