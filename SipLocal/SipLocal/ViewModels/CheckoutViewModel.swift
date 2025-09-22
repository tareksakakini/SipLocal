/**
 * CheckoutViewModel.swift
 * SipLocal
 *
 * ViewModel for CheckoutView - handles payment processing, order submission,
 * business hours validation, and checkout flow management.
 *
 * ## Features
 * - **Payment Processing**: Stripe and Apple Pay payment integration
 * - **Order Management**: Order submission and status tracking
 * - **Business Hours Validation**: Shop availability checking
 * - **Pickup Time Management**: Time selection and validation
 * - **Error Handling**: Comprehensive error handling for all payment methods
 * - **State Management**: UI state management for checkout flow
 *
 * ## Architecture
 * - **MVVM Pattern**: Separates business logic from UI
 * - **Dependency Injection**: Receives CartManager, OrderManager, and AuthenticationManager
 * - **Reactive State**: Uses @Published for UI updates
 * - **Error Boundaries**: Structured error handling for payment operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine
import StripePaymentSheet
import PassKit
import Stripe

/**
 * ViewModel for CheckoutView
 * 
 * Manages payment processing, order submission, business hours validation,
 * and checkout flow coordination.
 */
@MainActor
class CheckoutViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Payment processing state
    @Published var isProcessingPayment = false
    @Published var isProcessingApplePay = false
    
    /// Payment results and state
    @Published var paymentResult: String = ""
    @Published var paymentSuccess = false
    @Published var transactionId: String?
    @Published var showingPaymentResult = false
    
    /// Completed order details
    @Published var completedOrderItems: [CartItem] = []
    @Published var completedOrderTotal: Double = 0.0
    @Published var completedOrderShop: CoffeeShop?
    
    /// Pickup time management
    @Published var selectedPickupTime = Date().addingTimeInterval(5 * 60) // Default to 5 minutes from now
    @Published var showingTimePicker = false
    
    /// Alerts and sheets
    @Published var showingClosedShopAlert = false
    
    /// Stripe PaymentSheet state
    @Published var paymentSheet: PaymentSheet?
    @Published var stripePaymentResult: PaymentSheetResult?
    @Published var pendingClientSecret: String?
    
    /// User data
    @Published var userData: UserData?
    
    // MARK: - Dependencies
    
    private var cartManager: CartManager
    private var orderManager: OrderManager
    private var authManager: AuthenticationManager
    private let paymentService: PaymentService
    private let tokenService: TokenService
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Delegates
    
    @Published var applePayDelegate = ApplePayDelegate()
    
    // MARK: - Computed Properties
    
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
    
    /**
     * Check if checkout should be disabled
     */
    var isCheckoutDisabled: Bool {
        guard let isOpen = isShopOpen else { return false }
        return !isOpen
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
    
    // MARK: - Initialization
    
    /**
     * Initialize with dependencies
     */
    init(
        cartManager: CartManager,
        orderManager: OrderManager,
        authManager: AuthenticationManager,
        paymentService: PaymentService = PaymentService(),
        tokenService: TokenService = TokenService()
    ) {
        self.cartManager = cartManager
        self.orderManager = orderManager
        self.authManager = authManager
        self.paymentService = paymentService
        self.tokenService = tokenService
        
        setupObservers()
    }
    
    // MARK: - Public Methods
    
    /**
     * Update dependencies
     */
    func updateDependencies(
        cartManager: CartManager,
        orderManager: OrderManager,
        authManager: AuthenticationManager
    ) {
        self.cartManager = cartManager
        self.orderManager = orderManager
        self.authManager = authManager
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
     * Handle checkout button tap with business hours validation
     */
    func handleCheckout() {
        guard let isOpen = isShopOpen else {
            // If we can't determine shop status, allow checkout
            return
        }
        
        if !isOpen {
            showingClosedShopAlert = true
        }
        // If shop is open, payment processing will be handled by the view
    }
    
    /**
     * Process Stripe payment
     */
    func processStripePayment() {
        isProcessingPayment = true
        paymentResult = "Processing Stripe payment..."
        
        guard let firstItem = cartManager.items.first else {
            paymentResult = "No items in cart"
            isProcessingPayment = false
            return
        }
        
        let merchantId = firstItem.shop.merchantId
        
        // Fetch user data before payment
        guard let userId = authManager.currentUser?.uid else {
            paymentResult = "User not logged in."
            isProcessingPayment = false
            return
        }
        
        authManager.getUserData(userId: userId) { userData, error in
            guard let userData = userData else {
                DispatchQueue.main.async {
                    self.paymentResult = "Failed to fetch user info: \(error ?? "Unknown error")"
                    self.isProcessingPayment = false
                }
                return
            }
            
            Task {
                do {
                    let credentials = try await self.tokenService.getMerchantTokens(merchantId: merchantId)
                    print("Debug - Processing Stripe payment:")
                    print("  amount: \(self.cartManager.totalPrice)")
                    print("  merchantId: \(merchantId)")
                    print("  oauth_token: \(credentials.oauth_token.prefix(10)))...")
                    
                    // Get PaymentIntent and client secret from backend
                    let result = await self.paymentService.createAuthorizedOrderWithStripe(
                        amount: self.cartManager.totalPrice,
                        merchantId: merchantId,
                        oauthToken: credentials.oauth_token,
                        cartItems: self.cartManager.items,
                        customerName: userData.fullName,
                        customerEmail: userData.email,
                        userId: userId,
                        coffeeShop: self.cartManager.items.first!.shop,
                        pickupTime: self.selectedPickupTime
                    )
                    
                    await MainActor.run {
                        switch result {
                        case .success(let (transaction, clientSecret)):
                            if let clientSecret = clientSecret {
                                // Create PaymentSheet configuration
                                var configuration = PaymentSheet.Configuration()
                                configuration.merchantDisplayName = self.cartManager.items.first?.shop.name ?? "Coffee Shop"
                                configuration.allowsDelayedPaymentMethods = false
                                
                                // Create PaymentSheet
                                self.paymentSheet = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                                
                                // Store transaction details for later use
                                self.transactionId = transaction.transactionId
                                self.pendingClientSecret = clientSecret
                                self.completedOrderItems = self.cartManager.items
                                self.completedOrderTotal = self.cartManager.totalPrice
                                self.completedOrderShop = self.cartManager.items.first?.shop
                                
                                // Present PaymentSheet
                                self.isProcessingPayment = false
                                self.presentPaymentSheet()
                            } else {
                                self.paymentResult = "Failed to get payment client secret"
                                self.paymentSuccess = false
                                self.transactionId = nil
                                self.isProcessingPayment = false
                                self.showingPaymentResult = true
                            }
                        case .failure(let error):
                            self.paymentResult = error.localizedDescription
                            self.paymentSuccess = false
                            self.transactionId = nil
                            self.isProcessingPayment = false
                            self.showingPaymentResult = true
                        }
                    }
                } catch {
                    await MainActor.run {
                        self.paymentResult = "Failed to process Stripe payment: \(error.localizedDescription)"
                        self.paymentSuccess = false
                        self.transactionId = nil
                        self.isProcessingPayment = false
                        self.showingPaymentResult = true
                    }
                }
            }
        }
    }
    
    /**
     * Process Apple Pay payment
     */
    func processApplePayment() {
        print("🍎 Apple Pay: Starting processApplePayment()")
        
        guard let firstItem = cartManager.items.first else {
            print("❌ Apple Pay: No items in cart")
            paymentResult = "No items in cart"
            return
        }
        
        print("🍎 Apple Pay: First item found - \(firstItem.menuItem.name)")
        print("🍎 Apple Pay: Total price - $\(cartManager.totalPrice)")
        print("🍎 Apple Pay: Cart items count - \(cartManager.items.count)")
        
        let merchantId = "merchant.com.siplocal.app"
        let request = PKPaymentRequest()
        
        request.merchantIdentifier = merchantId
        request.supportedNetworks = [.visa, .masterCard, .amex, .discover]
        request.merchantCapabilities = .threeDSecure
        request.countryCode = "US"
        request.currencyCode = "USD"
        
        print("🍎 Apple Pay: Payment request configured with merchant ID: \(merchantId)")
        
        // Create payment summary items
        var paymentItems: [PKPaymentSummaryItem] = []
        
        // Add individual cart items
        for item in cartManager.items {
            let itemTotal = item.totalPrice
            let paymentItem = PKPaymentSummaryItem(
                label: "\(item.menuItem.name) x\(item.quantity)",
                amount: NSDecimalNumber(value: itemTotal),
                type: .final
            )
            paymentItems.append(paymentItem)
            print("🍎 Apple Pay: Added item - \(item.menuItem.name) x\(item.quantity) = $\(itemTotal)")
        }
        
        // Add total
        let totalItem = PKPaymentSummaryItem(
            label: firstItem.shop.name,
            amount: NSDecimalNumber(value: cartManager.totalPrice),
            type: .final
        )
        paymentItems.append(totalItem)
        
        request.paymentSummaryItems = paymentItems
        print("🍎 Apple Pay: Payment summary items created - Total: $\(cartManager.totalPrice)")
        
        // Configure the delegate with necessary data
        print("🍎 Apple Pay: Configuring delegate...")
        applePayDelegate.configure(
            cartManager: cartManager,
            authManager: authManager,
            tokenService: tokenService,
            paymentService: paymentService,
            orderManager: orderManager,
            selectedPickupTime: selectedPickupTime,
            onPaymentResult: { [self] success, message, transactionId, orderItems, orderTotal, orderShop in
                print("🍎 Apple Pay: Payment result callback - Success: \(success), Message: \(message)")
                DispatchQueue.main.async {
                    self.paymentSuccess = success
                    self.paymentResult = message
                    self.transactionId = transactionId
                    if success {
                        print("🍎 Apple Pay: Payment successful, clearing cart")
                        self.completedOrderItems = orderItems
                        self.completedOrderTotal = orderTotal
                        self.completedOrderShop = orderShop
                        self.cartManager.clearCart()
                    } else {
                        print("❌ Apple Pay: Payment failed - \(message)")
                    }
                    self.isProcessingApplePay = false
                    self.showingPaymentResult = true
                }
            }
        )
        
        // Present Apple Pay sheet
        print("🍎 Apple Pay: Creating payment authorization controller...")
        let controller = PKPaymentAuthorizationController(paymentRequest: request)
        controller.delegate = applePayDelegate
        
        print("🍎 Apple Pay: Presenting Apple Pay sheet...")
        controller.present { presented in
            if !presented {
                print("❌ Apple Pay: Failed to present Apple Pay sheet")
                self.paymentResult = "Unable to present Apple Pay"
                self.showingPaymentResult = true
            } else {
                print("✅ Apple Pay: Apple Pay sheet presented successfully")
            }
        }
    }
    
    /**
     * Handle Stripe payment result
     */
    func handleStripePaymentResult(_ result: PaymentSheetResult) {
        switch result {
        case .completed:
            paymentResult = "Order placed successfully! Check your orders to track status."
            paymentSuccess = true
            
            // Start the 30-second background timer for payment completion via OrderManager
            if let transactionId = self.transactionId,
               let clientSecret = self.pendingClientSecret {
                orderManager.startPaymentCaptureTimer(
                    transactionId: transactionId,
                    clientSecret: clientSecret,
                    paymentService: paymentService
                )
            }
            
            // Orders are now stored in Firestore by the backend with AUTHORIZED status
            // Refresh orders to show the new order
            Task {
                await orderManager.refreshOrders()
            }
            cartManager.clearCart()
            showingPaymentResult = true
        case .canceled:
            // User canceled the payment sheet - just dismiss silently
            // Don't show any result screen, just reset the processing state
            isProcessingPayment = false
            // Don't set showingPaymentResult = true to avoid showing "Payment Failed" screen
        case .failed(let error):
            paymentResult = "Payment failed: \(error.localizedDescription)"
            paymentSuccess = false
            showingPaymentResult = true
        }
    }
    
    /**
     * Format pickup time for display
     */
    func formatPickupTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    /**
     * Handle payment result dismissal
     */
    func handlePaymentResultDismiss() {
        showingPaymentResult = false
        if paymentSuccess {
            // Switch to Explore tab first, then dismiss checkout
            NotificationCenter.default.post(name: NSNotification.Name("SwitchToExploreTab"), object: nil)
        }
    }
    
    /**
     * Handle try again for failed payments
     */
    func handleTryAgain() {
        showingPaymentResult = false
        // Reset payment state for retry
        isProcessingPayment = false
        isProcessingApplePay = false
    }
    
    /**
     * Handle order cancellation
     */
    func handleOrderCancellation() {
        showingPaymentResult = false
    }
    
    // MARK: - Private Methods
    
    /**
     * Present PaymentSheet
     */
    private func presentPaymentSheet() {
        // Add a small delay to ensure any existing presentations are finished
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                self.paymentResult = "Unable to present payment sheet"
                self.paymentSuccess = false
                self.showingPaymentResult = true
                return
            }
            
            // Find the top-most view controller
            var topViewController = window.rootViewController
            while let presentedViewController = topViewController?.presentedViewController {
                topViewController = presentedViewController
            }
            
            guard let presentingViewController = topViewController else {
                self.paymentResult = "Unable to find presenting view controller"
                self.paymentSuccess = false
                self.showingPaymentResult = true
                return
            }
            
            self.paymentSheet?.present(from: presentingViewController) { [self] result in
                DispatchQueue.main.async {
                    self.stripePaymentResult = result
                    self.handleStripePaymentResult(result)
                }
            }
        }
    }
    
    /**
     * Setup observers for card entry and other events
     */
    private func setupObservers() {
    }
    
}

// MARK: - Design System

extension CheckoutViewModel {
    
    /**
     * Design system constants for the checkout view
     */
    enum Design {
        // Layout
        static let sectionSpacing: CGFloat = 16
        static let itemSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        
        // Cards
        static let cardCornerRadius: CGFloat = 12
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowOpacity: Double = 0.05
        
        // Buttons
        static let buttonCornerRadius: CGFloat = 12
        static let buttonPadding: CGFloat = 16
        
        // Typography
        static let titleFont: Font = .title2
        static let titleWeight: Font.Weight = .bold
        static let headlineFont: Font = .headline
        static let headlineWeight: Font.Weight = .medium
        static let bodyFont: Font = .body
        static let captionFont: Font = .caption
        
        // Colors
        static let backgroundColor: Color = Color(.systemGray6)
        static let cardBackgroundColor: Color = .white
        static let primaryTextColor: Color = .primary
        static let secondaryTextColor: Color = .secondary
        static let buttonTextColor: Color = .white
        
        // Payment buttons
        static let stripeButtonColor: Color = .blue
        static let applePayButtonColor: Color = .black
        static let disabledButtonColor: Color = .gray
    }
}
