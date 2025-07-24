import SwiftUI

struct PastOrdersView: View {
    @EnvironmentObject var orderManager: OrderManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showClearAllConfirmation = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if orderManager.orders.isEmpty {
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
                
                if !orderManager.orders.isEmpty {
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
                orderManager.clearAllOrders()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. All of your past orders will be permanently deleted.")
        }
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
                ForEach(orderManager.orders) { order in
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Main order info
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.coffeeShop.name)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
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
                }
                .padding(.horizontal)
                .padding(.bottom)
                .background(Color.white)
            }
        }
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// Preview
struct PastOrdersView_Previews: PreviewProvider {
    static var previews: some View {
        PastOrdersView()
            .environmentObject({
                let orderManager = OrderManager()
                // Add sample orders for preview
                orderManager.addOrder(
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
                        merchantId: "SAMPLE_MERCHANT_ID"
                    ),
                    items: [
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
                                merchantId: "SAMPLE_MERCHANT_ID"
                            ),
                            menuItem: MenuItem(name: "Cappuccino", price: 4.50, variations: nil, customizations: nil, imageURL: nil, modifierLists: nil),
                            category: "Coffee",
                            quantity: 2,
                            customizations: "Extra shot, oat milk"
                        )
                    ],
                    totalAmount: 9.00,
                    transactionId: "sq0idp-1234567890"
                )
                return orderManager
            }())
    }
}