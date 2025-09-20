/**
 * RefactoredCartManager.swift
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

// MARK: - RefactoredCartManager

/**
 * Refactored Cart Manager
 * 
 * Coordinates cart operations and specialized services while maintaining
 * backward compatibility with the existing CartManager interface.
 */
class RefactoredCartManager: ObservableObject {
    
    // MARK: - Published State Properties
    @Published var items: [CartItem] = []
    
    // Service state forwarding for backward compatibility
    @Published var shopBusinessHours: [String: BusinessHoursInfo] = [:]
    @Published var isLoadingBusinessHours: [String: Bool] = [:]
    
    // MARK: - Service Dependencies
    private let businessHoursService: BusinessHoursService
    private let validationService: CartValidationService
    
    // MARK: - Configuration
    private enum Configuration {
        static let autoSaveEnabled: Bool = true
        static let maxUndoSteps: Int = 10
        static let cartSyncInterval: TimeInterval = 30.0
    }
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    private var cartHistory: [CartSnapshot] = []
    private var lastSyncTime: Date = Date()
    
    // MARK: - Computed Properties
    
    /**
     * Total price of all items in cart
     */
    var totalPrice: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    /**
     * Total number of items in cart (sum of quantities)
     */
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
    
    /**
     * Total number of unique items in cart
     */
    var totalItemsInCart: Int {
        return items.count
    }
    
    /**
     * Check if cart is empty
     */
    var isEmpty: Bool {
        return items.isEmpty
    }
    
    /**
     * Get the shop ID for current cart (if any)
     */
    var currentShopId: String? {
        return items.first?.shop.id
    }
    
    /**
     * Get the current shop (if any)
     */
    var currentShop: CoffeeShop? {
        return items.first?.shop
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize services
        self.businessHoursService = BusinessHoursService()
        self.validationService = CartValidationService(businessHoursService: businessHoursService)
        
        // Setup service state forwarding
        setupServiceStateForwarding()
        
        // Setup cart monitoring
        setupCartMonitoring()
        
        print("🛒 RefactoredCartManager initialized")
    }
    
    deinit {
        cancellables.removeAll()
        print("🛒 RefactoredCartManager deinitialized")
    }
    
    // MARK: - Cart Operations
    
    /**
     * Add item to cart with validation
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
        
        let finalPrice = itemPriceWithModifiers ?? menuItem.price
        
        // Validate the addition
        let validationResult = validationService.validateAddItem(
            to: items,
            shop: shop,
            menuItem: menuItem,
            quantity: 1,
            customizations: customizations,
            itemPriceWithModifiers: finalPrice
        )
        
        guard validationResult.isValid else {
            print("🛒 Add item validation failed: \(validationResult.errorMessage ?? "Unknown error")")
            return false
        }
        
        // Create cart snapshot for undo functionality
        if Configuration.autoSaveEnabled {
            saveCartSnapshot()
        }
        
        // Check if item already exists with same customizations
        if let existingIndex = findExistingItemIndex(
            shop: shop,
            menuItem: menuItem,
            customizations: customizations,
            itemPriceWithModifiers: finalPrice,
            selectedSizeId: selectedSizeId,
            selectedModifierIdsByList: selectedModifierIdsByList
        ) {
            // Update existing item quantity
            items[existingIndex].quantity += 1
        } else {
            // Add new item
            let newItem = CartItem(
                shop: shop,
                menuItem: menuItem,
                category: category,
                quantity: 1,
                customizations: customizations,
                itemPriceWithModifiers: finalPrice,
                selectedSizeId: selectedSizeId,
                selectedModifierIdsByList: selectedModifierIdsByList
            )
            items.append(newItem)
        }
        
        print("🛒 Added item: \(menuItem.name) to cart ✅")
        return true
    }
    
    /**
     * Remove item from cart
     */
    func removeItem(cartItem: CartItem) {
        if Configuration.autoSaveEnabled {
            saveCartSnapshot()
        }
        
        items.removeAll { $0.id == cartItem.id }
        print("🛒 Removed item from cart ✅")
    }
    
