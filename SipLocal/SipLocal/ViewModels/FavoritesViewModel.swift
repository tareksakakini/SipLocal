/**
 * FavoritesViewModel.swift
 * SipLocal
 *
 * ViewModel for FavoritesView following MVVM architecture.
 * Handles favorites management, shop data loading, and user interactions.
 *
 * ## Responsibilities
 * - **Favorites Management**: Load and filter favorite coffee shops
 * - **Data Loading**: Fetch coffee shop data and sync with user preferences
 * - **State Management**: Handle loading states and empty state logic
 * - **User Interactions**: Navigate to shop details and manage favorites
 * - **Real-time Updates**: React to changes in user's favorite shops
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Data Filtering**: Efficient filtering and sorting of favorite shops
 * - **Empty State Management**: Handle empty favorites with user guidance
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine
import CoreLocation

// MARK: - FavoritesViewModel

/**
 * ViewModel for FavoritesView
 * 
 * Manages favorite coffee shops, data loading, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class FavoritesViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var favoriteShops: [CoffeeShop] = []
    @Published var allShops: [CoffeeShop] = []
    @Published var isLoadingShops: Bool = true
    @Published var isLoadingFavorites: Bool = false
    @Published var selectedShop: CoffeeShop?
    @Published var showShopDetail: Bool = false
    @Published var lastUpdated: Date = Date()
    
    // MARK: - Design Constants
    private enum Design {
        static let refreshCooldown: Double = 1.0
        static let animationDuration: Double = 0.3
        static let loadingDelay: Double = 0.1
        static let maxFavorites: Int = 50
    }
    
    // MARK: - Private State
    private var lastRefresh: Date = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Returns whether the user has any favorite shops
    var hasFavorites: Bool {
        !favoriteShops.isEmpty
    }
    
    /// Returns the number of favorite shops
    var favoritesCount: Int {
        favoriteShops.count
    }
    
    /// Returns favorite shops sorted by name
    var sortedFavoriteShops: [CoffeeShop] {
        favoriteShops.sorted { $0.name < $1.name }
    }
    
    /// Returns favorite shops sorted by recently added (if we had timestamps)
    var recentlyAddedFavorites: [CoffeeShop] {
        // For now, just return the regular sorted list
        // In a real app, we'd sort by the date they were favorited
        sortedFavoriteShops
    }
    
    /// Returns whether refresh is currently disabled due to cooldown
    var isRefreshDisabled: Bool {
        Date().timeIntervalSince(lastRefresh) < Design.refreshCooldown
    }
    
    /// Returns whether any operation is in progress
    var isOperationInProgress: Bool {
        isLoadingShops || isLoadingFavorites
    }
    
    /// Returns empty state message based on current state
    var emptyStateMessage: String {
        if isLoadingShops || isLoadingFavorites {
            return "Loading your favorites..."
        } else {
            return "No favorites yet"
        }
    }
    
    /// Returns empty state description
    var emptyStateDescription: String {
        if isLoadingShops || isLoadingFavorites {
            return "Please wait while we load your favorite coffee shops."
        } else {
            return "Start exploring coffee shops and add them to your favorites to see them here."
        }
    }
    
    /// Returns statistics about favorites
    var favoritesStatistics: (count: Int, percentage: Double) {
        let totalShops = allShops.count
        let favoriteCount = favoriteShops.count
        let percentage = totalShops > 0 ? Double(favoriteCount) / Double(totalShops) * 100 : 0.0
        return (count: favoriteCount, percentage: percentage)
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        setupFavoritesTracking()
        loadAllShops()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Load all coffee shops data
    func loadAllShops() {
        isLoadingShops = true
        
        // Simulate async loading (instant from local data)
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.loadingDelay) {
            self.allShops = CoffeeShopDataService.loadCoffeeShops()
            self.isLoadingShops = false
            self.fetchFavoriteShops()
            print("📍 Loaded \(self.allShops.count) coffee shops for favorites")
        }
    }
    
    /// Fetch and update favorite shops based on user preferences
    func fetchFavoriteShops() {
        guard !allShops.isEmpty else { return }
        
        isLoadingFavorites = true
        lastRefresh = Date()
        
        // Filter shops based on user's favorites
        let userFavoriteIds = Set(authManager.favoriteShops)
        let filteredShops = allShops.filter { shop in
            userFavoriteIds.contains(shop.id)
        }
        
        // Update with animation
        withAnimation(.easeInOut(duration: Design.animationDuration)) {
            favoriteShops = filteredShops
            isLoadingFavorites = false
            lastUpdated = Date()
        }
        
        print("❤️ Updated favorites: \(favoriteShops.count) shops")
    }
    
    /// Refresh favorites data
    func refreshFavorites() {
        guard !isRefreshDisabled else { return }
        fetchFavoriteShops()
    }
    
    /// Navigate to shop detail
    func navigateToShopDetail(_ shop: CoffeeShop) {
        selectedShop = shop
        showShopDetail = true
        print("🏪 Navigating to shop detail: \(shop.name)")
    }
    
    /// Remove a shop from favorites
    func removeFromFavorites(_ shop: CoffeeShop) {
        // This would typically call the auth manager to update favorites
        authManager.removeFavorite(shopId: shop.id) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.fetchFavoriteShops()
                    print("💔 Removed \(shop.name) from favorites")
                } else {
                    print("❌ Failed to remove \(shop.name) from favorites")
                }
            }
        }
    }
    
    /// Add a shop to favorites (for potential future use)
    func addToFavorites(_ shop: CoffeeShop) {
        guard favoriteShops.count < Design.maxFavorites else {
            print("⚠️ Maximum favorites limit reached")
            return
        }
        
        authManager.addFavorite(shopId: shop.id) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.fetchFavoriteShops()
                    print("❤️ Added \(shop.name) to favorites")
                } else {
                    print("❌ Failed to add \(shop.name) to favorites")
                }
            }
        }
    }
    
    /// Check if a shop is in favorites
    func isFavorite(_ shop: CoffeeShop) -> Bool {
        favoriteShops.contains { $0.id == shop.id }
    }
    
    /// Get shop by ID
    func getShop(by id: String) -> CoffeeShop? {
        allShops.first { $0.id == id }
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
        setupFavoritesTracking()
        fetchFavoriteShops()
    }
    
    /// Reset all states
    func resetState() {
        favoriteShops = []
        selectedShop = nil
        showShopDetail = false
        isLoadingShops = true
        isLoadingFavorites = false
        lastRefresh = Date.distantPast
    }
    
    // MARK: - Private Methods
    
    private func setupFavoritesTracking() {
        // In a real app, we might observe changes to the auth manager's favorites
        // For now, we'll rely on manual refresh calls
        print("🔄 Favorites tracking setup")
    }
}

// MARK: - Search and Filtering Extensions

extension FavoritesViewModel {
    
    /// Search favorites by name or address
    func searchFavorites(query: String) -> [CoffeeShop] {
        guard !query.isEmpty else { return favoriteShops }
        
        let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return favoriteShops.filter { shop in
            shop.name.lowercased().contains(searchQuery) ||
            shop.address.lowercased().contains(searchQuery)
        }
    }
    
    /// Group favorites by first letter of name
    var groupedFavorites: [String: [CoffeeShop]] {
        Dictionary(grouping: sortedFavoriteShops) { shop in
            String(shop.name.prefix(1).uppercased())
        }
    }
    
    /// Get favorites within a certain distance (if location data available)
    func favoritesNearby(coordinate: CLLocationCoordinate2D, radiusKm: Double) -> [CoffeeShop] {
        // This would calculate distance if we had location coordinates for shops
        // For now, return all favorites
        return favoriteShops
    }
}

// MARK: - Analytics Extensions

extension FavoritesViewModel {
    
    /// Get favorite shop categories (if available)
    var favoriteCategories: [String: Int] {
        // This would group by shop categories if we had that data
        // For now, return empty dictionary
        return [:]
    }
    
    /// Get most recently favorited shops (mock implementation)
    var recentFavorites: [CoffeeShop] {
        // In a real app, this would be sorted by favorite date
        return Array(favoriteShops.prefix(5))
    }
    
    /// Generate favorites summary for user
    var favoritesSummary: String {
        let stats = favoritesStatistics
        if stats.count == 0 {
            return "No favorites yet - start exploring!"
        } else if stats.count == 1 {
            return "You have 1 favorite coffee shop"
        } else {
            return "You have \(stats.count) favorite coffee shops (\(String(format: "%.1f", stats.percentage))% of all shops)"
        }
    }
}
