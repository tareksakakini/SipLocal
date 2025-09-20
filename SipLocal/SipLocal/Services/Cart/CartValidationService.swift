/**
 * CartValidationService.swift
 * SipLocal
 *
 * Service responsible for cart validation logic.
 * Extracted from CartManager to follow Single Responsibility Principle.
 *
 * ## Responsibilities
 * - **Shop Validation**: Ensure items are from the same shop
 * - **Business Hours Validation**: Check if shop is open for ordering
 * - **Item Validation**: Validate menu items and customizations
 * - **Cart Rules**: Enforce business rules and constraints
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on validation logic
 * - **Rule Engine**: Flexible validation rules system
 * - **Error Reporting**: Detailed validation error messages
 * - **Performance**: Efficient validation with early returns
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation

// MARK: - CartValidationService

/**
 * Service for cart validation operations
 * 
 * Handles all validation logic for cart operations including shop consistency,
 * business hours, item availability, and business rules enforcement.
 */
class CartValidationService {
    
    // MARK: - Dependencies
    private let businessHoursService: BusinessHoursService
    
    // MARK: - Configuration
    private enum Configuration {
        static let maxItemsPerCart: Int = 50
        static let maxQuantityPerItem: Int = 10
        static let maxTotalPrice: Double = 999.99
        static let minOrderAmount: Double = 5.00
    }
    
    // MARK: - Initialization
    
    init(businessHoursService: BusinessHoursService) {
        self.businessHoursService = businessHoursService
    }
    
    // MARK: - Public Interface
    
    /**
     * Validate adding an item to the cart
     */
    func validateAddItem(
        to cartItems: [CartItem],
        shop: CoffeeShop,
        menuItem: MenuItem,
        quantity: Int = 1,
        customizations: String? = nil,
        itemPriceWithModifiers: Double? = nil
    ) -> CartValidationResult {
        
        // Check cart item limit
        if cartItems.count >= Configuration.maxItemsPerCart {
            return .failure(.cartLimitReached(Configuration.maxItemsPerCart))
        }
        
        // Check quantity limit
        if quantity > Configuration.maxQuantityPerItem {
            return .failure(.quantityLimitExceeded(Configuration.maxQuantityPerItem))
        }
        
        // Check shop consistency
        if let shopValidation = validateShopConsistency(cartItems: cartItems, newShop: shop) {
            return .failure(shopValidation)
        }
        
        // Check if shop is open
        if let hoursValidation = validateBusinessHours(for: shop) {
            return .failure(hoursValidation)
        }
        
        // Check menu item validity
        if let itemValidation = validateMenuItem(menuItem, customizations: customizations) {
            return .failure(itemValidation)
        }
        
        // Check price validity
        if let priceValidation = validatePrice(itemPriceWithModifiers ?? menuItem.price) {
            return .failure(priceValidation)
        }
        
        // Check total cart value after addition
        let newTotalPrice = calculateTotalPrice(cartItems) + (itemPriceWithModifiers ?? menuItem.price) * Double(quantity)
        if newTotalPrice > Configuration.maxTotalPrice {
            return .failure(.totalPriceLimitExceeded(Configuration.maxTotalPrice))
        }
        
        return .success
    }
    
    /**
     * Validate updating item quantity
     */
    func validateUpdateQuantity(
        cartItem: CartItem,
        newQuantity: Int,
        allCartItems: [CartItem]
    ) -> CartValidationResult {
        
        if newQuantity < 0 {
            return .failure(.invalidQuantity("Quantity cannot be negative"))
        }
        
        if newQuantity > Configuration.maxQuantityPerItem {
            return .failure(.quantityLimitExceeded(Configuration.maxQuantityPerItem))
        }
        
        // Check total price after quantity update
        let otherItemsPrice = allCartItems.filter { $0.id != cartItem.id }.reduce(0) { $0 + $1.totalPrice }
        let newItemPrice = cartItem.itemPriceWithModifiers * Double(newQuantity)
        let newTotalPrice = otherItemsPrice + newItemPrice
        
        if newTotalPrice > Configuration.maxTotalPrice {
            return .failure(.totalPriceLimitExceeded(Configuration.maxTotalPrice))
        }
        
        return .success
    }
    
