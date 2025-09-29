import SwiftUI

/**
 * PastOrdersView - Displays the user's past orders (completed and cancelled).
 *
 * ## Features
 * - **Order History**: Shows completed and cancelled orders
 * - **Order Details**: Expandable order rows with item details
 * - **Order Management**: Cancel orders and clear all orders
 * - **Error Handling**: Displays loading states and error messages
 * - **Empty State**: Shows helpful message when no orders exist
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses PastOrdersViewModel for business logic
 * - **Design System**: Centralized styling constants
 * - **Component-Based**: Reusable UI components
 * - **Reactive UI**: Updates automatically with ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
struct PastOrdersView: View {
    
    // MARK: - Properties
    
    @StateObject private var viewModel: PastOrdersViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // MARK: - Initialization
    
    init(orderManager: OrderManager) {
        self._viewModel = StateObject(wrappedValue: PastOrdersViewModel(orderManager: orderManager))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                contentSection
            }
            .navigationTitle(PastOrdersViewModel.Design.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
                
                if viewModel.hasPastOrders {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        clearAllButton
                    }
                }
            }
        }
        .confirmationDialog(
            PastOrdersViewModel.Design.clearAllConfirmationTitle,
            isPresented: $viewModel.showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button(PastOrdersViewModel.Design.clearAllActionText, role: .destructive) {
                Task {
                    await viewModel.clearAllOrders()
                }
            }
            Button(PastOrdersViewModel.Design.cancelActionText, role: .cancel) { }
        } message: {
            Text(PastOrdersViewModel.Design.clearAllConfirmationMessage)
        }
        .task {
            await viewModel.loadOrders()
        }
    }
    
    // MARK: - Content Sections
    
    private var contentSection: some View {
        Group {
            if viewModel.isLoading {
                loadingView
            } else if let errorMessage = viewModel.errorMessage {
                errorView(message: errorMessage)
            } else if viewModel.pastOrders.isEmpty {
                emptyStateView
            } else {
                ordersList
            }
        }
    }
    
    // MARK: - Toolbar Components
    
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: 4) {
                Image(systemName: PastOrdersViewModel.Design.backIcon)
                    .font(.system(size: 16, weight: .medium))
                Text(PastOrdersViewModel.Design.backButtonText)
                    .font(PastOrdersViewModel.Design.bodyFont)
            }
            .foregroundColor(PastOrdersViewModel.Design.primaryTextColor)
        }
    }
    
    private var clearAllButton: some View {
        Button(PastOrdersViewModel.Design.clearAllButtonText) {
            viewModel.showClearAllConfirmationDialog()
        }
        .foregroundColor(PastOrdersViewModel.Design.destructiveColor)
    }
    
    // MARK: - Content Views
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text(PastOrdersViewModel.Design.loadingText)
                .font(PastOrdersViewModel.Design.bodyFont)
                .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PastOrdersViewModel.Design.backgroundColor)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: PastOrdersViewModel.Design.errorIcon)
                    .font(.system(size: 60))
                    .foregroundColor(PastOrdersViewModel.Design.errorColor)
                
                VStack(spacing: 8) {
                    Text(PastOrdersViewModel.Design.errorTitle)
                        .font(PastOrdersViewModel.Design.titleFont)
                    
                    Text(message)
                        .font(PastOrdersViewModel.Design.bodyFont)
                        .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Button(PastOrdersViewModel.Design.retryButtonText) {
                Task {
                    await viewModel.retryLoading()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PastOrdersViewModel.Design.backgroundColor)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: PastOrdersViewModel.Design.emptyStateIcon)
                    .font(.system(size: 60))
                    .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                
                VStack(spacing: 8) {
                    Text(PastOrdersViewModel.Design.emptyStateTitle)
                        .font(PastOrdersViewModel.Design.titleFont)
                    
                    Text(PastOrdersViewModel.Design.emptyStateMessage)
                        .font(PastOrdersViewModel.Design.bodyFont)
                        .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(PastOrdersViewModel.Design.backgroundColor)
    }
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: PastOrdersViewModel.Design.sectionSpacing) {
                ForEach(viewModel.pastOrders) { order in
                    OrderRow(order: order, viewModel: viewModel)
                }
            }
            .padding(PastOrdersViewModel.Design.padding)
        }
        .background(PastOrdersViewModel.Design.backgroundColor)
    }
}

/**
 * OrderRow - Displays individual order information with expandable details.
 *
 * ## Features
 * - **Order Summary**: Shows shop name, date, total, and item count
 * - **Expandable Details**: Tap to show order items and transaction details
 * - **Order Actions**: Cancel orders and view receipts
 * - **Status Display**: Visual status indicators with colors and icons
 *
 * ## Architecture
 * - **Component-Based**: Reusable order display component
 * - **Design System**: Uses centralized styling constants
 * - **State Management**: Manages expansion and cancellation states
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
struct OrderRow: View {
    
    // MARK: - Properties
    
    let order: Order
    let viewModel: PastOrdersViewModel?
    @EnvironmentObject private var orderManager: OrderManager
    
    @State private var isExpanded = false
    @State private var showingCancelAlert = false
    @State private var isCancelling = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main order info
            HStack(spacing: PastOrdersViewModel.Design.itemSpacing) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(order.coffeeShop.name)
                            .font(PastOrdersViewModel.Design.headlineFont)
                        
                        Spacer()
                        
                        // Status indicator
                        statusBadge
                    }
                    
                    Text(order.coffeeShop.address)
                        .font(PastOrdersViewModel.Design.captionFont)
                        .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                        .lineLimit(1)
                    
                    Text(order.formattedDate)
                        .font(PastOrdersViewModel.Design.captionFont)
                        .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(order.totalAmount, specifier: "%.2f")")
                        .font(PastOrdersViewModel.Design.headlineFont)
                    
                    HStack(spacing: 4) {
                        Text("\(order.items.reduce(0) { $0 + $1.quantity }) items")
                            .font(PastOrdersViewModel.Design.captionFont)
                            .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(PastOrdersViewModel.Design.captionFont)
                            .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                    }
                }
            }
            .padding(PastOrdersViewModel.Design.padding)
            .background(PastOrdersViewModel.Design.cardBackgroundColor)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(spacing: PastOrdersViewModel.Design.sectionSpacing) {
                    Divider()
                    
                    // Order items
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(PastOrdersViewModel.Design.captionFont)
                                .foregroundColor(.orange)
                            Text("Items")
                                .font(PastOrdersViewModel.Design.captionFont)
                                .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                                .textCase(.uppercase)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        ForEach(order.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.menuItem.name)
                                        .font(PastOrdersViewModel.Design.bodyFont)
                                        .fontWeight(.medium)
                                    
                                    if let customizations = item.customizations, !customizations.isEmpty {
                                        Text(customizations)
                                            .font(PastOrdersViewModel.Design.captionFont)
                                            .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                                    }
                                }
                                
                                Spacer()
                                
                                // Show setup details briefly when available
                                if let sizeId = item.selectedSizeId {
                                    Text("Size: \(sizeId)")
                                        .font(PastOrdersViewModel.Design.caption2Font)
                                        .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                                }
                                Text("×\(item.quantity)")
                                    .font(PastOrdersViewModel.Design.bodyFont)
                                    .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                                
                                Text("$\(item.totalPrice, specifier: "%.2f")")
                                    .font(PastOrdersViewModel.Design.bodyFont)
                                    .fontWeight(.medium)
                            }
                            .padding(.bottom, 2)
                        }
                    }
                    
                    // Transaction ID
                    Divider()
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "creditcard")
                                .font(PastOrdersViewModel.Design.captionFont)
                                .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                            Text("Transaction ID")
                                .font(PastOrdersViewModel.Design.captionFont)
                                .foregroundColor(PastOrdersViewModel.Design.secondaryTextColor)
                                .textCase(.uppercase)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        Text(order.transactionId)
                            .font(PastOrdersViewModel.Design.captionFont)
                            .fontDesign(.monospaced)
                            .foregroundColor(PastOrdersViewModel.Design.primaryTextColor)
                    }
                    // Show View Receipt button if receiptUrl is present
                    if let receiptUrl = order.receiptUrl, let url = URL(string: receiptUrl) {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            HStack {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text("View Receipt")
                            }
                            .font(PastOrdersViewModel.Design.captionFont)
                            .foregroundColor(.blue)
                            .padding(.top, 4)
                        }
                    }
                    
                    // Show Cancel button for authorized orders
                    if order.status == .authorized {
                        Divider()
                            .padding(.top, 8)
                        
                        Button(action: {
                            showingCancelAlert = true
                        }) {
                            HStack {
                                if isCancelling {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("Cancelling...")
                                } else {
                                    Image(systemName: "xmark.circle")
                                    Text("Cancel Order")
                                }
                            }
                            .font(PastOrdersViewModel.Design.captionFont)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(PastOrdersViewModel.Design.destructiveColor)
                            .cornerRadius(PastOrdersViewModel.Design.cornerRadius)
                        }
                        .disabled(isCancelling)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal, PastOrdersViewModel.Design.padding)
                .padding(.bottom, PastOrdersViewModel.Design.padding)
                .background(PastOrdersViewModel.Design.cardBackgroundColor)
            }
        }
        .cornerRadius(PastOrdersViewModel.Design.cornerRadius)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        .alert("Cancel Order?", isPresented: $showingCancelAlert) {
            Button("Cancel Order", role: .destructive) {
                cancelOrder()
            }
            Button("Keep Order", role: .cancel) {}
        } message: {
            Text("Are you sure you want to cancel this order? Your payment authorization will be cancelled and you won't be charged.")
        }
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: PastOrdersViewModel.statusIcon(for: order.status))
                .font(PastOrdersViewModel.Design.captionFont)
            
            Text(PastOrdersViewModel.statusDisplayText(for: order.status))
                .font(PastOrdersViewModel.Design.captionFont)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(PastOrdersViewModel.statusColor(for: order.status).opacity(0.1))
        .foregroundColor(PastOrdersViewModel.statusColor(for: order.status))
        .cornerRadius(8)
    }
    
    private func cancelOrder() {
        isCancelling = true
        
        Task {
            do {
                if let viewModel {
                    try await viewModel.cancelOrder(order)
                } else {
                    try await orderManager.cancelOrder(paymentId: order.transactionId)
                }
                await MainActor.run {
                    isCancelling = false
                    // Order status will be updated automatically via real-time listener
                }
            } catch {
                await MainActor.run {
                    isCancelling = false
                    // Could show an error alert here if needed
                    print("Failed to cancel order: \(error)")
                }
            }
        }
    }
}

// MARK: - Preview

struct PastOrdersView_Previews: PreviewProvider {
    static var previews: some View {
        let manager = OrderManager()
        return PastOrdersView(orderManager: manager)
            .environmentObject(manager)
    }
}
