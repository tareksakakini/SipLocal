/**
 * CartView.swift
 * SipLocal
 *
 * Main cart view displaying cart items, totals, and checkout functionality.
 * Refactored with clean architecture and MVVM pattern.
 *
 * ## Features
 * - **Empty State**: Clean empty cart display with call-to-action
 * - **Cart Items**: Scrollable list of cart items with quantity controls
 * - **Total Section**: Price summary and checkout button
 * - **Business Hours**: Shop availability validation for checkout
 * - **Navigation**: Back button and cart clearing functionality
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses CartViewModel for business logic
 * - **Component-Based**: Uses extracted CartItemRow component
 * - **Clean Separation**: UI logic separated from business logic
 * - **Reactive State**: Responds to ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

struct CartView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: CartViewModel
    
    // MARK: - Initialization
    
    /**
     * Initialize with CartManager dependency
     */
    init() {
        // We'll initialize the ViewModel in onAppear with the environment CartManager
        self._viewModel = StateObject(wrappedValue: CartViewModel(cartManager: CartManager()))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.isCartEmpty {
                    emptyCartState
                } else {
                    cartContent
                }
            }
            .background(CartViewModel.Design.backgroundColor)
            .navigationTitle("Cart")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
                
                if !viewModel.isCartEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        clearCartButton
                    }
                }
            }
            .alert("Shop is Closed", isPresented: $viewModel.showingClosedShopAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This coffee shop is currently closed. Please try again during business hours.")
            }
            .onAppear {
                viewModel.updateCartManager(cartManager)
                viewModel.fetchBusinessHours()
            }
        }
    }
    
    // MARK: - View Components
    
    /**
     * Empty cart state display
     */
    private var emptyCartState: some View {
        VStack(spacing: CartViewModel.Design.emptyStateSpacing) {
            Spacer()
            
            Image(systemName: "cart")
                .font(.system(size: CartViewModel.Design.emptyStateIconSize))
                .foregroundColor(CartViewModel.Design.emptyStateIconColor)
            
            VStack(spacing: CartViewModel.Design.emptyStateTextSpacing) {
                Text("Your cart is empty")
                    .font(CartViewModel.Design.emptyStateTitleFont)
                    .fontWeight(CartViewModel.Design.emptyStateTitleWeight)
                
                Text("Add some items to get started")
                    .font(CartViewModel.Design.emptyStateSubtitleFont)
                    .foregroundColor(CartViewModel.Design.emptyStateSubtitleColor)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    /**
     * Cart content with items and checkout
     */
    private var cartContent: some View {
        VStack(spacing: 0) {
            // Cart items list
            cartItemsList
            
            // Total section with checkout
            totalSection
        }
    }
    
    /**
     * Scrollable cart items list
     */
    private var cartItemsList: some View {
        ScrollView {
            LazyVStack(spacing: CartViewModel.Design.itemsSpacing) {
                ForEach(viewModel.cartItems) { item in
                    CartItemRow(cartItem: item)
                }
            }
            .padding(CartViewModel.Design.itemsPadding)
        }
    }
    
    /**
     * Total section with price and checkout button
     */
    private var totalSection: some View {
        VStack(spacing: CartViewModel.Design.totalSectionSpacing) {
            Divider()
            
            HStack {
                Text("Total (\(viewModel.totalItems) items)")
                    .font(CartViewModel.Design.totalItemsFont)
                    .fontWeight(CartViewModel.Design.totalItemsWeight)
                
                Spacer()
                
                Text("$\(viewModel.totalPrice, specifier: "%.2f")")
                    .font(CartViewModel.Design.totalPriceFont)
                    .fontWeight(CartViewModel.Design.totalPriceWeight)
            }
            .padding(.horizontal, CartViewModel.Design.totalHorizontalPadding)
            
            // Checkout button
            checkoutButton
        }
        .background(CartViewModel.Design.totalSectionBackgroundColor)
    }
    
    /**
     * Checkout button with business hours validation
     */
    private var checkoutButton: some View {
        Group {
            if viewModel.isCheckoutDisabled {
                Button(action: {
                    viewModel.handleCheckout()
                }) {
                    Text(viewModel.checkoutButtonText)
                        .font(CartViewModel.Design.checkoutButtonFont)
                        .fontWeight(CartViewModel.Design.checkoutButtonWeight)
                        .foregroundColor(CartViewModel.Design.checkoutButtonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(CartViewModel.Design.checkoutButtonPadding)
                        .background(viewModel.checkoutButtonColor)
                        .cornerRadius(CartViewModel.Design.checkoutButtonCornerRadius)
                }
            } else {
                NavigationLink(destination: CheckoutView().environmentObject(cartManager)) {
                    Text(viewModel.checkoutButtonText)
                        .font(CartViewModel.Design.checkoutButtonFont)
                        .fontWeight(CartViewModel.Design.checkoutButtonWeight)
                        .foregroundColor(CartViewModel.Design.checkoutButtonTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(CartViewModel.Design.checkoutButtonPadding)
                        .background(viewModel.checkoutButtonColor)
                        .cornerRadius(CartViewModel.Design.checkoutButtonCornerRadius)
                }
            }
        }
        .padding(.horizontal, CartViewModel.Design.totalHorizontalPadding)
        .padding(.bottom, CartViewModel.Design.totalBottomPadding)
    }
    
    /**
     * Back navigation button
     */
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: CartViewModel.Design.backButtonSpacing) {
                Image(systemName: "chevron.left")
                    .font(.system(size: CartViewModel.Design.backButtonIconSize, weight: .medium))
                Text("Back")
                    .font(CartViewModel.Design.backButtonFont)
            }
            .foregroundColor(CartViewModel.Design.backButtonColor)
        }
    }
    
    /**
     * Clear cart button
     */
    private var clearCartButton: some View {
        Button("Clear") {
            viewModel.clearCart()
        }
        .foregroundColor(CartViewModel.Design.clearButtonColor)
    }
}

// MARK: - Preview

struct CartView_Previews: PreviewProvider {
    static var previews: some View {
        CartView()
            .environmentObject(CartManager())
    }
} 