import Foundation
import SwiftUI
import Combine

/**
 * PastOrdersViewModel - Manages the business logic and state for PastOrdersView.
 *
 * ## Responsibilities
 * - **Order Management**: Fetches and manages past orders (completed and cancelled)
 * - **State Management**: Manages loading, error, and order display states
 * - **Order Operations**: Handles order cancellation and clearing all orders
 * - **Data Filtering**: Filters orders to show only past orders
 * - **Error Handling**: Processes and exposes error messages from OrderManager
 *
 * ## Architecture
 * - **MVVM Pattern**: Decouples UI from business logic
 * - **Reactive Programming**: Uses @Published for UI updates
 * - **Dependency Injection**: Receives OrderManager dependency
 * - **Concurrency**: Uses async/await for order operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class PastOrdersViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showClearAllConfirmation = false
    @Published var orders: [Order] = []
    
    // MARK: - Private Properties
    
    private let orderManager: OrderManager
    
    // MARK: - Computed Properties
    
    /// Filter to get only past orders (completed and cancelled)
    var pastOrders: [Order] {
        orders.filter { [.completed, .cancelled].contains($0.status) }
    }
    
    var hasPastOrders: Bool {
        !pastOrders.isEmpty
    }
    
    // MARK: - Initialization
    
    /**
     * Initialize with OrderManager dependency
     */
    init(orderManager: OrderManager) {
        self.orderManager = orderManager
        setupOrderManagerObserver()
        print("📋 PastOrdersViewModel initialized")
    }
    
    deinit {
        print("📋 PastOrdersViewModel deinitialized")
    }
    
    // MARK: - Public Methods
    
    /**
     * Load past orders from OrderManager
     */
    func loadOrders() async {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        await orderManager.fetchOrders()
        
        await MainActor.run {
            updateOrderState()
            isLoading = false
        }
    }
    
    /**
     * Retry loading orders after an error
     */
    func retryLoading() async {
        await loadOrders()
    }
    
    /**
     * Clear all past orders
     */
    func clearAllOrders() async {
        await orderManager.clearAllOrders()
        await MainActor.run {
            updateOrderState()
        }
    }
    
    /**
     * Cancel a specific order
     */
    func cancelOrder(_ order: Order) async throws {
        try await orderManager.cancelOrder(paymentId: order.transactionId)
        await MainActor.run {
            updateOrderState()
        }
    }
    
    /**
     * Show clear all confirmation dialog
     */
    func showClearAllConfirmationDialog() {
        showClearAllConfirmation = true
    }
    
    /**
     * Hide clear all confirmation dialog
     */
    func hideClearAllConfirmationDialog() {
        showClearAllConfirmation = false
    }
    
    // MARK: - Private Methods
    
    /**
     * Setup observer for OrderManager state changes
     */
    private func setupOrderManagerObserver() {
        // Observe OrderManager's published properties
        orderManager.$orders
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateOrderState()
                }
            }
            .store(in: &cancellables)
        
        orderManager.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.isLoading = isLoading
            }
            .store(in: &cancellables)
        
        orderManager.$errorMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] errorMessage in
                self?.errorMessage = errorMessage
            }
            .store(in: &cancellables)
    }
    
    /**
     * Update order state from OrderManager
     */
    @MainActor
    private func updateOrderState() {
        orders = orderManager.orders
    }
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
}

// MARK: - Design System

extension PastOrdersViewModel {
    
    /**
     * Design constants for PastOrdersView
     */
    enum Design {
        
        // MARK: - Spacing
        static let sectionSpacing: CGFloat = 16
        static let itemSpacing: CGFloat = 12
        static let padding: CGFloat = 16
        static let cornerRadius: CGFloat = 12
        
        // MARK: - Colors
        static let backgroundColor = Color(.systemGray6)
        static let cardBackgroundColor = Color.white
        static let primaryTextColor = Color.primary
        static let secondaryTextColor = Color.secondary
        static let errorColor = Color.orange
        static let destructiveColor = Color.red
        
        // MARK: - Typography
        static let titleFont = Font.title2.weight(.semibold)
        static let headlineFont = Font.headline.weight(.semibold)
        static let bodyFont = Font.body
        static let captionFont = Font.caption
        static let caption2Font = Font.caption2
        
        // MARK: - Icons
        static let backIcon = "chevron.left"
        static let loadingIcon = "cup.and.saucer"
        static let errorIcon = "exclamationmark.triangle"
        static let emptyStateIcon = "cup.and.saucer"
        static let clearAllIcon = "trash"
        
        // MARK: - Text
        static let navigationTitle = "Past Orders"
        static let backButtonText = "Back"
        static let clearAllButtonText = "Clear All"
        static let loadingText = "Loading orders..."
        static let errorTitle = "Error Loading Orders"
        static let retryButtonText = "Try Again"
        static let emptyStateTitle = "No Past Orders"
        static let emptyStateMessage = "Your order history will appear here after you make your first purchase."
        static let clearAllConfirmationTitle = "Clear All Orders"
        static let clearAllConfirmationMessage = "This action cannot be undone. All of your past orders will be permanently deleted."
        static let clearAllActionText = "Clear All Orders"
        static let cancelActionText = "Cancel"
    }
}

// MARK: - Order Status Extensions

extension PastOrdersViewModel {
    
    /**
     * Get display text for order status
     */
    static func statusDisplayText(for status: OrderStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .submitted:
            return "Submitted"
        case .inProgress:
            return "In Progress"
        case .ready:
            return "Ready"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        case .draft:
            return "Draft"
        case .pending:
            return "Pending"
        case .active:
            return "Active"
        }
    }
    
    /**
     * Get icon for order status
     */
    static func statusIcon(for status: OrderStatus) -> String {
        switch status {
        case .authorized:
            return "clock.badge.checkmark.fill"
        case .submitted:
            return "doc.text"
        case .inProgress:
            return "clock.fill"
        case .ready:
            return "checkmark.circle.fill"
        case .completed:
            return "folder.fill"
        case .cancelled:
            return "xmark.circle.fill"
        case .draft:
            return "doc.text"
        case .pending:
            return "hourglass"
        case .active:
            return "clock.fill"
        }
    }
    
    /**
     * Get color for order status
     */
    static func statusColor(for status: OrderStatus) -> Color {
        switch status {
        case .authorized:
            return .orange
        case .submitted:
            return .orange
        case .inProgress:
            return .blue
        case .ready:
            return .green
        case .completed:
            return .gray
        case .cancelled:
            return .red
        case .draft:
            return .gray
        case .pending:
            return .orange
        case .active:
            return .blue
        }
    }
}
