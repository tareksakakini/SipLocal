/**
 * PaymentResultView.swift
 * SipLocal
 *
 * Payment result display view showing success/failure states,
 * order summary, pickup information, and transaction details.
 * Refactored with clean architecture and MVVM pattern.
 *
 * ## Features
 * - **Payment Result Display**: Success and failure state presentation
 * - **Order Summary**: Cart items and total amount display
 * - **Pickup Information**: Location and time details
 * - **Transaction Details**: Transaction ID and payment confirmation
 * - **User Actions**: Dismiss, retry, and cancel functionality
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses PaymentResultViewModel for business logic
 * - **Component-Based**: Uses extracted components for better maintainability
 * - **Clean Separation**: UI logic separated from business logic
 * - **Reactive State**: Responds to ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

struct PaymentResultView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: PaymentResultViewModel
    @EnvironmentObject var orderManager: OrderManager
    
    // MARK: - Initialization
    
    /**
     * Initialize with payment result data and callbacks
     */
    init(
        isSuccess: Bool,
        transactionId: String?,
        message: String,
        coffeeShop: CoffeeShop?,
        orderItems: [CartItem]?,
        totalAmount: Double?,
        pickupTime: Date?,
        onDismiss: @escaping () -> Void,
        onTryAgain: (() -> Void)? = nil,
        onCancel: (() -> Void)? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: PaymentResultViewModel(
            isSuccess: isSuccess,
            transactionId: transactionId,
            message: message,
            coffeeShop: coffeeShop,
            orderItems: orderItems,
            totalAmount: totalAmount,
            pickupTime: pickupTime,
            onDismiss: onDismiss,
            onTryAgain: onTryAgain,
            onCancel: onCancel
        ))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: PaymentResultViewModel.Design.mainSpacing) {
                    if viewModel.isSuccess {
                        successContent
                    } else {
                        failureContent
                    }
                }
                .padding(PaymentResultViewModel.Design.horizontalPadding)
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(PaymentResultViewModel.Design.backgroundColor)
        }
    }
    
    // MARK: - Success Content
    
    private var successContent: some View {
        VStack(spacing: PaymentResultViewModel.Design.mainSpacing) {
            Spacer().frame(height: PaymentResultViewModel.Design.topSpacer)
            
            // Success Header
            successHeader
            
            // Pickup Information Card
            if viewModel.hasCoffeeShop {
                pickupInformationCard
            }
            
            // Order Summary Card
            if viewModel.hasOrderItems {
                orderSummaryCard
            }
            
            // Transaction ID
            if viewModel.hasTransactionId {
                transactionIdSection
            }
            
            Spacer().frame(height: PaymentResultViewModel.Design.bottomSpacer)
            
            // Action Button
            continueButton
        }
    }
    
    /**
     * Success header with icon and title
     */
    private var successHeader: some View {
        VStack(spacing: PaymentResultViewModel.Design.cardSpacing) {
            Image(systemName: viewModel.successIconConfig.name)
                .font(.system(size: viewModel.successIconConfig.size))
                .foregroundColor(viewModel.successIconConfig.color)
            
            Text("Order Placed!")
                .font(PaymentResultViewModel.Design.titleFont)
                .fontWeight(PaymentResultViewModel.Design.titleWeight)
                .multilineTextAlignment(.center)
        }
    }
    
    /**
     * Pickup information card
     */
    private var pickupInformationCard: some View {
        VStack(alignment: .leading, spacing: PaymentResultViewModel.Design.itemSpacing) {
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.orange)
                Text("Pickup Location")
                    .font(PaymentResultViewModel.Design.headlineFont)
                    .fontWeight(PaymentResultViewModel.Design.headlineWeight)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(viewModel.coffeeShop?.name ?? "")
                    .font(PaymentResultViewModel.Design.bodyFont)
                    .fontWeight(PaymentResultViewModel.Design.bodyWeight)
                
                Text(viewModel.coffeeShop?.address ?? "")
                    .font(PaymentResultViewModel.Design.bodyFont)
                    .foregroundColor(PaymentResultViewModel.Design.secondaryTextColor)
                    .multilineTextAlignment(.leading)
                
                if let formattedPickupTime = viewModel.formattedPickupTime {
                    Divider()
                        .padding(.vertical, PaymentResultViewModel.Design.dividerPadding)
                    
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.blue)
                            .font(PaymentResultViewModel.Design.captionFont)
                        
                        Text("Pickup Time: \(formattedPickupTime)")
                            .font(PaymentResultViewModel.Design.bodyFont)
                            .fontWeight(PaymentResultViewModel.Design.bodyWeight)
                    }
                }
            }
        }
        .padding(PaymentResultViewModel.Design.horizontalPadding)
        .background(PaymentResultViewModel.Design.cardBackgroundColor)
        .cornerRadius(PaymentResultViewModel.Design.cardCornerRadius)
    }
    
    /**
     * Order summary card
     */
    private var orderSummaryCard: some View {
        VStack(spacing: PaymentResultViewModel.Design.cardSpacing) {
            HStack {
                Text("Order Summary")
                    .font(PaymentResultViewModel.Design.headlineFont)
                    .fontWeight(PaymentResultViewModel.Design.headlineWeight)
                Spacer()
            }
            
            VStack(spacing: PaymentResultViewModel.Design.itemSpacing) {
                ForEach(viewModel.orderItems ?? []) { item in
                    orderItemRow(item)
                    
                    if item.id != viewModel.orderItems?.last?.id {
                        Divider()
                    }
                }
                
                // Total
                if let formattedTotal = viewModel.formattedTotalAmount {
                    Divider()
                        .padding(.top, PaymentResultViewModel.Design.dividerPadding)
                    
                    HStack {
                        Text("Total")
                            .font(PaymentResultViewModel.Design.headlineFont)
                            .fontWeight(PaymentResultViewModel.Design.headlineWeight)
                        
                        Spacer()
                        
                        Text(formattedTotal)
                            .font(PaymentResultViewModel.Design.headlineFont)
                            .fontWeight(PaymentResultViewModel.Design.titleWeight)
                    }
                }
            }
        }
        .padding(PaymentResultViewModel.Design.horizontalPadding)
        .background(PaymentResultViewModel.Design.cardBackgroundColor)
        .cornerRadius(PaymentResultViewModel.Design.cardCornerRadius)
    }
    
    /**
     * Individual order item row
     */
    private func orderItemRow(_ item: CartItem) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.menuItem.name)
                    .font(PaymentResultViewModel.Design.bodyFont)
                    .fontWeight(PaymentResultViewModel.Design.bodyWeight)
                
                if let customizations = item.customizations, !customizations.isEmpty {
                    Text(customizations)
                        .font(PaymentResultViewModel.Design.captionFont)
                        .foregroundColor(PaymentResultViewModel.Design.secondaryTextColor)
                }
            }
            
            Spacer()
            
            Text("×\(item.quantity)")
                .font(PaymentResultViewModel.Design.bodyFont)
                .foregroundColor(PaymentResultViewModel.Design.secondaryTextColor)
            
            Text("$\(item.totalPrice, specifier: "%.2f")")
                .font(PaymentResultViewModel.Design.bodyFont)
                .fontWeight(PaymentResultViewModel.Design.bodyWeight)
        }
    }
    
    /**
     * Transaction ID section
     */
    private var transactionIdSection: some View {
        VStack(spacing: PaymentResultViewModel.Design.transactionIdPadding) {
            Text("Transaction ID")
                .font(PaymentResultViewModel.Design.captionFont)
                .foregroundColor(PaymentResultViewModel.Design.secondaryTextColor)
                .textCase(.uppercase)
                .fontWeight(PaymentResultViewModel.Design.captionWeight)
            
            Text(viewModel.transactionId ?? "")
                .font(PaymentResultViewModel.Design.captionFont)
                .fontDesign(.monospaced)
                .padding(.horizontal, PaymentResultViewModel.Design.transactionIdHorizontalPadding)
                .padding(.vertical, PaymentResultViewModel.Design.transactionIdVerticalPadding)
                .background(PaymentResultViewModel.Design.backgroundColor)
                .cornerRadius(PaymentResultViewModel.Design.transactionIdCornerRadius)
        }
    }
    
    /**
     * Continue button
     */
    private var continueButton: some View {
        Button(action: viewModel.handleDismiss) {
            Text("Continue")
                .fontWeight(PaymentResultViewModel.Design.headlineWeight)
                .frame(maxWidth: .infinity)
                .padding(PaymentResultViewModel.Design.buttonPadding)
                .background(PaymentResultViewModel.Design.primaryButtonColor)
                .foregroundColor(PaymentResultViewModel.Design.buttonTextColor)
                .cornerRadius(PaymentResultViewModel.Design.buttonCornerRadius)
        }
    }
    
    // MARK: - Failure Content
    
    private var failureContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Failure Header
            failureHeader
            
            Spacer()
            
            // Action Buttons
            failureActionButtons
        }
    }
    
    /**
     * Failure header with icon and message
     */
    private var failureHeader: some View {
        VStack(spacing: PaymentResultViewModel.Design.cardSpacing) {
            Image(systemName: viewModel.failureIconConfig.name)
                .font(.system(size: viewModel.failureIconConfig.size))
                .foregroundColor(viewModel.failureIconConfig.color)
            
            VStack(spacing: PaymentResultViewModel.Design.transactionIdPadding) {
                Text("Payment Failed")
                    .font(PaymentResultViewModel.Design.titleFont)
                    .fontWeight(PaymentResultViewModel.Design.titleWeight)
                    .multilineTextAlignment(.center)
                
                Text(viewModel.message)
                    .font(PaymentResultViewModel.Design.bodyFont)
                    .foregroundColor(PaymentResultViewModel.Design.secondaryTextColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, PaymentResultViewModel.Design.horizontalPadding)
            }
        }
    }
    
    /**
     * Failure action buttons
     */
    private var failureActionButtons: some View {
        VStack(spacing: PaymentResultViewModel.Design.itemSpacing) {
            Button(action: viewModel.handleTryAgain) {
                Text("Try Again")
                    .fontWeight(PaymentResultViewModel.Design.headlineWeight)
                    .frame(maxWidth: .infinity)
                    .padding(PaymentResultViewModel.Design.buttonPadding)
                    .background(PaymentResultViewModel.Design.primaryButtonColor)
                    .foregroundColor(PaymentResultViewModel.Design.buttonTextColor)
                    .cornerRadius(PaymentResultViewModel.Design.buttonCornerRadius)
            }
            
            Button(action: viewModel.handleDismiss) {
                Text("Go Back")
                    .fontWeight(PaymentResultViewModel.Design.bodyWeight)
                    .frame(maxWidth: .infinity)
                    .padding(PaymentResultViewModel.Design.buttonPadding)
                    .background(PaymentResultViewModel.Design.secondaryButtonColor)
                    .foregroundColor(PaymentResultViewModel.Design.secondaryButtonTextColor)
                    .cornerRadius(PaymentResultViewModel.Design.buttonCornerRadius)
            }
        }
    }
    
}

