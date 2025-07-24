import Foundation

struct Order: Codable, Identifiable {
    let id: String
    let date: Date
    let coffeeShop: CoffeeShop
    let items: [CartItem]
    let totalAmount: Double
    let transactionId: String
    let status: OrderStatus
    let receiptUrl: String? // Square receipt URL for this order
    
    enum OrderStatus: String, Codable, CaseIterable {
        case completed = "completed"
        case pending = "pending"
        case cancelled = "cancelled"
    }
    
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
        receiptUrl: String? = nil // New parameter, default nil for backward compatibility
    ) {
        let order = Order(
            id: UUID().uuidString,
            date: Date(),
            coffeeShop: coffeeShop,
            items: items,
            totalAmount: totalAmount,
            transactionId: transactionId,
            status: .completed,
            receiptUrl: receiptUrl // Pass to struct
        )
        
        orders.insert(order, at: 0) // Add to beginning for chronological order
        saveOrders()
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
    
    var recentOrders: [Order] {
        Array(orders.prefix(5))
    }
    
    var totalSpent: Double {
        orders.reduce(0) { $0 + $1.totalAmount }
    }
}