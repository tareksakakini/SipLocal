/**
 * CartViewModel.swift
 * SipLocal
 *
 * ViewModel for CartView - handles cart display, business hours validation,
 * and checkout flow management.
 *
 * ## Features
 * - **Cart State Management**: Monitor cart items, totals, and empty state
 * - **Business Hours Validation**: Check shop availability for checkout
 * - **Checkout Flow**: Handle navigation to checkout with validation
 * - **Cart Operations**: Clear cart and manage cart state
 * - **Error Handling**: Handle shop closure and validation errors
 *
 * ## Architecture
 * - **MVVM Pattern**: Separates business logic from UI
 * - **Dependency Injection**: Receives CartManager for cart operations
 * - **Reactive State**: Uses @Published for UI updates
 * - **Error Boundaries**: Structured error handling for cart operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

/**
 * ViewModel for CartView
 * 
 * Manages cart display state, business hours validation,
 * and checkout flow coordination.
 */
@MainActor
class CartViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Show closed shop alert
    @Published var showingClosedShopAlert = false
    
    /// Show cart view
    @Published var showingCart = false
    
    // MARK: - Dependencies
    
    private var cartManager: CartManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /**
     * Check if cart is empty
     */
    var isCartEmpty: Bool {
        cartManager.items.isEmpty
    }
    
    /**
     * Get total number of items in cart
     */
    var totalItems: Int {
        cartManager.totalItems
    }
    
    /**
     * Get total price of cart
     */
    var totalPrice: Double {
        cartManager.totalPrice
    }
    
    /**
     * Get cart items
     */
    var cartItems: [CartItem] {
        cartManager.items
    }
    
    /**
     * Check if shop is open (based on first item in cart)
     */
    var isShopOpen: Bool? {
        guard let firstItem = cartManager.items.first else { return nil }
        return cartManager.isShopOpen(shop: firstItem.shop)
    }
    
    /**
     * Get shop from first cart item
     */
    var shop: CoffeeShop? {
        cartManager.items.first?.shop
    }
    
    // MARK: - Initialization
    
    /**
     * Initialize with CartManager dependency
     */
    init(cartManager: CartManager) {
        self.cartManager = cartManager
        
        setupCartObservers()
    }
    
    // MARK: - Public Methods
    
    /**
     * Update the CartManager reference
     */
    func updateCartManager(_ cartManager: CartManager) {
        self.cartManager = cartManager
        setupCartObservers()
    }
    
    /**
     * Fetch business hours for the shop in cart
     */
    func fetchBusinessHours() {
        guard let shop = shop else { return }
        
        Task {
            await cartManager.fetchBusinessHours(for: shop)
        }
    }
    
    /**
     * Clear the entire cart
     */
    func clearCart() {
        cartManager.clearCart()
    }
    
    /**
     * Handle checkout button tap
     */
    func handleCheckout() {
        guard let isOpen = isShopOpen else {
            // If we can't determine shop status, allow checkout
            return
        }
        
        if !isOpen {
            showingClosedShopAlert = true
        }
        // If shop is open, navigation will be handled by the view
    }
    
    /**
     * Update quantity for a cart item
     */
    func updateQuantity(cartItem: CartItem, quantity: Int) {
        cartManager.updateQuantity(cartItem: cartItem, quantity: quantity)
    }
    
    /**
     * Check if checkout should be disabled
     */
    var isCheckoutDisabled: Bool {
        guard let isOpen = isShopOpen else { return false }
        return !isOpen
    }
    
    /**
     * Get checkout button text
     */
    var checkoutButtonText: String {
        if isCheckoutDisabled {
            return "Shop is Closed"
        } else {
            return "Checkout"
        }
    }
    
    /**
     * Get checkout button color
     */
    var checkoutButtonColor: Color {
        if isCheckoutDisabled {
            return .red
        } else {
            return .black
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup cart state observers
     */
    private func setupCartObservers() {
        // Observe cart changes for UI updates
        cartManager.$items
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Design System

extension CartViewModel {
    
    /**
     * Design system constants for the cart view
     */
    enum Design {
        // Empty state
        static let emptyStateSpacing: CGFloat = 24
        static let emptyStateIconSize: CGFloat = 80
        static let emptyStateTextSpacing: CGFloat = 8
        
        // Cart items
        static let itemsSpacing: CGFloat = 16
        static let itemsPadding: CGFloat = 16
        
        // Total section
        static let totalSectionSpacing: CGFloat = 16
        static let totalHorizontalPadding: CGFloat = 16
        static let totalBottomPadding: CGFloat = 16
        
        // Checkout button
        static let checkoutButtonPadding: CGFloat = 16
        static let checkoutButtonCornerRadius: CGFloat = 12
        
        // Navigation
        static let backButtonSpacing: CGFloat = 4
        static let backButtonIconSize: CGFloat = 16
        
        // Typography
        static let emptyStateTitleFont: Font = .title2
        static let emptyStateTitleWeight: Font.Weight = .semibold
        static let emptyStateSubtitleFont: Font = .subheadline
        static let totalItemsFont: Font = .headline
        static let totalItemsWeight: Font.Weight = .semibold
        static let totalPriceFont: Font = .title2
        static let totalPriceWeight: Font.Weight = .bold
        static let checkoutButtonFont: Font = .headline
        static let checkoutButtonWeight: Font.Weight = .semibold
        static let backButtonFont: Font = .body
        static let clearButtonFont: Font = .body
        
        // Colors
        static let emptyStateIconColor: Color = .gray
        static let emptyStateSubtitleColor: Color = .secondary
        static let clearButtonColor: Color = .red
        static let backButtonColor: Color = .primary
        static let checkoutButtonTextColor: Color = .white
        
        // Background
        static let backgroundColor: Color = Color(.systemGray6)
        static let totalSectionBackgroundColor: Color = Color(.systemGray6)
    }
}