// MARK: - Preview

struct PaymentResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Success Preview
            PaymentResultView(
                isSuccess: true,
                transactionId: "stripe_1234567890",
                message: "Your payment has been processed successfully.",
                coffeeShop: CoffeeShop(
                    id: "sample1",
                    name: "Sample Coffee Shop",
                    address: "123 Main Street, Downtown, NY 10001",
                    latitude: 40.7128,
                    longitude: -74.0060,
                    phone: "(555) 123-4567",
                    website: "https://example.com",
                    description: "Sample description",
                    imageName: "sample",
                    stampName: "sample",
                    merchantId: "SAMPLE_MERCHANT_ID",
                    posType: .square
                ),
                orderItems: [
                    CartItem(
                        shop: CoffeeShop(
                            id: "sample1",
                            name: "Sample Coffee Shop",
                            address: "123 Main Street, Downtown, NY 10001",
                            latitude: 40.7128,
                            longitude: -74.0060,
                            phone: "(555) 123-4567",
                            website: "https://example.com",
                            description: "Sample description",
                            imageName: "sample",
                            stampName: "sample",
                            merchantId: "SAMPLE_MERCHANT_ID",
                            posType: .square
                        ),
                        menuItem: MenuItem(
                            id: "item_cappuccino",
                            name: "Cappuccino",
                            price: 4.50,
                            variations: nil,
                            customizations: nil,
                            imageURL: nil,
                            modifierLists: nil
                        ),
                        category: "Coffee",
                        quantity: 2,
                        customizations: "Extra shot, oat milk"
                    )
                ],
                totalAmount: 12.25,
                pickupTime: Date().addingTimeInterval(10 * 60),
                onDismiss: { print("Dismissed") },
                onTryAgain: nil,
                onCancel: { print("Cancelled") }
            )
            .environmentObject(OrderManager())
            .previewDisplayName("Success")
            
            // Failure Preview
            PaymentResultView(
                isSuccess: false,
                transactionId: nil,
                message: "Your payment could not be processed. Please check your payment method and try again.",
                coffeeShop: nil,
                orderItems: nil,
                totalAmount: nil,
                pickupTime: nil,
                onDismiss: { print("Dismissed") },
                onTryAgain: { print("Try Again") },
                onCancel: nil
            )
            .environmentObject(OrderManager())
            .previewDisplayName("Failure")
        }
    }
}