    /**
     * Update item quantity with validation
     */
    func updateQuantity(cartItem: CartItem, quantity: Int) {
        let validationResult = validationService.validateUpdateQuantity(
            cartItem: cartItem,
            newQuantity: quantity,
            allCartItems: items
        )
        
        guard validationResult.isValid else {
            print("🛒 Update quantity validation failed: \(validationResult.errorMessage ?? "Unknown error")")
            return
        }
        
        if Configuration.autoSaveEnabled {
            saveCartSnapshot()
        }
        
        if let index = items.firstIndex(where: { $0.id == cartItem.id }) {
            if quantity <= 0 {
                items.remove(at: index)
            } else {
                items[index].quantity = quantity
            }
            print("🛒 Updated item quantity to \(quantity) ✅")
        }
    }
    
    /**
     * Clear all items from cart
     */
    func clearCart() {
        if Configuration.autoSaveEnabled {
            saveCartSnapshot()
        }
        
        items.removeAll()
        print("🛒 Cart cleared ✅")
    }
    
    /**
     * Validate cart for checkout
     */
    func validateForCheckout() -> CartValidationResult {
        return validationService.validateCartForCheckout(items)
    }
    
    // MARK: - Business Hours Operations (Delegated to BusinessHoursService)
    
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
        await businessHoursService.fetchBusinessHours(for: shop)
    }
    
    /**
     * Refresh business hours for a shop
     */
    func refreshBusinessHours(for shop: CoffeeShop) async {
        await businessHoursService.refreshBusinessHours(for: shop)
    }
    
    /**
     * Clear business hours cache
     */
    func clearBusinessHoursCache() {
        businessHoursService.clearCache()
    }
    
    // MARK: - Undo/Redo Operations
    
    /**
     * Undo last cart operation
     */
    func undoLastOperation() -> Bool {
        guard let lastSnapshot = cartHistory.popLast() else {
            return false
        }
        
        items = lastSnapshot.items
        print("🛒 Undo operation completed ✅")
        return true
    }
    
    /**
     * Check if undo is available
     */
    var canUndo: Bool {
        return !cartHistory.isEmpty
    }
    
    // MARK: - Cart Analysis
    
    /**
     * Get cart summary
     */
    func getCartSummary() -> CartSummary {
        let itemsByCategory = Dictionary(grouping: items) { $0.category }
        let categoryTotals = itemsByCategory.mapValues { items in
            items.reduce(0) { $0 + $1.totalPrice }
        }
        
        return CartSummary(
            totalItems: totalItems,
            uniqueItems: items.count,
            totalPrice: totalPrice,
            shop: currentShop,
            categoriesCount: itemsByCategory.count,
            categoryTotals: categoryTotals
        )
    }
    
    /**
     * Get items grouped by category
     */
    func getItemsByCategory() -> [String: [CartItem]] {
        return Dictionary(grouping: items) { $0.category }
    }
    
    /**
     * Find items by menu item ID
     */
    func findItems(by menuItemId: String) -> [CartItem] {
        return items.filter { $0.menuItemId == menuItemId }
    }
    
    // MARK: - Private Methods
    
    private func setupServiceStateForwarding() {
        // Forward business hours state
        businessHoursService.$shopBusinessHours
            .assign(to: &$shopBusinessHours)
        
        businessHoursService.$isLoadingBusinessHours
            .assign(to: &$isLoadingBusinessHours)
    }
    
    private func setupCartMonitoring() {
        // Monitor cart changes for analytics and auto-save
        $items
            .sink { [weak self] newItems in
                self?.handleCartChange(newItems)
            }
            .store(in: &cancellables)
    }
    
    private func handleCartChange(_ newItems: [CartItem]) {
        lastSyncTime = Date()
        
        // Track cart analytics
        trackCartOperation("cart_changed", details: [
            "item_count": newItems.count,
            "total_price": totalPrice,
            "shop_id": currentShopId ?? "none"
        ])
    }
    
    private func findExistingItemIndex(
        shop: CoffeeShop,
        menuItem: MenuItem,
        customizations: String?,
        itemPriceWithModifiers: Double,
        selectedSizeId: String?,
        selectedModifierIdsByList: [String: [String]]?
    ) -> Int? {
        
        return items.firstIndex { item in
            item.shop.id == shop.id &&
            item.menuItemId == menuItem.id &&
            item.customizations == customizations &&
            item.itemPriceWithModifiers == itemPriceWithModifiers &&
            item.selectedSizeId == selectedSizeId &&
            normalizeModifierMap(item.selectedModifierIdsByList) == normalizeModifierMap(selectedModifierIdsByList)
        }
    }
    
    private func saveCartSnapshot() {
        let snapshot = CartSnapshot(
            items: items,
            timestamp: Date()
        )
        
        cartHistory.append(snapshot)
        
        // Limit history size
        if cartHistory.count > Configuration.maxUndoSteps {
            cartHistory.removeFirst()
        }
    }
    
    private func trackCartOperation(_ operation: String, details: [String: Any] = [:]) {
        // In a real app, this would send analytics data
        print("📊 CartManager: \(operation) - \(details)")
    }
}

