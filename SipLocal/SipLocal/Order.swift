import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case submitted = "SUBMITTED"     // Order just placed, waiting for merchant
    case inProgress = "IN_PROGRESS"  // Merchant is preparing the order
    case ready = "READY"             // Order is ready for pickup
    case completed = "COMPLETED"     // Order has been picked up
    case cancelled = "CANCELLED"     // Order was cancelled
    case draft = "DRAFT"             // Order is in draft state (legacy)
    case pending = "PENDING"         // Order is pending (legacy)
    case active = "active"           // Legacy status for backward compatibility
}

struct Order: Codable, Identifiable {
    let id: String
    let date: Date
    let coffeeShop: CoffeeShop
    let items: [CartItem]
    let totalAmount: Double
    let transactionId: String
    let status: OrderStatus
    let receiptUrl: String? // Square receipt URL for this order
    let squareOrderId: String? // Square order ID for status fetching
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var shortDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter.string(from: date)
    }
}

class OrderManager: ObservableObject {
    @Published var orders: [Order] = []
    
    private let ordersKey = "SavedOrders"
    
    init() {
        loadOrders()
    }
    
    func addOrder(
        coffeeShop: CoffeeShop,
        items: [CartItem],
        totalAmount: Double,
        transactionId: String,
        receiptUrl: String? = nil, // New parameter, default nil for backward compatibility
        squareOrderId: String? = nil // Square order ID for status fetching
    ) {
        let order = Order(
            id: UUID().uuidString,
            date: Date(),
            coffeeShop: coffeeShop,
            items: items,
            totalAmount: totalAmount,
            transactionId: transactionId,
            status: .submitted, // Use SUBMITTED status for new orders
            receiptUrl: receiptUrl, // Pass to struct
            squareOrderId: squareOrderId // Pass Square order ID
        )
        
        orders.insert(order, at: 0) // Add to beginning for chronological order
        saveOrders()
    }
    
    func updateOrderStatus(orderId: String, newStatus: OrderStatus) {
        if let index = orders.firstIndex(where: { $0.id == orderId }) {
            // Create a new order with updated status
            let oldOrder = orders[index]
            let updatedOrder = Order(
                id: oldOrder.id,
                date: oldOrder.date,
                coffeeShop: oldOrder.coffeeShop,
                items: oldOrder.items,
                totalAmount: oldOrder.totalAmount,
                transactionId: oldOrder.transactionId,
                status: newStatus,
                receiptUrl: oldOrder.receiptUrl,
                squareOrderId: oldOrder.squareOrderId
            )
            
            orders[index] = updatedOrder
            saveOrders()
        }
    }
    
    func syncOrderStatusesWithSquare() async {
        print("🔄 OrderManager: Starting order status sync with Square...")
        
        let squareService = SquareAPIService.shared
        
        for order in orders {
            // Only sync orders that have a Square order ID
            guard let squareOrderId = order.squareOrderId else {
                continue
            }
            
            do {
                let newStatus = try await squareService.fetchOrderStatus(
                    orderId: squareOrderId,
                    merchantId: order.coffeeShop.merchantId
                )
                
                // Only update if status has changed
                if newStatus != order.status {
                    print("🔄 OrderManager: Updated order status from \(order.status) to \(newStatus) for \(order.coffeeShop.name)")
                    await MainActor.run {
                        self.updateOrderStatus(orderId: order.id, newStatus: newStatus)
                    }
                }
                
            } catch {
                print("❌ OrderManager: Failed to sync status for order at \(order.coffeeShop.name): \(error)")
                // Continue with other orders even if one fails
            }
        }
        
        print("🔄 OrderManager: Order status sync completed")
    }
    
    func removeOrder(_ order: Order) {
        orders.removeAll { $0.id == order.id }
        saveOrders()
    }
    
    func clearAllOrders() {
        orders.removeAll()
        saveOrders()
    }
    
    private func saveOrders() {
        if let encoded = try? JSONEncoder().encode(orders) {
            UserDefaults.standard.set(encoded, forKey: ordersKey)
        }
    }
    
    private func loadOrders() {
        if let data = UserDefaults.standard.data(forKey: ordersKey),
           let decoded = try? JSONDecoder().decode([Order].self, from: data) {
            orders = decoded
        }
    }
    
    // Helper computed properties
    var completedOrders: [Order] {
        orders.filter { $0.status == .completed }
    }
    
    var submittedOrders: [Order] {
        orders.filter { $0.status == .submitted }
    }
    
    var inProgressOrders: [Order] {
        orders.filter { $0.status == .inProgress }
    }
    
    var readyOrders: [Order] {
        orders.filter { $0.status == .ready }
    }
    
    var recentOrders: [Order] {
        Array(orders.prefix(5))
    }
    
    var totalSpent: Double {
        orders.reduce(0) { $0 + $1.totalAmount }
    }
}