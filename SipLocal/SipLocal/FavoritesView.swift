import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var favoriteShops: [CoffeeShop] = []
    
    private let allShops = DataService.loadCoffeeShops()
    
    var body: some View {
        NavigationStack {
            Group {
                if favoriteShops.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "heart.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Color(.systemGray4))
                        
                        Text("No Favorites Yet")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Tap the heart on a coffee shop to add it to your favorites.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 20) {
                            ForEach(favoriteShops) { shop in
                                NavigationLink(destination: CoffeeShopDetailView(shop: shop, authManager: authManager)) {
                                    FavoriteShopCard(shop: shop)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Favorites")
            .onAppear(perform: fetchFavoriteShops)
        }
    }
    
    private func fetchFavoriteShops() {
        self.favoriteShops = allShops.filter { shop in
            authManager.favoriteShops.contains(shop.id)
        }
    }
}

struct FavoriteShopCard: View {
    let shop: CoffeeShop
    
    var body: some View {
        VStack(alignment: .leading) {
            Image(shop.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 150)
                .cornerRadius(10)
                .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(shop.name)
                    .font(.headline)
                
                Text(shop.address)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text(shop.description)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(2)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        let authManager = AuthenticationManager()
        // Manually set some favorites for preview
        authManager.favoriteShops = ["1", "3"]
        
        return FavoritesView()
            .environmentObject(authManager)
    }
} 