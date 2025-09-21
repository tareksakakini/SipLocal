/**
 * CartValidationService.swift
 * SipLocal
 *
 * Service responsible for cart validation operations.
 * Handles validation logic for cart items, shop compatibility, and business rules.
 *
 * ## Features
 * - **Cart Validation**: Validate cart items and operations
 * - **Shop Compatibility**: Ensure items are from the same shop
 * - **Business Rules**: Enforce business hours and availability rules
 * - **Item Matching**: Advanced item matching with customizations
 * - **Error Handling**: Comprehensive validation with detailed error messages
 *
 * ## Architecture
 * - **Single Responsibility**: Focused solely on validation logic
 * - **Business Logic**: Encapsulates all cart validation rules
 * - **Reusable**: Can be used by multiple cart operations
 * - **Testable**: Pure functions for easy unit testing
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation

/**
 * Service for managing cart validation operations
 */
class CartValidationService {
    
    // MARK: - Validation Operations
    
    /**
     * Validate if an item can be added to the cart
     */
    func canAddItem(
        shop: CoffeeShop,
        menuItem: MenuItem,
        existingItems: [CartItem],
        isShopOpen: Bool?
    ) -> ValidationResult {
        
        // Check if cart has items from a different coffee shop
        if !existingItems.isEmpty && existingItems.first?.shop.id != shop.id {
            return .failure(.differentShop)
        }
        
        // Check if shop is open (if we have business hours data)
        if let isOpen = isShopOpen, !isOpen {
            return .failure(.shopClosed)
        }
        
        return .success
    }
    
    /**
     * Find existing item in cart that matches the new item
     */
    func findMatchingItem(
        shop: CoffeeShop,
        menuItem: MenuItem,
        customizations: String?,
        itemPriceWithModifiers: Double,
        selectedSizeId: String?,
        selectedModifierIdsByList: [String: [String]]?,
        existingItems: [CartItem]
    ) -> Int? {
        
        return existingItems.firstIndex(where: {
            // Consider item identity including menu item id and exact selections
            $0.shop.id == shop.id &&
            $0.menuItemId == menuItem.id &&
            $0.customizations == customizations &&
            $0.itemPriceWithModifiers == itemPriceWithModifiers &&
            $0.selectedSizeId == selectedSizeId &&
            normalizeModifierMap($0.selectedModifierIdsByList) == normalizeModifierMap(selectedModifierIdsByList)
        })
    }
    
    /**
     * Validate cart state
     */
    func validateCartState(items: [CartItem]) -> ValidationResult {
        if items.isEmpty {
            return .success
        }
        
        // Check if all items are from the same shop
        let shopIds = Set(items.map { $0.shop.id })
        if shopIds.count > 1 {
            return .failure(.multipleShops)
        }
        
        // Check for invalid quantities
        for item in items {
            if item.quantity <= 0 {
                return .failure(.invalidQuantity)
            }
        }
        
        return .success
    }
    
    /**
     * Validate quantity update
     */
    func validateQuantityUpdate(quantity: Int) -> ValidationResult {
        if quantity < 0 {
            return .failure(.invalidQuantity)
        }
        
        if quantity > 99 { // Reasonable upper limit
            return .failure(.quantityTooHigh)
        }
        
        return .success
    }
    
    /**
     * Check if cart is empty
     */
    func isCartEmpty(items: [CartItem]) -> Bool {
        return items.isEmpty
    }
    
    /**
     * Get cart summary
     */
    func getCartSummary(items: [CartItem]) -> CartSummary {
        let totalPrice = items.reduce(0) { $0 + $1.totalPrice }
        let totalItems = items.reduce(0) { $0 + $1.quantity }
        let shopCount = Set(items.map { $0.shop.id }).count
        
        return CartSummary(
            totalPrice: totalPrice,
            totalItems: totalItems,
            itemCount: items.count,
            shopCount: shopCount,
            isEmpty: items.isEmpty
        )
    }
}

// MARK: - Validation Result

/**
 * Result of a validation operation
 */
enum ValidationResult {
    case success
    case failure(ValidationError)
}

/**
 * Validation error types
 */
enum ValidationError: LocalizedError {
    case differentShop
    case shopClosed
    case multipleShops
    case invalidQuantity
    case quantityTooHigh
    case itemNotFound
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .differentShop:
            return "Cannot add items from different coffee shops"
        case .shopClosed:
            return "This coffee shop is currently closed"
        case .multipleShops:
            return "Cart contains items from multiple shops"
        case .invalidQuantity:
            return "Invalid quantity specified"
        case .quantityTooHigh:
            return "Quantity is too high"
        case .itemNotFound:
            return "Item not found in cart"
        case .networkError:
            return "Network error occurred"
        }
    }
}

// MARK: - Cart Summary

/**
 * Summary of cart state
 */
struct CartSummary {
    let totalPrice: Double
    let totalItems: Int
    let itemCount: Int
    let shopCount: Int
    let isEmpty: Bool
    
    var formattedTotalPrice: String {
        return String(format: "$%.2f", totalPrice)
    }
}

// MARK: - Private Helpers

/**
 * Normalize modifier map for consistent comparison
 */
private func normalizeModifierMap(_ map: [String: [String]]?) -> [String: [String]]? {
    guard let map else { return nil }
    var normalized: [String: [String]] = [:]
    for (key, value) in map {
        normalized[key] = value.sorted()
    }
    return normalized
}

// MARK: - Design System

extension CartValidationService {
    
    /**
     * Design system constants for CartValidationService
     */
    enum Design {
        // Validation limits
        static let maxQuantity = 99
        static let minQuantity = 0
        
        // Error messages
        static let differentShopError = "Cannot add items from different coffee shops"
        static let shopClosedError = "This coffee shop is currently closed"
        static let multipleShopsError = "Cart contains items from multiple shops"
        static let invalidQuantityError = "Invalid quantity specified"
        static let quantityTooHighError = "Quantity is too high"
        static let itemNotFoundError = "Item not found in cart"
        static let networkError = "Network error occurred"
        
        // Price formatting
        static let priceFormat = "$%.2f"
    }
}