// MARK: - CartSnapshot

/**
 * Snapshot of cart state for undo functionality
 */
private struct CartSnapshot {
    let items: [CartItem]
    let timestamp: Date
}

// MARK: - CartSummary

/**
 * Summary of cart contents and statistics
 */
struct CartSummary {
    let totalItems: Int
    let uniqueItems: Int
    let totalPrice: Double
    let shop: CoffeeShop?
    let categoriesCount: Int
    let categoryTotals: [String: Double]
    
    var averageItemPrice: Double {
        guard totalItems > 0 else { return 0.0 }
        return totalPrice / Double(totalItems)
    }
    
    var shopName: String {
        return shop?.name ?? "No shop selected"
    }
    
    var formattedTotalPrice: String {
        return String(format: "$%.2f", totalPrice)
    }
}

// MARK: - Utility Functions

/**
 * Normalize modifier map for comparison
 */
private func normalizeModifierMap(_ map: [String: [String]]?) -> [String: [String]]? {
    guard let map = map else { return nil }
    var normalized: [String: [String]] = [:]
    for (key, value) in map {
        normalized[key] = value.sorted()
    }
    return normalized
}

// MARK: - Analytics Extensions

extension RefactoredCartManager {
    
    /**
     * Get cart analytics data
     */
    var analyticsData: [String: Any] {
        let summary = getCartSummary()
        return [
            "total_items": summary.totalItems,
            "unique_items": summary.uniqueItems,
            "total_price": summary.totalPrice,
            "shop_id": currentShopId ?? "none",
            "categories_count": summary.categoriesCount,
            "average_item_price": summary.averageItemPrice,
            "cart_age_seconds": Date().timeIntervalSince(lastSyncTime),
            "can_undo": canUndo
        ]
    }
    
    /**
     * Export cart data for sharing/backup
     */
    func exportCartData() -> [String: Any] {
        return [
            "items": items.map { item in
                [
                    "shop_id": item.shop.id,
                    "shop_name": item.shop.name,
                    "menu_item_id": item.menuItemId,
                    "menu_item_name": item.menuItem.name,
                    "category": item.category,
                    "quantity": item.quantity,
                    "customizations": item.customizations ?? "",
                    "price": item.itemPriceWithModifiers,
                    "total_price": item.totalPrice
                ]
            },
            "summary": [
                "total_items": totalItems,
                "total_price": totalPrice,
                "shop_name": currentShop?.name ?? "",
                "created_at": Date().timeIntervalSince1970
            ]
        ]
    }
}
