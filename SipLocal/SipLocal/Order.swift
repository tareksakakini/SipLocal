import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseFunctions

enum OrderStatus: String, Codable, CaseIterable {
    case authorized = "AUTHORIZED"   // Payment authorized, awaiting confirmation
    case submitted = "SUBMITTED"     // Order just placed, waiting for merchant
    case inProgress = "IN_PROGRESS"  // Merchant is preparing the order
    case ready = "READY"             // Order is ready for pickup
    case completed = "COMPLETED"     // Order has been picked up
    case cancelled = "CANCELLED"     // Order was cancelled
    case draft = "DRAFT"             // Order is in draft state (legacy)
    case pending = "PENDING"         // Order is pending (legacy)
    case active = "active"           // Legacy status for backward compatibility
}

enum OrderError: Error, LocalizedError {
    case notAuthenticated
    case cancellationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .cancellationFailed(let message):
            return "Failed to cancel order: \(message)"
        }
    }
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
    @Published var isRealtimeActive = false
    
    private let firestore = Firestore.firestore()
    private let auth = Auth.auth()
    private var listenerRegistration: ListenerRegistration?
    
    init() {
        // Load orders when user is authenticated
        if auth.currentUser != nil {
            Task {
                await setupRealtimeListener()
            }
        }
        
        // Listen for authentication changes
        auth.addStateDidChangeListener { [weak self] _, user in
            if user != nil {
                Task {
                    await self?.setupRealtimeListener()
                }
            } else {
                DispatchQueue.main.async {
                    self?.orders = []
                    self?.removeListener()
                }
            }
        }
    }
    
    deinit {
        removeListener()
    }
    
    // MARK: - Real-time Listener Setup
    
    @MainActor
    private func setupRealtimeListener() async {
        guard let userId = auth.currentUser?.uid else {
            print("OrderManager: No user ID available")
            return
        }
        
        print("OrderManager: Setting up real-time listener for user ID: \(userId)")
        
        // Remove any existing listener
        removeListener()
        
        isLoading = true
        errorMessage = nil
        
        // Set up real-time listener for user's orders with more explicit configuration
        listenerRegistration = firestore
            .collection("orders")
            .whereField("userId", isEqualTo: userId)
            .addSnapshotListener(includeMetadataChanges: true) { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("OrderManager: Real-time listener error: \(error)")
                        self.errorMessage = "Failed to load orders: \(error.localizedDescription)"
                        self.isLoading = false
                        return
                    }
                    
                    guard let snapshot = snapshot else {
                        print("OrderManager: No snapshot received")
                        self.isLoading = false
                        return
                    }
                    
                    print("OrderManager: 🔄 REAL-TIME UPDATE TRIGGERED - \(snapshot.documents.count) documents")
                    print("OrderManager: Snapshot metadata - hasPendingWrites: \(snapshot.metadata.hasPendingWrites), fromCache: \(snapshot.metadata.isFromCache)")
                    
                    // Only process if this is not from cache or if it's the initial load
                    if snapshot.metadata.isFromCache && self.orders.count > 0 {
                        print("OrderManager: Skipping cache-only update")
                        return
                    }
                    
                    var fetchedOrders: [Order] = []
                    
                    for document in snapshot.documents {
                        print("OrderManager: Processing document: \(document.documentID)")
                        
                        if let order = try? document.data(as: FirestoreOrder.self) {
                            print("OrderManager: Successfully decoded FirestoreOrder: \(order.transactionId) with status: \(order.status ?? "nil")")
                            // Convert FirestoreOrder to Order
                            if let convertedOrder = order.toOrder() {
                                fetchedOrders.append(convertedOrder)
                                print("OrderManager: Successfully converted to Order: \(convertedOrder.id) with status: \(convertedOrder.status)")
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
                    let oldOrders = self.orders
                    self.orders = fetchedOrders.sorted { $0.date > $1.date }
                    print("OrderManager: Real-time update - \(fetchedOrders.count) orders processed")
                    
                    // Check if any order statuses changed
                    for (index, newOrder) in self.orders.enumerated() {
                        if index < oldOrders.count {
                            let oldOrder = oldOrders[index]
                            if oldOrder.status != newOrder.status {
                                print("OrderManager: 🎉 STATUS CHANGE DETECTED! Order \(newOrder.id) changed from \(oldOrder.status) to \(newOrder.status)")
                            }
                        }
                    }
                    
                    self.isLoading = false
                    self.isRealtimeActive = true
                }
            }
        
        print("OrderManager: Real-time listener setup complete")
    }
    
    private func removeListener() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("OrderManager: Removed real-time listener")
    }
    
    // MARK: - Firestore Operations
    
    @MainActor
    func fetchOrders() async {
        // This method now just sets up the real-time listener
        await setupRealtimeListener()
    }
    
    func refreshOrders() async {
        // Force a refresh by temporarily removing and re-adding the listener
        removeListener()
        await setupRealtimeListener()
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
            
            // No need to manually refresh - the real-time listener will handle updates automatically
            print("OrderManager: Updated order status to \(newStatus.rawValue) for order \(orderId)")
            
        } catch {
            print("OrderManager: Error updating order status: \(error)")
        }
    }
    
    // MARK: - Order Cancellation
    
    func cancelOrder(paymentId: String) async throws {
        guard auth.currentUser != nil else {
            throw OrderError.notAuthenticated
        }
        
        // Call Firebase Cloud Function to cancel the order
        let functions = Functions.functions()
        let data = ["paymentId": paymentId]
        
        do {
            let result = try await functions.httpsCallable("cancelOrder").call(data)
            print("OrderManager: Successfully cancelled order: \(paymentId)")
        } catch {
            print("OrderManager: Error cancelling order: \(error)")
            throw OrderError.cancellationFailed(error.localizedDescription)
        }
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
    
    var authorizedOrders: [Order] {
        orders.filter { $0.status == .authorized }
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
        let orderStatus = OrderStatus(rawValue: status ?? "AUTHORIZED") ?? .authorized
        
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