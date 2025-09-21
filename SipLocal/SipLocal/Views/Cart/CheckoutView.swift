/**
 * CheckoutView.swift
 * SipLocal
 *
 * Main checkout view displaying cart summary, pickup time selection,
 * and payment processing functionality.
 * Refactored with clean architecture and MVVM pattern.
 *
 * ## Features
 * - **Cart Summary**: Display cart items with totals
 * - **Pickup Time Selection**: Time picker with business hours validation
 * - **Payment Processing**: Stripe, Apple Pay, and Square payment integration
 * - **Business Hours Validation**: Shop availability checking
 * - **Order Management**: Order submission and status tracking
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses CheckoutViewModel for business logic
 * - **Component-Based**: Uses extracted components (CheckoutItemRow, PickupTimeSelectionView)
 * - **Clean Separation**: UI logic separated from business logic
 * - **Reactive State**: Responds to ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import SquareInAppPaymentsSDK
import Combine
import StripePaymentSheet
import PassKit
import Stripe

struct CheckoutView: View {
    
    // MARK: - Properties
    
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: CheckoutViewModel
    
    // MARK: - Initialization
    
    /**
     * Initialize with dependencies
     */
    init() {
        // We'll initialize the ViewModel in onAppear with the environment dependencies
        self._viewModel = StateObject(wrappedValue: CheckoutViewModel(
            cartManager: CartManager(),
            orderManager: OrderManager(),
            authManager: AuthenticationManager()
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Cart Summary
                cartSummarySection
                
                // Payment Section
                paymentSection
            }
            .background(CheckoutViewModel.Design.backgroundColor)
            .navigationTitle("Checkout")
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .sheet(isPresented: $viewModel.showingCardEntry) {
                CardEntryView(delegate: viewModel.cardEntryDelegate)
            }
            .sheet(isPresented: $viewModel.showingTimePicker) {
                PickupTimeSelectionView(
                    selectedTime: $viewModel.selectedPickupTime, 
                    isPresented: $viewModel.showingTimePicker,
                    businessHoursInfo: cartManager.items.first.flatMap { cartManager.shopBusinessHours[$0.shop.id] }
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
            .alert("Shop is Closed", isPresented: $viewModel.showingClosedShopAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This coffee shop is currently closed. Please try again during business hours.")
            }
            .sheet(isPresented: $viewModel.showingPaymentResult) {
                PaymentResultView(
                    isSuccess: viewModel.paymentSuccess,
                    transactionId: viewModel.transactionId,
                    message: viewModel.paymentResult,
                    coffeeShop: viewModel.paymentSuccess ? viewModel.completedOrderShop : nil,
                    orderItems: viewModel.paymentSuccess ? viewModel.completedOrderItems : nil,
                    totalAmount: viewModel.paymentSuccess ? viewModel.completedOrderTotal : nil,
                    pickupTime: viewModel.paymentSuccess ? viewModel.selectedPickupTime : nil,
                    onDismiss: {
                        viewModel.handlePaymentResultDismiss()
                        if viewModel.paymentSuccess {
                            // Dismiss the checkout view after a brief delay to ensure tab switch completes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                presentationMode.wrappedValue.dismiss()
                            }
                        } else {
                            // For failed payments, just dismiss normally
                            presentationMode.wrappedValue.dismiss()
                        }
                    },
                    onTryAgain: viewModel.paymentSuccess ? nil : {
                        viewModel.handleTryAgain()
                    },
                    onCancel: viewModel.paymentSuccess ? {
                        viewModel.handleOrderCancellation()
                        presentationMode.wrappedValue.dismiss()
                    } : nil
                )
            }
            .onAppear {
                viewModel.updateDependencies(
                    cartManager: cartManager,
                    orderManager: orderManager,
                    authManager: authManager
                )
                viewModel.fetchBusinessHours()
            }
        }
    }
    
    // MARK: - View Components
    
    /**
     * Cart summary section with items and pickup time
     */
    private var cartSummarySection: some View {
        ScrollView {
            VStack(spacing: CheckoutViewModel.Design.sectionSpacing) {
                // Order Summary Header
                orderSummaryHeader
                
                // Coffee Shop Header
                if let firstItem = cartManager.items.first {
                    coffeeShopHeader(for: firstItem.shop)
                }
                
                // Cart Items
                cartItemsList
                
                // Pickup Time Section
                pickupTimeSection
            }
        }
    }
    
    /**
     * Order summary header
     */
    private var orderSummaryHeader: some View {
        HStack {
            Text("Order Summary")
                .font(CheckoutViewModel.Design.titleFont)
                .fontWeight(CheckoutViewModel.Design.titleWeight)
            Spacer()
        }
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
        .padding(.top, CheckoutViewModel.Design.verticalPadding)
    }
    
    /**
     * Coffee shop header
     */
    private func coffeeShopHeader(for shop: CoffeeShop) -> some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: "house.fill")
                    .font(.subheadline)
                    .foregroundColor(CheckoutViewModel.Design.secondaryTextColor)
                
                Text(shop.name)
                    .font(CheckoutViewModel.Design.headlineFont)
                    .fontWeight(CheckoutViewModel.Design.headlineWeight)
                    .foregroundColor(CheckoutViewModel.Design.primaryTextColor)
                
                Spacer()
            }
            
            Divider()
                .padding(.top, 4)
        }
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
        .padding(.bottom, 8)
    }
    
    /**
     * Cart items list
     */
    private var cartItemsList: some View {
        LazyVStack(spacing: CheckoutViewModel.Design.itemSpacing) {
            ForEach(cartManager.items) { item in
                CheckoutItemRow(cartItem: item)
            }
        }
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
    }
    
    /**
     * Pickup time selection section
     */
    private var pickupTimeSection: some View {
        VStack(spacing: CheckoutViewModel.Design.itemSpacing) {
            Button(action: {
                viewModel.showingTimePicker = true
            }) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pickup at")
                            .font(CheckoutViewModel.Design.captionFont)
                            .foregroundColor(CheckoutViewModel.Design.secondaryTextColor)
                        
                        Text(viewModel.formatPickupTime(viewModel.selectedPickupTime))
                            .font(CheckoutViewModel.Design.bodyFont)
                            .fontWeight(.semibold)
                            .foregroundColor(CheckoutViewModel.Design.primaryTextColor)
                    }
                    
                    Spacer()
                    
                    // Chevron with subtle background
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 28, height: 28)
                        
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CheckoutViewModel.Design.secondaryTextColor)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: CheckoutViewModel.Design.cardCornerRadius)
                        .fill(CheckoutViewModel.Design.cardBackgroundColor)
                        .shadow(
                            color: Color.black.opacity(CheckoutViewModel.Design.cardShadowOpacity),
                            radius: CheckoutViewModel.Design.cardShadowRadius,
                            x: 0,
                            y: 2
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CheckoutViewModel.Design.cardCornerRadius)
                        .stroke(Color(.systemGray5), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
        }
        .padding(.bottom, 20)
    }
    
    /**
     * Payment section with total and payment buttons
     */
    private var paymentSection: some View {
        VStack(spacing: CheckoutViewModel.Design.sectionSpacing) {
            Divider()
            
            // Total
            totalSection
            
            // Payment Buttons
            paymentButtonsSection
            
            Spacer(minLength: 16)
        }
        .background(CheckoutViewModel.Design.backgroundColor)
    }
    
    /**
     * Total price section
     */
    private var totalSection: some View {
        HStack {
            Text("Total")
                .font(CheckoutViewModel.Design.titleFont)
                .fontWeight(CheckoutViewModel.Design.titleWeight)
            
            Spacer()
            
            Text("$\(viewModel.totalPrice, specifier: "%.2f")")
                .font(CheckoutViewModel.Design.titleFont)
                .fontWeight(CheckoutViewModel.Design.titleWeight)
        }
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
    }
    
    /**
     * Payment buttons section
     */
    private var paymentButtonsSection: some View {
        VStack(spacing: CheckoutViewModel.Design.sectionSpacing) {
            // Stripe Payment Button
            stripePaymentButton
            
            // Apple Pay Button
            if PKPaymentAuthorizationController.canMakePayments(usingNetworks: [.visa, .masterCard, .amex, .discover]) {
                applePayButton
            }
        }
    }
    
    /**
     * Stripe payment button
     */
    private var stripePaymentButton: some View {
        Button(action: {
            viewModel.handleCheckout()
            if !viewModel.isCheckoutDisabled {
                viewModel.processStripePayment()
            }
        }) {
            HStack {
                if viewModel.isProcessingPayment {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Processing...")
                } else {
                    Image(systemName: "creditcard")
                    Text("Pay with Card")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CheckoutViewModel.Design.buttonPadding)
            .background(viewModel.isProcessingPayment ? CheckoutViewModel.Design.disabledButtonColor : CheckoutViewModel.Design.stripeButtonColor)
            .foregroundColor(CheckoutViewModel.Design.buttonTextColor)
            .cornerRadius(CheckoutViewModel.Design.buttonCornerRadius)
        }
        .disabled(viewModel.isProcessingPayment || viewModel.isProcessingApplePay)
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
    }
    
    /**
     * Apple Pay button
     */
    private var applePayButton: some View {
        Button(action: {
            viewModel.handleCheckout()
            if !viewModel.isCheckoutDisabled {
                viewModel.processApplePayment()
            }
        }) {
            HStack {
                if viewModel.isProcessingApplePay {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                    Text("Processing...")
                } else {
                    Image(systemName: "apple.logo")
                    Text("Pay")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(CheckoutViewModel.Design.buttonPadding)
            .background(viewModel.isProcessingApplePay ? CheckoutViewModel.Design.disabledButtonColor : CheckoutViewModel.Design.applePayButtonColor)
            .foregroundColor(CheckoutViewModel.Design.buttonTextColor)
            .cornerRadius(CheckoutViewModel.Design.buttonCornerRadius)
        }
        .disabled(viewModel.isProcessingPayment || viewModel.isProcessingApplePay)
        .padding(.horizontal, CheckoutViewModel.Design.horizontalPadding)
    }
    
    /**
     * Back navigation button
     */
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                Text("Back")
                    .font(.body)
            }
            .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

struct CheckoutView_Previews: PreviewProvider {
    static var previews: some View {
        CheckoutView()
            .environmentObject(CartManager())
            .environmentObject(OrderManager())
            .environmentObject(AuthenticationManager())
    }
}

// MARK: - Apple Pay Delegate Class

class ApplePayDelegate: NSObject, ObservableObject, PKPaymentAuthorizationControllerDelegate {
    private var cartManager: CartManager?
    private var authManager: AuthenticationManager?
    private var tokenService: TokenService?
    private var paymentService: PaymentService?
    private var orderManager: OrderManager?
    private var selectedPickupTime: Date?
    private var onPaymentResult: ((Bool, String, String?, [CartItem], Double, CoffeeShop?) -> Void)?
    
    func configure(
        cartManager: CartManager,
        authManager: AuthenticationManager,
        tokenService: TokenService,
        paymentService: PaymentService,
        orderManager: OrderManager,
        selectedPickupTime: Date,
        onPaymentResult: @escaping (Bool, String, String?, [CartItem], Double, CoffeeShop?) -> Void
    ) {
        print("🍎 ApplePayDelegate: Configuring with dependencies")
        self.cartManager = cartManager
        self.authManager = authManager
        self.tokenService = tokenService
        self.paymentService = paymentService
        self.orderManager = orderManager
        self.selectedPickupTime = selectedPickupTime
        self.onPaymentResult = onPaymentResult
        print("🍎 ApplePayDelegate: Configuration complete")
    }
    
    func paymentAuthorizationController(_ controller: PKPaymentAuthorizationController, didAuthorizePayment payment: PKPayment, handler completion: @escaping (PKPaymentAuthorizationResult) -> Void) {
        
        print("🍎 ApplePayDelegate: Payment authorization received")
        print("🍎 ApplePayDelegate: Payment token data size: \(payment.token.paymentData.count) bytes")
        
        guard let cartManager = cartManager,
              let authManager = authManager,
              let tokenService = tokenService,
              let paymentService = paymentService,
              let orderManager = orderManager,
              let selectedPickupTime = selectedPickupTime,
              let onPaymentResult = onPaymentResult else {
            print("❌ ApplePayDelegate: Missing required dependencies")
            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
            return
        }
        
        guard let firstItem = cartManager.items.first else {
            print("❌ ApplePayDelegate: No items in cart")
            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
            return
        }
        
        let merchantId = firstItem.shop.merchantId
        print("🍎 ApplePayDelegate: Processing payment for merchant: \(merchantId)")
        
        // Fetch user data before payment
        guard let userId = authManager.currentUser?.uid else {
            print("❌ ApplePayDelegate: User not logged in")
            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
            return
        }
        
        print("🍎 ApplePayDelegate: Fetching user data for userId: \(userId)")
        authManager.getUserData(userId: userId) { userData, error in
            guard let userData = userData else {
                print("❌ ApplePayDelegate: Failed to fetch user data - \(error ?? "Unknown error")")
                DispatchQueue.main.async {
                    completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                }
                return
            }
            
            print("🍎 ApplePayDelegate: User data retrieved - \(userData.fullName) (\(userData.email))")
            
            Task {
                do {
                    print("🍎 ApplePayDelegate: Fetching merchant tokens for: \(merchantId)")
                    print("🍎 ApplePayDelegate: POS Type: \(firstItem.shop.posType.rawValue)")
                    
                    // Use appropriate token service based on POS type
                    let oauthToken: String
                    if firstItem.shop.posType == .clover {
                        let cloverCredentials = try await tokenService.getCloverCredentials(merchantId: merchantId)
                        oauthToken = cloverCredentials.accessToken
                        print("🍎 ApplePayDelegate: Clover credentials retrieved successfully")
                    } else {
                        let squareCredentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
                        oauthToken = squareCredentials.oauth_token
                        print("🍎 ApplePayDelegate: Square credentials retrieved successfully")
                    }
                    
                    // Create Stripe Token from Apple Pay
                    print("🍎 ApplePayDelegate: Creating Stripe Token from Apple Pay...")
                    
                    // Convert amount to cents (avoiding floating point issues)
                    let amountDecimal = NSDecimalNumber(value: cartManager.totalPrice)
                    let amountInCents = amountDecimal.multiplying(by: NSDecimalNumber(value: 100)).intValue
                    
                    print("🍎 ApplePayDelegate: Amount: $\(cartManager.totalPrice) = \(amountInCents) cents")
                    
                    // Create Stripe Token from Apple Pay payment
                    let tokenResult = await withCheckedContinuation { continuation in
                        STPAPIClient.shared.createToken(with: payment) { token, error in
                            if let error = error {
                                print("❌ ApplePayDelegate: Failed to create Stripe Token: \(error.localizedDescription)")
                                continuation.resume(returning: Result<STPToken, Error>.failure(error))
                            } else if let token = token {
                                print("✅ ApplePayDelegate: Stripe Token created: \(token.tokenId)")
                                continuation.resume(returning: Result<STPToken, Error>.success(token))
                            } else {
                                let unknownError = NSError(domain: "ApplePayError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error creating Token"])
                                continuation.resume(returning: Result<STPToken, Error>.failure(unknownError))
                            }
                        }
                    }
                    
                    let stripeToken: STPToken
                    switch tokenResult {
                    case .success(let token):
                        stripeToken = token
                    case .failure(let error):
                        onPaymentResult(
                            false,
                            "Failed to create payment token: \(error.localizedDescription)",
                            nil,
                            [],
                            0.0,
                            nil
                        )
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                        return
                    }
                    
                    print("🍎 ApplePayDelegate: Calling processApplePayPayment with:")
                    print("  - Amount: \(amountInCents) cents")
                    print("  - Merchant ID: \(merchantId)")
                    print("  - Customer: \(userData.fullName) (\(userData.email))")
                    print("  - Items count: \(cartManager.items.count)")
                    print("  - Token ID: \(stripeToken.tokenId)")
                    
                    let result = await paymentService.processApplePayPayment(
                        tokenId: stripeToken.tokenId,
                        amount: amountInCents,
                        merchantId: merchantId,
                        oauthToken: oauthToken,
                        cartItems: cartManager.items,
                        customerName: userData.fullName,
                        customerEmail: userData.email,
                        userId: userId,
                        coffeeShop: cartManager.items.first!.shop,
                        pickupTime: selectedPickupTime
                    )
                    
                    await MainActor.run {
                        switch result {
                        case .success(let transaction):
                            print("✅ ApplePayDelegate: Payment authorized!")
                            print("  - Transaction ID: \(transaction.transactionId)")
                            print("  - Status: \(transaction.status ?? "AUTHORIZED")")
                            print("  - Message: \(transaction.message)")
                            
                            // Start the 30-second capture timer for Apple Pay
                            // For Apple Pay, we always start the capture timer since it's always authorized first
                            print("🕒 Starting Apple Pay capture timer for transaction: \(transaction.transactionId)")
                            orderManager.startApplePayCaptureTimer(
                                transactionId: transaction.transactionId,
                                paymentService: paymentService
                            )
                            
                            // Refresh orders to show the new order
                            Task {
                                await orderManager.refreshOrders()
                            }
                            
                            onPaymentResult(
                                true,
                                transaction.message,
                                transaction.transactionId,
                                cartManager.items,
                                cartManager.totalPrice,
                                cartManager.items.first?.shop
                            )
                            
                            completion(PKPaymentAuthorizationResult(status: .success, errors: []))
                            
                        case .failure(let error):
                            print("❌ ApplePayDelegate: Payment failed with error:")
                            print("  - Error: \(error.localizedDescription)")
                            
                            onPaymentResult(
                                false,
                                error.localizedDescription,
                                nil,
                                [],
                                0.0,
                                nil
                            )
                            completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                        }
                    }
                } catch {
                    print("❌ ApplePayDelegate: Exception during payment processing:")
                    print("  - Error: \(error.localizedDescription)")
                    
                    await MainActor.run {
                        onPaymentResult(
                            false,
                            "Failed to retrieve payment credentials: \(error.localizedDescription)",
                            nil,
                            [],
                            0.0,
                            nil
                        )
                        completion(PKPaymentAuthorizationResult(status: .failure, errors: []))
                    }
                }
            }
        }
    }
    
    func paymentAuthorizationControllerDidFinish(_ controller: PKPaymentAuthorizationController) {
        print("🍎 ApplePayDelegate: Payment authorization finished")
        controller.dismiss {
            print("🍎 ApplePayDelegate: Apple Pay sheet dismissed")
            // The completion will be handled by the callback
        }
    }
}

// 2. Create a UIViewControllerRepresentable to wrap the Square SDK's view controller
struct CardEntryView: UIViewControllerRepresentable {
    var delegate: SQIPCardEntryViewControllerDelegate
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Customize the card entry form theme
        let theme = SQIPTheme()
        theme.tintColor = .black
        theme.saveButtonTitle = "Pay"
        
        let cardEntryViewController = SQIPCardEntryViewController(theme: theme)
        cardEntryViewController.delegate = delegate
        
        let navigationController = UINavigationController(rootViewController: cardEntryViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
}


struct CheckoutItemRow: View {
    let cartItem: CartItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cartItem.menuItem.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let customizations = cartItem.customizations, !customizations.isEmpty {
                    Text(customizations)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("×\(cartItem.quantity)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("$\(cartItem.totalPrice, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct PickupTimeSelectionView: View {
    @Binding var selectedTime: Date
    @Binding var isPresented: Bool
    @State private var tempTime: Date
    let businessHoursInfo: BusinessHoursInfo?
    
    init(selectedTime: Binding<Date>, isPresented: Binding<Bool>, businessHoursInfo: BusinessHoursInfo? = nil) {
        self._selectedTime = selectedTime
        self._isPresented = isPresented
        self._tempTime = State(initialValue: selectedTime.wrappedValue)
        self.businessHoursInfo = businessHoursInfo
    }
    
    private var timeRange: ClosedRange<Date> {
        let now = Date()
        let calendar = Calendar.current
        
        // Get today's closing time
        let today = calendar.component(.weekday, from: now)
        let dayOfWeek = convertWeekdayToSquareFormat(today)
        
        if let businessHoursInfo = businessHoursInfo,
           let todayPeriods = businessHoursInfo.weeklyHours[dayOfWeek],
           !todayPeriods.isEmpty {
            
            // Find the latest closing time for today
            var latestClosingTime: (hour: Int, minute: Int) = (0, 0)
            var latestClosingTimeString = ""
            
            for period in todayPeriods {
                let closingTime = parseTimeString(period.endTime)
                let currentLatest = latestClosingTime.hour * 60 + latestClosingTime.minute
                let periodClosing = closingTime.hour * 60 + closingTime.minute
                
                print("Debug - Period: \(period.startTime) to \(period.endTime)")
                print("Debug - Parsed closing: \(closingTime.hour):\(closingTime.minute) (\(periodClosing) minutes)")
                print("Debug - Current latest: \(latestClosingTime.hour):\(latestClosingTime.minute) (\(currentLatest) minutes)")
                
                if periodClosing > currentLatest {
                    latestClosingTime = closingTime
                    latestClosingTimeString = period.endTime
                    print("Debug - New latest: \(latestClosingTime.hour):\(latestClosingTime.minute)")
                }
            }
            
            print("Debug - Final latest closing time: \(latestClosingTime.hour):\(latestClosingTime.minute)")
            
            // Create closing date for today
            var closingComponents = calendar.dateComponents([.year, .month, .day], from: now)
            closingComponents.hour = latestClosingTime.hour
            closingComponents.minute = latestClosingTime.minute
            closingComponents.second = 0
            
            if let todayClosing = calendar.date(from: closingComponents) {
                // Ensure closing time is after current time
                if todayClosing > now {
                    return now...todayClosing
                }
            }
        }
        
        // Fallback: allow up to 24 hours from now
        let maxTime = now.addingTimeInterval(24 * 60 * 60)
        return now...maxTime
    }
    
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int) {
        // Handle empty or invalid time strings
        guard !timeString.isEmpty else { return (0, 0) }
        
        let components = timeString.split(separator: ":")
        guard components.count >= 2 else { return (0, 0) }
        
        let hour = Int(components[0]) ?? 0
        let minute = Int(components[1]) ?? 0
        
        // Validate hour and minute ranges
        let validHour = max(0, min(23, hour))
        let validMinute = max(0, min(59, minute))
        
        return (validHour, validMinute)
    }
    
    private func convertWeekdayToSquareFormat(_ weekday: Int) -> String {
        switch weekday {
        case 1: return "SUN"
        case 2: return "MON"
        case 3: return "TUE"
        case 4: return "WED"
        case 5: return "THU"
        case 6: return "FRI"
        case 7: return "SAT"
        default: return "MON"
        }
    }
    
    private func getClosingTimeString() -> String? {
        guard let businessHoursInfo = businessHoursInfo else { return nil }
        
        let today = Calendar.current.component(.weekday, from: Date())
        let dayOfWeek = convertWeekdayToSquareFormat(today)
        
        guard let todayPeriods = businessHoursInfo.weeklyHours[dayOfWeek],
              !todayPeriods.isEmpty else { return nil }
        
        // Find the latest closing time
        var latestClosingTime: (hour: Int, minute: Int) = (0, 0)
        var latestClosingTimeString = ""
        
        for period in todayPeriods {
            let closingTime = parseTimeString(period.endTime)
            let currentLatest = latestClosingTime.hour * 60 + latestClosingTime.minute
            let periodClosing = closingTime.hour * 60 + closingTime.minute
            
            if periodClosing > currentLatest {
                latestClosingTime = closingTime
                latestClosingTimeString = period.endTime
            }
        }
        
        // For debugging, let's also show the original time string
        print("Debug - Original closing time string: \(latestClosingTimeString)")
        print("Debug - Parsed closing time: \(latestClosingTime.hour):\(latestClosingTime.minute)")
        
        // Format the time for display
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        
        var components = DateComponents()
        components.hour = latestClosingTime.hour
        components.minute = latestClosingTime.minute
        
        if let timeDate = Calendar.current.date(from: components) {
            return formatter.string(from: timeDate)
        }
        
        return "\(latestClosingTime.hour):\(String(format: "%02d", latestClosingTime.minute))"
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                DatePicker(
                    "",
                    selection: $tempTime,
                    in: timeRange,
                    displayedComponents: [.hourAndMinute]
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .padding()
                
                // Show closing time info if available
                if let closingTimeString = getClosingTimeString() {
                    Text("Shop closes at \(closingTimeString)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.bottom)
                }
            }
            .navigationTitle("Pickup Time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        // Ensure the selected time is on today's date
                        let calendar = Calendar.current
                        let timeComponents = calendar.dateComponents([.hour, .minute], from: tempTime)
                        let todayWithSelectedTime = calendar.dateBySettingTime(of: Date(), hour: timeComponents.hour ?? 0, minute: timeComponents.minute ?? 0)
                        selectedTime = todayWithSelectedTime ?? tempTime
                        isPresented = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

extension Calendar {
    func dateBySettingTime(of date: Date, hour: Int, minute: Int) -> Date? {
        var components = self.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        return self.date(from: components)
    }
}


