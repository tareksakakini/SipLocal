import SwiftUI

struct ActiveOrdersView: View {
    @EnvironmentObject var orderManager: OrderManager
    @Environment(\.presentationMode) var presentationMode
    
    // Get the most recent order of ALL orders (active or past)
    private var latestOrder: Order? {
        orderManager.orders.sorted { $0.date > $1.date }.first
    }
    
    // Get the most recent active order, but only if it's also the latest of ALL orders
    private var latestActiveOrder: Order? {
        guard let latest = latestOrder,
              [.authorized, .submitted, .inProgress, .ready].contains(latest.status) else {
            print("ActiveOrdersView: No active order - latest order status: \(latestOrder?.status.rawValue ?? "none")")
            return nil
        }
        print("ActiveOrdersView: Found active order: \(latest.id) with status: \(latest.status.rawValue)")
        return latest
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if orderManager.isLoading {
                    loadingView
                } else if let errorMessage = orderManager.errorMessage {
                    errorView(message: errorMessage)
                } else if let latestOrder = latestActiveOrder {
                    activeOrderView(order: latestOrder)
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Active Orders")
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
            }
        }
        .onAppear {
            print("ActiveOrdersView: View appeared, checking orders...")
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
            
            Text("Loading active orders...")
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
                    Text("Error Loading Active Orders")
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
                Image(systemName: "clock.badge.checkmark")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    Text("No Active Orders")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("You don't have any active orders at the moment. Only your most recent order will appear here if it's still active (authorized, submitted, in progress, or ready).")
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
    
    private func activeOrderView(order: Order) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Status indicator card
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: statusIcon(for: order.status))
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(statusColor(for: order.status))
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Order Status")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                                .fontWeight(.medium)
                            
                            Text(statusDisplayText(for: order.status))
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(statusColor(for: order.status))
                        }
                        
                        Spacer()
                    }
                    .padding()
                    .background(statusColor(for: order.status).opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Order details
                OrderRow(order: order)
            }
            .padding()
        }
        .background(Color(.systemGray6))
    }
    
    private func statusDisplayText(for status: OrderStatus) -> String {
        switch status {
        case .authorized:
            return "Authorized"
        case .submitted:
            return "Submitted"
        case .inProgress:
            return "In Progress"
        case .ready:
            return "Ready for Pickup"
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
    
    private func statusIcon(for status: OrderStatus) -> String {
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
    
    private func statusColor(for status: OrderStatus) -> Color {
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

// Preview
struct ActiveOrdersView_Previews: PreviewProvider {
    static var previews: some View {
        ActiveOrdersView()
            .environmentObject(OrderManager())
    }
}