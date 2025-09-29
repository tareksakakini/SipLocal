//
//  FavoritesView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Design Constants

private enum Design {
    // Empty State
    static let emptyIconSize: CGFloat = 60
    static let emptyStateSpacing: CGFloat = 16
    
    // Card Layout
    static let cardSpacing: CGFloat = 20
    static let cardImageHeight: CGFloat = 150
    static let cardCornerRadius: CGFloat = 10
    static let cardShadowRadius: CGFloat = 5
    static let cardPadding: CGFloat = 16
    static let cardInfoSpacing: CGFloat = 4
    
    // Colors
    static let emptyIconColor = Color(.systemGray4)
    static let cardBackgroundColor = Color(.systemBackground)
}

// MARK: - Favorites View

/// View displaying user's favorite coffee shops
/// Shows empty state when no favorites exist, otherwise displays cards in a scrollable list
struct FavoritesView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var favoriteShops: [CoffeeShop] = []
    
    private let allShops = CoffeeShopDataService.loadCoffeeShops()
    
    var body: some View {
        NavigationStack {
            contentView
                .navigationTitle("Favorites")
                .onAppear(perform: fetchFavoriteShops)
        }
    }
    
    // MARK: - View Components
    
    /// Main content view that shows either empty state or favorites list
    private var contentView: some View {
        Group {
            if favoriteShops.isEmpty {
                emptyStateView
            } else {
                favoritesListView
            }
        }
    }
    
    /// Empty state displayed when user has no favorite shops
    private var emptyStateView: some View {
        VStack(spacing: Design.emptyStateSpacing) {
            Image(systemName: "heart.slash.fill")
                .font(.system(size: Design.emptyIconSize))
                .foregroundColor(Design.emptyIconColor)
                .accessibilityHidden(true)
            
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No favorites yet. Tap the heart on a coffee shop to add it to your favorites.")
    }
    
    /// Scrollable list of favorite coffee shops
    private var favoritesListView: some View {
        ScrollView {
            LazyVStack(spacing: Design.cardSpacing) {
                ForEach(favoriteShops) { shop in
                    favoriteShopLink(for: shop)
                }
            }
            .padding()
        }
    }
    
    /// Navigation link wrapper for each favorite shop
    private func favoriteShopLink(for shop: CoffeeShop) -> some View {
        NavigationLink(destination: CoffeeShopDetailView(shop: shop, authManager: authManager)) {
            FavoriteShopCard(shop: shop)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("View details for \(shop.name)")
    }
    
    // MARK: - Actions
    
    /// Fetch and update the list of favorite shops based on user preferences
    private func fetchFavoriteShops() {
        favoriteShops = allShops.filter { shop in
            authManager.favoriteShops.contains(shop.id)
        }
    }
}

// MARK: - Favorite Shop Card

/// Card component displaying a favorite coffee shop with image and details
struct FavoriteShopCard: View {
    let shop: CoffeeShop
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            shopImage
            shopInfo
        }
        .background(Design.cardBackgroundColor)
        .cornerRadius(Design.cardCornerRadius)
        .shadow(radius: Design.cardShadowRadius)
    }
    
    // MARK: - Card Components
    
    /// Shop image with fallback for missing images
    private var shopImage: some View {
        // For Asset Catalog images, SwiftUI handles the loading automatically
        // We use the imageName directly as it corresponds to the .imageset name
        Image(shop.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(height: Design.cardImageHeight)
            .cornerRadius(Design.cardCornerRadius)
            .clipped()
            .accessibilityLabel("Photo of \(shop.name)")
    }
    
    /// Shop information section with name, address, and description
    private var shopInfo: some View {
        VStack(alignment: .leading, spacing: Design.cardInfoSpacing) {
            Text(shop.name)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            
            Text(shop.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(shop.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(Design.cardPadding)
    }
}

// MARK: - Previews

struct FavoritesView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Preview with favorites
            FavoritesView()
                .environmentObject({
                    let authManager = AuthenticationManager()
                    authManager.favoriteShops = ["1", "3"] // Mock favorites
                    return authManager
                }())
                .previewDisplayName("With Favorites")
            
            // Preview empty state
            FavoritesView()
                .environmentObject(AuthenticationManager())
                .previewDisplayName("Empty State")
        }
    }
} 