/**
 * PaymentResultViewModel.swift
 * SipLocal
 *
 * ViewModel for PaymentResultView - handles payment result display logic,
 * order summary formatting, and user interaction management.
 *
 * ## Features
 * - **Payment Result Management**: Success and failure state handling
 * - **Order Summary Formatting**: Cart items and total display logic
 * - **Pickup Information**: Location and time formatting
 * - **Transaction Details**: Transaction ID display and formatting
 * - **User Actions**: Dismiss, retry, and cancel action handling
 * - **State Management**: Reactive UI state with @Published properties
 *
 * ## Architecture
 * - **MVVM Pattern**: Separates business logic from UI
 * - **Dependency Injection**: Receives payment result data and callbacks
 * - **Reactive State**: Uses @Published for UI updates
 * - **Error Boundaries**: Structured error handling for payment results
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

/**
 * ViewModel for PaymentResultView
 * 
 * Manages payment result display, order summary formatting,
 * and user interaction coordination.
 */
@MainActor
class PaymentResultViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Payment result state
    @Published var isSuccess: Bool
    @Published var message: String
    @Published var transactionId: String?
    
    /// Order details
    @Published var coffeeShop: CoffeeShop?
    @Published var orderItems: [CartItem]?
    @Published var totalAmount: Double?
    @Published var pickupTime: Date?
    
    /// Action callbacks
    private let onDismiss: () -> Void
    private let onTryAgain: (() -> Void)?
    private let onCancel: (() -> Void)?
    
    // MARK: - Computed Properties
    
    /**
     * Formatted pickup time string
     */
    var formattedPickupTime: String? {
        guard let pickupTime = pickupTime else { return nil }
        return formatPickupTime(pickupTime)
    }
    
    /**
     * Formatted total amount string
     */
    var formattedTotalAmount: String? {
        guard let totalAmount = totalAmount else { return nil }
        return String(format: "$%.2f", totalAmount)
    }
    
    /**
     * Check if order items exist and are not empty
     */
    var hasOrderItems: Bool {
        guard let orderItems = orderItems else { return false }
        return !orderItems.isEmpty
    }
    
    /**
     * Check if coffee shop information is available
     */
    var hasCoffeeShop: Bool {
        return coffeeShop != nil
    }
    
    /**
     * Check if transaction ID is available
     */
    var hasTransactionId: Bool {
        return transactionId != nil
    }
    
    /**
     * Success icon configuration
     */
    var successIconConfig: (name: String, color: Color, size: CGFloat) {
        return (name: "checkmark.circle.fill", color: .green, size: 80)
    }
    
    /**
     * Failure icon configuration
     */
    var failureIconConfig: (name: String, color: Color, size: CGFloat) {
        return (name: "xmark.circle.fill", color: .red, size: 80)
    }
    
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
        self.isSuccess = isSuccess
        self.transactionId = transactionId
        self.message = message
        self.coffeeShop = coffeeShop
        self.orderItems = orderItems
        self.totalAmount = totalAmount
        self.pickupTime = pickupTime
        self.onDismiss = onDismiss
        self.onTryAgain = onTryAgain
        self.onCancel = onCancel
    }
    
    // MARK: - Public Methods
    
    /**
     * Handle dismiss action
     */
    func handleDismiss() {
        onDismiss()
    }
    
    /**
     * Handle try again action
     */
    func handleTryAgain() {
        if let onTryAgain = onTryAgain {
            onTryAgain()
        } else {
            onDismiss()
        }
    }
    
    /**
     * Handle cancel action
     */
    func handleCancel() {
        onCancel?()
    }
    
    // MARK: - Private Methods
    
    /**
     * Format pickup time for display
     */
    private func formatPickupTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Design System

extension PaymentResultViewModel {
    
    /**
     * Design system constants for PaymentResultView
     */
    enum Design {
        // Layout
        static let mainSpacing: CGFloat = 24
        static let cardSpacing: CGFloat = 16
        static let itemSpacing: CGFloat = 12
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        
        // Cards
        static let cardCornerRadius: CGFloat = 12
        static let cardBackgroundColor: Color = .white
        
        // Buttons
        static let buttonCornerRadius: CGFloat = 12
        static let buttonPadding: CGFloat = 16
        static let primaryButtonColor: Color = .black
        static let secondaryButtonColor: Color = Color(.systemGray6)
        
        // Icons
        static let successIconSize: CGFloat = 80
        static let successIconColor: Color = .green
        static let failureIconSize: CGFloat = 80
        static let failureIconColor: Color = .red
        
        // Typography
        static let titleFont: Font = .title
        static let titleWeight: Font.Weight = .bold
        static let headlineFont: Font = .headline
        static let headlineWeight: Font.Weight = .semibold
        static let bodyFont: Font = .body
        static let bodyWeight: Font.Weight = .medium
        static let captionFont: Font = .caption
        static let captionWeight: Font.Weight = .medium
        
        // Colors
        static let backgroundColor: Color = Color(.systemGray6)
        static let primaryTextColor: Color = .primary
        static let secondaryTextColor: Color = .secondary
        static let buttonTextColor: Color = .white
        static let secondaryButtonTextColor: Color = .primary
        
        // Spacing
        static let topSpacer: CGFloat = 20
        static let bottomSpacer: CGFloat = 20
        static let dividerPadding: CGFloat = 4
        static let transactionIdPadding: CGFloat = 8
        static let transactionIdHorizontalPadding: CGFloat = 16
        static let transactionIdVerticalPadding: CGFloat = 8
        static let transactionIdCornerRadius: CGFloat = 8
    }
}
