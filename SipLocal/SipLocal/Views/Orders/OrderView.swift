//
//  OrderView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Design Constants

private enum Design {
    // Search Bar
    static let searchBarPadding: CGFloat = 12
    static let searchBarCornerRadius: CGFloat = 12
    static let searchBarTopSpacing: CGFloat = 8
    
    // Shop Cards
    static let cardSpacing: CGFloat = 16
    static let cardPadding: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    static let cardShadowRadius: CGFloat = 6
    static let cardShadowOffset: CGFloat = 2
    
    // Shop Images
    static let shopImageSize: CGFloat = 60
    static let shopImageCornerRadius: CGFloat = 12
    
    // Business Hours Badge
    static let badgePaddingHorizontal: CGFloat = 8
    static let badgePaddingVertical: CGFloat = 4
    static let badgeProgressScale: CGFloat = 0.6
    
    // Empty State
    static let emptyStateIconSize: CGFloat = 32
    static let emptyStateTopPadding: CGFloat = 40
    static let emptyStateSpacing: CGFloat = 12
    
    // Colors
    static let searchBarBackground = Color(.systemGray5)
    static let cardBackground = Color.white
    static let backgroundColor = Color(.systemGray6)
    static let shadowColor = Color.black.opacity(0.04)
    static let openBadgeColor = Color.green
    static let closedBadgeColor = Color.red
    static let emptyIconColor = Color.gray.opacity(0.5)
}

// MARK: - Order View

/// Main ordering interface displaying searchable list of coffee shops
/// Shows business hours status and navigates to menu selection
struct OrderView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @EnvironmentObject var cartManager: CartManager
    
    private let coffeeShops = CoffeeShopDataService.loadCoffeeShops()
    
    // MARK: - Computed Properties
    
    /// Filtered coffee shops based on search text
    var filteredShops: [CoffeeShop] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return coffeeShops }
        
        let lowercasedSearch = trimmedSearch.lowercased()
        return coffeeShops.filter { shop in
            shop.name.lowercased().contains(lowercasedSearch) ||
            shop.address.lowercased().contains(lowercasedSearch)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                Spacer().frame(height: Design.searchBarTopSpacing)
                shopsList
            }
            .background(Design.backgroundColor)
            .navigationTitle("Order")
        }
    }
    
    // MARK: - View Components
    
    /// Search bar for filtering coffee shops
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search by name or address", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .onTapGesture { isSearching = true }
                .accessibilityLabel("Search coffee shops")
            
            if isSearching && !searchText.isEmpty {
                clearSearchButton
            }
        }
        .padding(Design.searchBarPadding)
        .background(Design.searchBarBackground)
        .cornerRadius(Design.searchBarCornerRadius)
        .padding([.horizontal, .top])
    }
    
    /// Clear search button
    private var clearSearchButton: some View {
        Button(action: clearSearch) {
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Clear search")
    }
    
    /// Scrollable list of coffee shops
    private var shopsList: some View {
        ScrollView {
            LazyVStack(spacing: Design.cardSpacing) {
                ForEach(filteredShops) { shop in
                    shopCard(for: shop)
                }
                
                if filteredShops.isEmpty && !searchText.isEmpty {
                    emptySearchState
                }
            }
            .padding([.horizontal, .bottom])
        }
    }
    
    /// Individual coffee shop card
    private func shopCard(for shop: CoffeeShop) -> some View {
        NavigationLink(destination: MenuCategorySelectionView(shop: shop)) {
            HStack(spacing: Design.cardSpacing) {
                shopImage(for: shop)
                shopInfo(for: shop)
                Spacer()
                chevronIcon
            }
            .padding(Design.cardPadding)
            .background(Design.cardBackground)
            .cornerRadius(Design.cardCornerRadius)
            .shadow(
                color: Design.shadowColor,
                radius: Design.cardShadowRadius,
                x: 0,
                y: Design.cardShadowOffset
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Order from \(shop.name)")
        .onAppear {
            Task {
                await cartManager.fetchBusinessHours(for: shop)
            }
        }
    }
    
    /// Shop image thumbnail
    private func shopImage(for shop: CoffeeShop) -> some View {
        Image(shop.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Design.shopImageSize, height: Design.shopImageSize)
            .clipShape(RoundedRectangle(cornerRadius: Design.shopImageCornerRadius))
            .accessibilityLabel("Photo of \(shop.name)")
    }
    
    /// Shop information section
    private func shopInfo(for shop: CoffeeShop) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            shopHeader(for: shop)
            shopAddress(for: shop)
        }
    }
    
    /// Shop name and business hours header
    private func shopHeader(for shop: CoffeeShop) -> some View {
        HStack {
            Text(shop.name)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            
            Spacer()
            
            businessHoursBadge(for: shop)
        }
    }
    
    /// Shop address
    private func shopAddress(for shop: CoffeeShop) -> some View {
        Text(shop.address)
            .font(.subheadline)
            .foregroundColor(.secondary)
            .lineLimit(2)
    }
    
    /// Business hours status badge
    private func businessHoursBadge(for shop: CoffeeShop) -> some View {
        Group {
            if let isLoading = cartManager.isLoadingBusinessHours[shop.id], isLoading {
                ProgressView()
                    .scaleEffect(Design.badgeProgressScale)
                    .accessibilityLabel("Loading business hours")
            } else if let isOpen = cartManager.isShopOpen(shop: shop) {
                Text(isOpen ? "Open" : "Closed")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, Design.badgePaddingHorizontal)
                    .padding(.vertical, Design.badgePaddingVertical)
                    .background(
                        Capsule()
                            .fill(isOpen ? Design.openBadgeColor : Design.closedBadgeColor)
                    )
                    .accessibilityLabel(isOpen ? "Currently open" : "Currently closed")
            }
        }
    }
    
    /// Navigation chevron icon
    private var chevronIcon: some View {
        Image(systemName: "chevron.right")
            .foregroundColor(.secondary)
            .accessibilityHidden(true)
    }
    
    /// Empty search state
    private var emptySearchState: some View {
        VStack(spacing: Design.emptyStateSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: Design.emptyStateIconSize))
                .foregroundColor(Design.emptyIconColor)
                .accessibilityHidden(true)
            
            Text("No coffee shops found")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.top, Design.emptyStateTopPadding)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No coffee shops found for your search")
    }
    
    // MARK: - Actions
    
    /// Clear search text and dismiss keyboard
    private func clearSearch() {
        searchText = ""
        isSearching = false
        // Dismiss keyboard using SwiftUI's focused state management
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Previews

struct OrderView_Previews: PreviewProvider {
    static var previews: some View {
        OrderView()
            .environmentObject(CartManager())
    }
} 