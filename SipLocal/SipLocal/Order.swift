import Foundation
import FirebaseFirestore
import FirebaseAuth

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
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()
    
    init() {
        // Load orders when user is authenticated
        if auth.currentUser != nil {
            Task {
                await fetchOrders()
            }
        }
        
        // Listen for authentication changes
        auth.addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                Task {
                    await self?.fetchOrders()
                }
            } else {
                DispatchQueue.main.async {
                    self?.orders = []
                }
            }
        }
    }
    
    // MARK: - Firestore Operations
    
    @MainActor
    func fetchOrders() async {
        guard let userId = auth.currentUser?.uid else {
            print("OrderManager: No user ID available")
            return
        }
        
        print("OrderManager: Fetching orders for user ID: \(userId)")
        
        isLoading = true
        errorMessage = nil
        
        do {
            let snapshot = try await firestore
                .collection("orders")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            print("OrderManager: Raw Firestore response - \(snapshot.documents.count) documents found")
            
            // Debug: Log all documents to see what's in Firestore
            for (index, document) in snapshot.documents.enumerated() {
                print("OrderManager: Document \(index): \(document.data())")
            }
            
            var fetchedOrders: [Order] = []
            
            for document in snapshot.documents {
                print("OrderManager: Attempting to decode document: \(document.documentID)")
                
                if let order = try? document.data(as: FirestoreOrder.self) {
                    print("OrderManager: Successfully decoded FirestoreOrder: \(order.transactionId)")
                    // Convert FirestoreOrder to Order
                    if let convertedOrder = order.toOrder() {
                        fetchedOrders.append(convertedOrder)
                        print("OrderManager: Successfully converted to Order: \(convertedOrder.id)")
                    } else {
                        print("OrderManager: Failed to convert FirestoreOrder to Order")
                    }
                } else {
                    print("OrderManager: Failed to decode document as FirestoreOrder")
                    print("OrderManager: Document data: \(document.data())")
                    
                    // Try to decode with more detailed error
                    do {
                        let _ = try document.data(as: FirestoreOrder.self)
                    } catch {
                        print("OrderManager: Decoding error details: \(error)")
                    }
                }
            }
            
            // Sort orders by creation date (newest first)
            self.orders = fetchedOrders.sorted { $0.date > $1.date }
            print("OrderManager: Fetched \(fetchedOrders.count) orders from Firestore")
            
        } catch {
            print("OrderManager: Error fetching orders: \(error)")
            errorMessage = "Failed to load orders: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func refreshOrders() async {
        await fetchOrders()
    }
    
    // MARK: - Order Status Updates
    
    func updateOrderStatus(orderId: String, newStatus: OrderStatus) async {
        guard let userId = auth.currentUser?.uid else { return }
        
        do {
            try await firestore
                .collection("orders")
                .whereField("userId", isEqualTo: userId)
                .whereField("transactionId", isEqualTo: orderId)
                .getDocuments()
                .documents
                .first?
                .reference
                .updateData([
                    "status": newStatus.rawValue,
                    "updatedAt": FieldValue.serverTimestamp()
                ])
            
            // Refresh orders after update
            await fetchOrders()
            
        } catch {
            print("OrderManager: Error updating order status: \(error)")
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
                    await updateOrderStatus(orderId: order.transactionId, newStatus: newStatus)
                }
                
            } catch {
                print("❌ OrderManager: Failed to sync status for order at \(order.coffeeShop.name): \(error)")
                // Continue with other orders even if one fails
            }
        }
        
        print("🔄 OrderManager: Order status sync completed")
    }
    
    // MARK: - Helper Methods
    
    func removeOrder(_ order: Order) async {
        guard let userId = auth.currentUser?.uid else { return }
        
        do {
            try await firestore
                .collection("orders")
                .whereField("userId", isEqualTo: userId)
                .whereField("transactionId", isEqualTo: order.transactionId)
                .getDocuments()
                .documents
                .first?
                .reference
                .delete()
            
            await fetchOrders()
            
        } catch {
            print("OrderManager: Error removing order: \(error)")
        }
    }
    
    func clearAllOrders() async {
        guard let userId = auth.currentUser?.uid else { return }
        
        do {
            let snapshot = try await firestore
                .collection("orders")
                .whereField("userId", isEqualTo: userId)
                .getDocuments()
            
            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            
            try await batch.commit()
            await fetchOrders()
            
        } catch {
            print("OrderManager: Error clearing orders: \(error)")
        }
    }
    
    // MARK: - Computed Properties
    
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

// MARK: - Firestore Order Model

struct FirestoreOrder: Codable {
    let transactionId: String
    let paymentStatus: String?
    let amount: String
    let currency: String?
    let merchantId: String?
    let createdAt: Date?
    let updatedAt: Date?
    let paymentMethod: String?
    let receiptNumber: String?
    let receiptUrl: String?
    let userId: String?
    let coffeeShopData: CoffeeShopData?
    let items: [FirestoreOrderItem]?
    let customerName: String?
    let customerEmail: String?
    let orderId: String?
    let status: String?
    
