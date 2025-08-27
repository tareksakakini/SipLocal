import SwiftUI

struct PastOrdersView: View {
    @EnvironmentObject var orderManager: OrderManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showClearAllConfirmation = false
    
    // Filter to get only past orders (completed and cancelled)
    private var pastOrders: [Order] {
        orderManager.orders.filter { [.completed, .cancelled].contains($0.status) }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if orderManager.isLoading {
                    loadingView
                } else if let errorMessage = orderManager.errorMessage {
                    errorView(message: errorMessage)
                } else if pastOrders.isEmpty {
                    emptyStateView
                } else {
                    ordersList
                }
            }
            .navigationTitle("Past Orders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
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
                
                if !pastOrders.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            showClearAllConfirmation = true
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .confirmationDialog(
            "Clear All Orders",
            isPresented: $showClearAllConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Orders", role: .destructive) {
                Task {
                    await orderManager.clearAllOrders()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. All of your past orders will be permanently deleted.")
        }
        .onAppear {
            // Debug: Check if orders are being fetched when view appears
            print("PastOrdersView: View appeared, checking orders...")
            Task {
                await orderManager.fetchOrders()
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Loading orders...")
                .font(.body)
                .foregroundColor(.secondary)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 60))
                    .foregroundColor(.orange)
                
                VStack(spacing: 8) {
                    Text("Error Loading Orders")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Button("Try Again") {
                Task {
                    await orderManager.fetchOrders()
                }
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 16) {
                Image(systemName: "cup.and.saucer")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Past Orders")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Your order history will appear here after you make your first purchase.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGray6))
    }
    
    private var ordersList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(pastOrders) { order in
                    OrderRow(order: order)
                }
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
}

struct OrderRow: View {
    let order: Order
    @State private var isExpanded = false
    @State private var showingCancelAlert = false
    @State private var isCancelling = false
    @EnvironmentObject var orderManager: OrderManager
    
    var body: some View {
        VStack(spacing: 0) {
            // Main order info
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(order.coffeeShop.name)
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        // Status indicator
                        statusBadge
                    }
                    
                    Text(order.coffeeShop.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    Text(order.formattedDate)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("$\(order.totalAmount, specifier: "%.2f")")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 4) {
                        Text("\(order.items.reduce(0) { $0 + $1.quantity }) items")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color.white)
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }
            
            // Expanded details
            if isExpanded {
                VStack(spacing: 16) {
                    Divider()
                    
                    // Order items
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Text("Items")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        ForEach(order.items) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.menuItem.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    if let customizations = item.customizations, !customizations.isEmpty {
                                        Text(customizations)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                // Show setup details briefly when available
                                if let sizeId = item.selectedSizeId {
                                    Text("Size: \(sizeId)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("×\(item.quantity)")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
                                Text("$\(item.totalPrice, specifier: "%.2f")")
                                    .font(.body)
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
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Transaction ID")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        
                        Text(order.transactionId)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.primary)
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
                            .font(.subheadline)
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
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red)
                            .cornerRadius(8)
                        }
                        .disabled(isCancelling)
                        .padding(.top, 8)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color.white)
            }
        }
        .cornerRadius(12)
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
            Image(systemName: statusIcon)
                .font(.caption)
            
            Text(statusDisplayText)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.1))
        .foregroundColor(statusColor)
        .cornerRadius(8)
    }
    
    private var statusDisplayText: String {
        switch order.status {
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
    
    private var statusIcon: String {
        switch order.status {
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
            return "clock.fill" // Legacy support
        }
    }
    
    private var statusColor: Color {
        switch order.status {
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
            return .blue // Legacy support
        }
    }
    
    private func cancelOrder() {
        isCancelling = true
        
        Task {
            do {
                try await orderManager.cancelOrder(paymentId: order.transactionId)
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

// Preview
struct PastOrdersView_Previews: PreviewProvider {
    static var previews: some View {
        PastOrdersView()
            .environmentObject(OrderManager())
    }
}