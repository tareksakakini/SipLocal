/**
 * CartManager.swift
 * SipLocal
 *
 * Refactored CartManager following Single Responsibility Principle.
 * Acts as a coordinator for specialized cart services.
 *
 * ## Responsibilities
 * - **Cart Coordination**: Manage cart items and operations
 * - **Service Integration**: Coordinate BusinessHoursService and CartValidationService
 * - **State Management**: Maintain cart state and synchronization
 * - **API Compatibility**: Preserve existing CartManager interface
 *
 * ## Architecture
 * - **Coordinator Pattern**: Manages specialized service classes
 * - **Single Responsibility**: Each service handles one concern
 * - **Observable**: Reactive state management with @Published properties
 * - **Performance**: Optimized service coordination and caching
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Combine

// MARK: - CartItem

struct CartItem: Identifiable, Codable {
    let id: UUID
    let shop: CoffeeShop
    let menuItem: MenuItem
    // Persist the Square item identifier to reliably match current menu
    let menuItemId: String
    let category: String
    var quantity: Int
    var customizations: String?
    let itemPriceWithModifiers: Double
    // Detailed selections to enable re-ordering with preloaded customizations
    var selectedSizeId: String?
    // Mapping of modifierListId -> selected modifier ids
    var selectedModifierIdsByList: [String: [String]]?
    
    init(
        shop: CoffeeShop,
        menuItem: MenuItem,
        category: String,
        quantity: Int,
        customizations: String? = nil,
        itemPriceWithModifiers: Double? = nil,
        selectedSizeId: String? = nil,
        selectedModifierIdsByList: [String: [String]]? = nil
    ) {
        self.id = UUID()
        self.shop = shop
        self.menuItem = menuItem
        self.menuItemId = menuItem.id
        self.category = category
        self.quantity = quantity
        self.customizations = customizations
        self.itemPriceWithModifiers = itemPriceWithModifiers ?? menuItem.price
        self.selectedSizeId = selectedSizeId
        self.selectedModifierIdsByList = selectedModifierIdsByList
    }
    
    var totalPrice: Double {
        return itemPriceWithModifiers * Double(quantity)
    }
}

// MARK: - CartManager

/**
 * CartManager - Coordinator for cart services
 * 
 * Manages cart state and coordinates specialized services
 * for business hours and validation operations.
 */
class CartManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var items: [CartItem] = []
    
    // Service state forwarding for backward compatibility
    @Published var shopBusinessHours: [String: BusinessHoursInfo] = [:]
    @Published var isLoadingBusinessHours: [String: Bool] = [:]
    
    // MARK: - Services
    
    private let businessHoursService = BusinessHoursService()
    private let validationService = CartValidationService()
    
    // MARK: - Computed Properties
    
    var totalPrice: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
    
    // MARK: - Initialization
    
    init() {
        print("🛒 CartManager initialized")
        setupServiceObservers()
    }
    
    deinit {
        print("🛒 CartManager deinitialized")
    }
    
    // MARK: - Service Coordination
    
    /**
     * Setup observers for service state changes
     */
    private func setupServiceObservers() {
        // Forward business hours state from service
        Task {
            while true {
                await MainActor.run {
                    self.shopBusinessHours = self.businessHoursService.getAllBusinessHours()
                    self.isLoadingBusinessHours = self.businessHoursService.getAllLoadingStates()
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
    }
    
    // MARK: - Business Hours Operations
    
    /**
     * Check if a shop is currently open
     */
    func isShopOpen(shop: CoffeeShop) -> Bool? {
        return businessHoursService.isShopOpen(shop: shop)
    }
    
    /**
     * Fetch business hours for a shop
     */
    func fetchBusinessHours(for shop: CoffeeShop) async {
        _ = await businessHoursService.fetchBusinessHours(for: shop)
    }
    
    // MARK: - Cart Operations
    
    /**
     * Add item to cart
     */
    func addItem(
        shop: CoffeeShop,
        menuItem: MenuItem,
        category: String,
        customizations: String? = nil,
        itemPriceWithModifiers: Double? = nil,
        selectedSizeId: String? = nil,
        selectedModifierIdsByList: [String: [String]]? = nil
    ) -> Bool {
        let priceWithModifiers = itemPriceWithModifiers ?? menuItem.price
        
        // Validate if item can be added
        let validationResult = validationService.canAddItem(
            shop: shop,
            menuItem: menuItem,
            existingItems: items,
            isShopOpen: isShopOpen(shop: shop)
        )
        
        switch validationResult {
        case .failure:
            return false
        case .success:
            break
        }
        
        // Check for existing matching item
        if let existingIndex = validationService.findMatchingItem(
            shop: shop,
            menuItem: menuItem,
            customizations: customizations,
            itemPriceWithModifiers: priceWithModifiers,
            selectedSizeId: selectedSizeId,
            selectedModifierIdsByList: selectedModifierIdsByList,
            existingItems: items
        ) {
            items[existingIndex].quantity += 1
        } else {
            let newItem = CartItem(
                shop: shop,
                menuItem: menuItem,
                category: category,
                quantity: 1,
                customizations: customizations,
                itemPriceWithModifiers: priceWithModifiers,
                selectedSizeId: selectedSizeId,
                selectedModifierIdsByList: selectedModifierIdsByList
            )
            items.append(newItem)
        }
        return true
    }
    
    /**
     * Remove item from cart
     */
    func removeItem(cartItem: CartItem) {
        items.removeAll { $0.id == cartItem.id }
    }
    
    /**
     * Update item quantity
     */
    func updateQuantity(cartItem: CartItem, quantity: Int) {
        // Validate quantity
        let validationResult = validationService.validateQuantityUpdate(quantity: quantity)
        
        switch validationResult {
        case .failure:
            return // Invalid quantity, don't update
        case .success:
            break
        }
        
        if let index = items.firstIndex(where: { $0.id == cartItem.id }) {
            if quantity <= 0 {
                items.remove(at: index)
            } else {
                items[index].quantity = quantity
            }
        }
    }
    
    /**
     * Clear cart
     */
    func clearCart() {
        items.removeAll()
    }
    
    /**
     * Clear business hours cache
     */
    func clearBusinessHoursCache() {
        businessHoursService.clearCache()
    }
    
    /**
     * Get cart summary
     */
    func getCartSummary() -> CartSummary {
        return validationService.getCartSummary(items: items)
    }
    
    /**
     * Validate cart state
     */
    func validateCartState() -> ValidationResult {
        return validationService.validateCartState(items: items)
    }
}

// MARK: - Design System

extension CartManager {
    
    /**
     * Design system constants for CartManager
     */
    enum Design {
        // Service names
        static let businessHoursServiceName = "BusinessHoursService"
        static let validationServiceName = "CartValidationService"
        
        // Logging
        static let cartManagerInitialized = "🛒 CartManager initialized"
        static let cartManagerDeinitialized = "🛒 CartManager deinitialized"
        
        // State management
        static let stateUpdateInterval: UInt64 = 100_000_000 // 0.1 seconds
    }
}