    /**
     * Validate cart for checkout
     */
    func validateCartForCheckout(_ cartItems: [CartItem]) -> CartValidationResult {
        
        // Check if cart is empty
        if cartItems.isEmpty {
            return .failure(.emptyCart)
        }
        
        // Check minimum order amount
        let totalPrice = calculateTotalPrice(cartItems)
        if totalPrice < Configuration.minOrderAmount {
            return .failure(.minimumOrderNotMet(Configuration.minOrderAmount))
        }
        
        // Check shop is still open (if we have business hours data)
        if let firstShop = cartItems.first?.shop {
            if let hoursValidation = validateBusinessHours(for: firstShop) {
                return .failure(hoursValidation)
            }
        }
        
        // Validate all items are still valid
        for item in cartItems {
            if let itemValidation = validateMenuItem(item.menuItem, customizations: item.customizations) {
                return .failure(itemValidation)
            }
        }
        
        return .success
    }
    
    /**
     * Validate shop consistency across cart items
     */
    func validateShopConsistency(cartItems: [CartItem], newShop: CoffeeShop) -> CartValidationError? {
        guard !cartItems.isEmpty else { return nil }
        
        if let existingShopId = cartItems.first?.shop.id, existingShopId != newShop.id {
            return .differentShop(existingShopName: cartItems.first?.shop.name ?? "Unknown")
        }
        
        return nil
    }
    
    /**
     * Validate business hours for ordering
     */
    func validateBusinessHours(for shop: CoffeeShop) -> CartValidationError? {
        guard let isOpen = businessHoursService.isShopOpen(shop: shop) else {
            // No business hours data available - allow ordering
            return nil
        }
        
        if !isOpen {
            return .shopClosed(shopName: shop.name)
        }
        
        return nil
    }
    
    /**
     * Validate menu item and customizations
     */
    func validateMenuItem(_ menuItem: MenuItem, customizations: String?) -> CartValidationError? {
        // Check if menu item has required fields
        if menuItem.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .invalidMenuItem("Menu item name is empty")
        }
        
        if menuItem.price < 0 {
            return .invalidMenuItem("Menu item has negative price")
        }
        
        // Validate customizations length if present
        if let customizations = customizations,
           customizations.count > 500 { // Reasonable limit for customizations text
            return .invalidCustomizations("Customizations text too long")
        }
        
        return nil
    }
    
    /**
     * Validate price value
     */
    func validatePrice(_ price: Double) -> CartValidationError? {
        if price < 0 {
            return .invalidPrice("Price cannot be negative")
        }
        
        if price > 999.99 { // Reasonable upper limit for a single item
            return .invalidPrice("Price exceeds maximum allowed")
        }
        
        return nil
    }
    
    /**
     * Check if cart can accept items from a specific shop
     */
    func canAcceptItemsFrom(shop: CoffeeShop, currentCartItems: [CartItem]) -> Bool {
        return validateShopConsistency(cartItems: currentCartItems, newShop: shop) == nil
    }
    
    /**
     * Get validation rules summary
     */
    func getValidationRules() -> CartValidationRules {
        return CartValidationRules(
            maxItemsPerCart: Configuration.maxItemsPerCart,
            maxQuantityPerItem: Configuration.maxQuantityPerItem,
            maxTotalPrice: Configuration.maxTotalPrice,
            minOrderAmount: Configuration.minOrderAmount
        )
    }
    
    // MARK: - Private Methods
    
    private func calculateTotalPrice(_ cartItems: [CartItem]) -> Double {
        return cartItems.reduce(0) { $0 + $1.totalPrice }
    }
}

// MARK: - CartValidationResult

/**
 * Result of cart validation operations
 */
enum CartValidationResult {
    case success
    case failure(CartValidationError)
    
    var isValid: Bool {
        switch self {
        case .success:
            return true
        case .failure:
            return false
        }
    }
    
    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .failure(let error):
            return error.localizedDescription
        }
    }
}

