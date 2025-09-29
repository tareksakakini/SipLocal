/**
 * MenuViewModel.swift
 * SipLocal
 *
 * ViewModel for MenuView managing menu data loading, state management,
 * and business logic for menu display and navigation.
 *
 * ## Features
 * - **Menu Data Management**: Handles menu loading, caching, and refresh
 * - **State Management**: Loading, error, and success states
 * - **Error Handling**: Comprehensive error management with retry logic
 * - **Performance**: Optimized data loading with background refresh
 * - **Navigation**: Handles menu item selection and category navigation
 *
 * ## Architecture
 * - **MVVM Pattern**: Separates business logic from UI
 * - **Reactive State**: Uses @Published properties for UI updates
 * - **Service Integration**: Works with MenuDataManager for data operations
 * - **Error Boundaries**: Structured error handling for all operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import SwiftUI

/**
 * ViewModel for MenuView
 * 
 * Manages menu data loading, state management, and business logic
 * for menu display and navigation operations.
 */
class MenuViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var menuCategories: [MenuCategory] = []
    @Published var isRefreshing = false
    
    // MARK: - Private Properties
    
    private let shop: CoffeeShop
    
    // MARK: - Initialization
    
    /**
     * Initialize with coffee shop
     */
    init(shop: CoffeeShop) {
        self.shop = shop
        print("📋 MenuViewModel initialized for shop: \(shop.name)")
    }
    
    deinit {
        print("📋 MenuViewModel deinitialized for shop: \(shop.name)")
    }
    
    // MARK: - Public Methods
    
    /**
     * Load menu data for the shop
     */
    func loadMenuData() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        await MenuDataManager.shared.primeMenu(for: shop)
        
        await MainActor.run {
            updateMenuState()
            isLoading = false
        }
    }
    
    /**
     * Refresh menu data
     */
    func refreshMenuData() async {
        await MainActor.run {
            isRefreshing = true
            errorMessage = nil
        }
        
        await MenuDataManager.shared.refreshMenuData(for: shop)
        
        await MainActor.run {
            updateMenuState()
            isRefreshing = false
        }
    }
    
    /**
     * Retry loading menu data
     */
    func retryLoading() async {
        await refreshMenuData()
    }
    
    /**
     * Navigate to menu category
     */
    func navigateToCategory(_ category: MenuCategory) {
        // Navigation logic can be implemented here
        print("📋 Navigating to category: \(category.name)")
    }
    
    /**
     * Navigate to menu item
     */
    func navigateToMenuItem(_ item: MenuItem, in category: MenuCategory) {
        // Navigation logic can be implemented here
        print("📋 Navigating to item: \(item.name) in category: \(category.name)")
    }
    
    // MARK: - Computed Properties
    
    /**
     * Check if menu is empty
     */
    var isMenuEmpty: Bool {
        return menuCategories.isEmpty
    }
    
    /**
     * Get total number of menu items
     */
    var totalMenuItems: Int {
        return menuCategories.reduce(0) { $0 + $1.items.count }
    }
    
    /**
     * Get menu summary
     */
    var menuSummary: String {
        if isMenuEmpty {
            return "No menu items available"
        } else {
            return "\(menuCategories.count) categories, \(totalMenuItems) items"
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Update menu state from MenuDataManager
     */
    @MainActor
    private func updateMenuState() {
        menuCategories = MenuDataManager.shared.getMenuCategories(for: shop)
        
        if let error = MenuDataManager.shared.getErrorMessage(for: shop) {
            errorMessage = error
        }
    }
}

// MARK: - Design System

extension MenuViewModel {
    
    /**
     * Design system constants for MenuViewModel
     */
    enum Design {
        // Loading states
        static let loadingMessage = "Loading menu..."
        static let refreshingMessage = "Refreshing menu..."
        
        // Error messages
        static let loadErrorTitle = "Unable to load menu"
        static let refreshErrorTitle = "Unable to refresh menu"
        static let retryButtonTitle = "Try Again"
        
        // Navigation
        static let backButtonTitle = "Back"
        static let menuTitle = "Menu"
        
        // Empty state
        static let emptyMenuTitle = "No menu items available"
        static let emptyMenuMessage = "Menu items will appear here when available"
        
        // Logging
        static let viewModelInitialized = "📋 MenuViewModel initialized for shop:"
        static let viewModelDeinitialized = "📋 MenuViewModel deinitialized for shop:"
        static let navigatingToCategory = "📋 Navigating to category:"
        static let navigatingToItem = "📋 Navigating to item:"
    }
}