    func toOrder() -> Order? {
        // For orders without coffeeShopData, create a fallback coffee shop
        let coffeeShop: CoffeeShop
        if let coffeeShopData = coffeeShopData {
            coffeeShop = CoffeeShop(
                id: coffeeShopData.id,
                name: coffeeShopData.name,
                address: coffeeShopData.address,
                latitude: coffeeShopData.latitudeDouble,
                longitude: coffeeShopData.longitudeDouble,
                phone: coffeeShopData.phone,
                website: coffeeShopData.website,
                description: coffeeShopData.description,
                imageName: coffeeShopData.imageName,
                stampName: coffeeShopData.stampName,
                merchantId: coffeeShopData.merchantId
            )
        } else {
            // Fallback coffee shop for orders without coffeeShopData
            coffeeShop = CoffeeShop(
                id: "unknown",
                name: "Unknown Coffee Shop",
                address: "Unknown Address",
                latitude: 0.0,
                longitude: 0.0,
                phone: "Unknown",
                website: "",
                description: "Unknown coffee shop",
                imageName: "qisa", // Default image
                stampName: "qisa_stamp",
                merchantId: merchantId ?? "unknown"
            )
        }
        
        // Convert Firestore order items to CartItems
        let cartItems: [CartItem]
        if let items = items {
            cartItems = items.compactMap { $0.toCartItem(coffeeShop: coffeeShop) }
        } else {
            // Fallback item for orders without items
            let fallbackMenuItem = MenuItem(
                id: "unknown_item",
                name: "Unknown Item",
                price: 0.0,
                variations: nil,
                customizations: nil,
                imageURL: nil,
                modifierLists: nil
            )
            cartItems = [
                CartItem(
                    shop: coffeeShop,
                    menuItem: fallbackMenuItem,
                    category: "Unknown",
                    quantity: 1,
                    customizations: nil,
                    itemPriceWithModifiers: 0.0
                )
            ]
        }
        
        // Parse amount (convert from cents to dollars)
        let totalAmount = (Double(amount) ?? 0.0) / 100.0
        
        // Parse status
        let orderStatus = OrderStatus(rawValue: status ?? "SUBMITTED") ?? .submitted
        
        // Use current date if createdAt is nil
        let orderDate = createdAt ?? Date()
        
        return Order(
            id: transactionId,
            date: orderDate,
            coffeeShop: coffeeShop,
            items: cartItems,
            totalAmount: totalAmount,
            transactionId: transactionId,
            status: orderStatus,
            receiptUrl: receiptUrl,
            squareOrderId: orderId
        )
    }
}

struct CoffeeShopData: Codable {
    let id: String
    let name: String
    let address: String
    let latitude: String
    let longitude: String
    let phone: String
    let website: String
    let description: String
    let imageName: String
    let stampName: String
    let merchantId: String
    
    // Custom decoding to handle all potential type mismatches
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle id as either string or number
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = idString
        } else if let idNumber = try? container.decode(Int.self, forKey: .id) {
            id = String(idNumber)
        } else {
            id = "unknown"
        }
        
        name = try container.decode(String.self, forKey: .name)
        address = try container.decode(String.self, forKey: .address)
        
        // Handle latitude as either string or number
        if let latString = try? container.decode(String.self, forKey: .latitude) {
            latitude = latString
        } else if let latNumber = try? container.decode(Double.self, forKey: .latitude) {
            latitude = String(latNumber)
        } else {
            latitude = "0.0"
        }
        
        // Handle longitude as either string or number
        if let lonString = try? container.decode(String.self, forKey: .longitude) {
            longitude = lonString
        } else if let lonNumber = try? container.decode(Double.self, forKey: .longitude) {
            longitude = String(lonNumber)
        } else {
            longitude = "0.0"
        }
        
        phone = try container.decode(String.self, forKey: .phone)
        website = try container.decode(String.self, forKey: .website)
        description = try container.decode(String.self, forKey: .description)
        imageName = try container.decode(String.self, forKey: .imageName)
        stampName = try container.decode(String.self, forKey: .stampName)
        merchantId = try container.decode(String.self, forKey: .merchantId)
    }
    
    // Computed properties to convert strings to doubles
    var latitudeDouble: Double {
        return Double(latitude) ?? 0.0
    }
    
    var longitudeDouble: Double {
        return Double(longitude) ?? 0.0
    }
}

struct FirestoreOrderItem: Codable {
    let name: String
    let quantity: Int
    let price: Int // Price in cents
    let customizations: String?
    
    func toCartItem(coffeeShop: CoffeeShop) -> CartItem? {
        // Create a basic MenuItem from the stored data
        let menuItem = MenuItem(
            id: name, // Use name as ID since we don't store the original ID
            name: name,
            price: Double(price) / 100.0, // Convert cents to dollars
            variations: nil,
            customizations: nil,
            imageURL: nil,
            modifierLists: nil
        )
        
        return CartItem(
            shop: coffeeShop,
            menuItem: menuItem,
            category: "Unknown", // We don't store category in Firestore
            quantity: quantity,
            customizations: customizations,
            itemPriceWithModifiers: Double(price) / 100.0
        )
    }
}