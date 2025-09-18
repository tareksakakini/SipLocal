import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            ExploreView()
                .tabItem {
                    Label("Explore", systemImage: "magnifyingglass")
                }
                .tag(0)
            
            FavoritesView()
                .tabItem {
                    Label("Favorites", systemImage: "heart")
                }
                .tag(1)
            
            OrderView()
                .tabItem {
                    Label("Order", systemImage: "cup.and.saucer")
                }
                .tag(2)
            
            PassportView()
                .tabItem {
                    Label("Passport", systemImage: "book")
                }
                .tag(3)
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person")
                }
                .tag(4)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExploreTab"))) { _ in
            selectedTab = 0
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthenticationManager())
    }
} 