// MARK: - CartValidationError

/**
 * Structured error types for cart validation
 */
enum CartValidationError: LocalizedError {
    case emptyCart
    case cartLimitReached(Int)
    case quantityLimitExceeded(Int)
    case totalPriceLimitExceeded(Double)
    case minimumOrderNotMet(Double)
    case differentShop(existingShopName: String)
    case shopClosed(shopName: String)
    case invalidMenuItem(String)
    case invalidCustomizations(String)
    case invalidPrice(String)
    case invalidQuantity(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyCart:
            return "Cart is empty"
        case .cartLimitReached(let limit):
            return "Cart limit reached (\(limit) items maximum)"
        case .quantityLimitExceeded(let limit):
            return "Quantity limit exceeded (\(limit) maximum per item)"
        case .totalPriceLimitExceeded(let limit):
            return "Total price limit exceeded ($\(String(format: "%.2f", limit)) maximum)"
        case .minimumOrderNotMet(let minimum):
            return "Minimum order amount not met ($\(String(format: "%.2f", minimum)) required)"
        case .differentShop(let existingShopName):
            return "Cannot add items from different shops. Current cart contains items from \(existingShopName)"
        case .shopClosed(let shopName):
            return "\(shopName) is currently closed"
        case .invalidMenuItem(let message):
            return "Invalid menu item: \(message)"
        case .invalidCustomizations(let message):
            return "Invalid customizations: \(message)"
        case .invalidPrice(let message):
            return "Invalid price: \(message)"
        case .invalidQuantity(let message):
            return "Invalid quantity: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .emptyCart:
            return "Add items to your cart before proceeding."
        case .cartLimitReached:
            return "Please remove some items before adding more."
        case .quantityLimitExceeded:
            return "Please reduce the quantity or add the item multiple times."
        case .totalPriceLimitExceeded:
            return "Please remove some items to reduce the total price."
        case .minimumOrderNotMet:
            return "Please add more items to meet the minimum order amount."
        case .differentShop:
            return "Please clear your cart or complete your current order first."
        case .shopClosed:
            return "Please try again during business hours or choose a different shop."
        case .invalidMenuItem:
            return "Please select a valid menu item."
        case .invalidCustomizations:
            return "Please check your customizations and try again."
        case .invalidPrice:
            return "Please contact support if this issue persists."
        case .invalidQuantity:
            return "Please enter a valid quantity between 1 and 10."
        }
    }
}

// MARK: - CartValidationRules

/**
 * Configuration rules for cart validation
 */
struct CartValidationRules {
    let maxItemsPerCart: Int
    let maxQuantityPerItem: Int
    let maxTotalPrice: Double
    let minOrderAmount: Double
    
    var summary: String {
        return """
        Cart Validation Rules:
        • Maximum items per cart: \(maxItemsPerCart)
        • Maximum quantity per item: \(maxQuantityPerItem)
        • Maximum total price: $\(String(format: "%.2f", maxTotalPrice))
        • Minimum order amount: $\(String(format: "%.2f", minOrderAmount))
        """
    }
}

// MARK: - Analytics Extensions

extension CartValidationService {
    
    /**
     * Track validation operations for analytics
     */
    func trackValidation(_ operation: String, result: CartValidationResult, details: [String: Any] = [:]) {
        // In a real app, this would send analytics data
        let status = result.isValid ? "✅" : "❌"
        var logDetails = details
        if let error = result.errorMessage {
            logDetails["error"] = error
        }
        print("📊 CartValidationService: \(operation) \(status) - \(logDetails)")
    }
    
    /**
     * Get validation analytics data
     */
    var analyticsData: [String: Any] {
        let rules = getValidationRules()
        return [
            "max_items_per_cart": rules.maxItemsPerCart,
            "max_quantity_per_item": rules.maxQuantityPerItem,
            "max_total_price": rules.maxTotalPrice,
            "min_order_amount": rules.minOrderAmount,
            "validation_rules_version": "1.0"
        ]
    }
}
