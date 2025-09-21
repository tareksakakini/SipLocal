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
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    
    // Payment capture timer
    private var paymentCaptureTimers: [String: Timer] = [:]
    
    init() {
        // Load orders when user is authenticated
        if auth.currentUser != nil {
            Task {
                await setupRealtimeListener()
            }
        }
        
        // Listen for authentication changes
        authListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
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
        if let handle = authListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
        removeListener()
        // Clean up all payment capture timers
        paymentCaptureTimers.values.forEach { $0.invalidate() }
        paymentCaptureTimers.removeAll()
    }
    
    // MARK: - Real-time Listener Setup
    
    @MainActor
    private func setupRealtimeListener() async {
        guard let userId = auth.currentUser?.uid else {
            print("OrderManager: No user ID available")
            return
        }
        
        print("OrderManager: Setting up listener")
        
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
                    
                    // Only process if this is not from cache or if it's the initial load
                    if snapshot.metadata.isFromCache && self.orders.count > 0 {
                        return
                    }
                    
                    print("OrderManager: Processing \(snapshot.documents.count) orders")
                    
                    var fetchedOrders: [Order] = []
                    
                    for document in snapshot.documents {
                        if let order = try? document.data(as: FirestoreOrder.self) {
                            // Convert FirestoreOrder to Order
                            if let convertedOrder = order.toOrder() {
                                fetchedOrders.append(convertedOrder)
                            }
                        } else {
                            print("OrderManager: Failed to decode order \(document.documentID)")
                        }
                    }
                    
                    // Sort orders by creation date (newest first)
                    let oldOrders = self.orders
                    self.orders = fetchedOrders.sorted { $0.date > $1.date }
                    
                    // Check for status changes (only log significant ones)
                    let statusChanges = self.orders.compactMap { newOrder in
                        oldOrders.first(where: { $0.transactionId == newOrder.transactionId })
                            .flatMap { oldOrder in
                                oldOrder.status != newOrder.status ? (oldOrder.status, newOrder.status) : nil
                            }
                    }
                    
                    if !statusChanges.isEmpty {
                        print("OrderManager: \(statusChanges.count) status changes detected")
                    }
                    
                    self.isLoading = false
                    self.isRealtimeActive = true
                }
            }
        
        print("OrderManager: Listener active")
    }
    
    private func removeListener() {
        listenerRegistration?.remove()
        listenerRegistration = nil
        print("OrderManager: Listener removed")
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
            print("OrderManager: Updated order \(orderId) to \(newStatus.rawValue)")
            
        } catch {
            print("OrderManager: Error updating order status: \(error)")
        }
    }
    
    // MARK: - Payment Capture Timer
    
    func startPaymentCaptureTimer(transactionId: String, clientSecret: String, paymentService: PaymentService) {
        print("🕒 Starting payment capture timer for transaction: \(transactionId)")
        
        // Cancel any existing timer for this transaction
        paymentCaptureTimers[transactionId]?.invalidate()
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            print("🔥 Payment capture timer fired for transaction: \(transactionId)")
            
            Task {
                await self.capturePayment(transactionId: transactionId, clientSecret: clientSecret, paymentService: paymentService)
            }
        }
        
        // Store the timer
        paymentCaptureTimers[transactionId] = timer
        
        // Add to run loop to ensure it fires
        RunLoop.main.add(timer, forMode: .common)
        print("✅ Payment capture timer scheduled successfully")
    }
    
    private func capturePayment(transactionId: String, clientSecret: String, paymentService: PaymentService) async {
        print("💳 Capturing payment for transaction: \(transactionId)")
        
        let result = await paymentService.completeStripePayment(
            clientSecret: clientSecret,
            transactionId: transactionId
        )
        
        await MainActor.run {
            // Clean up the timer
            paymentCaptureTimers[transactionId]?.invalidate()
            paymentCaptureTimers.removeValue(forKey: transactionId)
            
            switch result {
            case .success(let transaction):
                print("✅ Payment captured successfully: \(transaction)")
                // Refresh orders to show updated status
                Task {
                    await self.refreshOrders()
                }
            case .failure(let error):
                print("❌ Payment capture failed: \(error.localizedDescription)")
                // Could implement retry logic or notification here
            }
        }
    }
    
    // MARK: - Apple Pay Capture Timer
    
    func startApplePayCaptureTimer(transactionId: String, paymentService: PaymentService) {
        print("🍎🕒 Starting Apple Pay capture timer for transaction: \(transactionId)")
        
        // Cancel any existing timer for this transaction
        paymentCaptureTimers[transactionId]?.invalidate()
        
        // Create a new timer
        let timer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            print("🍎🔥 Apple Pay capture timer fired for transaction: \(transactionId)")
            
            Task {
                await self.captureApplePayPayment(transactionId: transactionId, paymentService: paymentService)
            }
        }
        
        // Store the timer
        paymentCaptureTimers[transactionId] = timer
        
        // Add to run loop to ensure it fires
        RunLoop.main.add(timer, forMode: .common)
        print("✅ Apple Pay capture timer scheduled successfully")
    }
    
    private func captureApplePayPayment(transactionId: String, paymentService: PaymentService) async {
        print("🍎💳 Capturing Apple Pay payment for transaction: \(transactionId)")
        
        let result = await paymentService.captureApplePayPayment(transactionId: transactionId)
        
        await MainActor.run {
            // Clean up the timer
            paymentCaptureTimers[transactionId]?.invalidate()
            paymentCaptureTimers.removeValue(forKey: transactionId)
            
            switch result {
            case .success(let message):
                print("✅ Apple Pay payment captured successfully: \(message)")
                // Refresh orders to show updated status
                Task {
                    await self.refreshOrders()
                }
            case .failure(let error):
                print("❌ Apple Pay payment capture failed: \(error.localizedDescription)")
                // Could implement retry logic or notification here
            }
        }
    }
    
    // MARK: - Order Cancellation
    
    func cancelOrder(paymentId: String) async throws {
        guard auth.currentUser != nil else {
            throw OrderError.notAuthenticated
        }
        
        // Cancel any pending payment capture timer for this order
        if let timer = paymentCaptureTimers[paymentId] {
            print("🛑 Cancelling payment capture timer for order: \(paymentId)")
            timer.invalidate()
            paymentCaptureTimers.removeValue(forKey: paymentId)
        }
        
        // Check if this is an Apple Pay order by looking at the order data
        let orderDoc = try await firestore
            .collection("orders")
            .document(paymentId)
            .getDocument()
        
        let functions = Functions.functions()
        
        if let orderData = orderDoc.data(),
           let paymentMethod = orderData["paymentMethod"] as? String,
           paymentMethod == "apple_pay" {
            // Cancel Apple Pay authorization
            print("🍎 Cancelling Apple Pay order: \(paymentId)")
            let data = ["transactionId": paymentId]
            
            do {
                _ = try await functions.httpsCallable("cancelApplePayPayment").call(data)
                print("OrderManager: Cancelled Apple Pay order")
            } catch {
                print("OrderManager: Error cancelling Apple Pay order: \(error)")
                throw OrderError.cancellationFailed(error.localizedDescription)
            }
        } else {
            // Cancel regular Stripe payment
            let data = ["paymentId": paymentId]
            
            do {
                _ = try await functions.httpsCallable("cancelOrder").call(data)
                print("OrderManager: Cancelled order")
            } catch {
                print("OrderManager: Error cancelling order: \(error)")
                throw OrderError.cancellationFailed(error.localizedDescription)
            }
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
                merchantId: coffeeShopData.merchantId,
                posType: .square // Default to square for legacy data
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
                merchantId: merchantId ?? "unknown",
                posType: .square // Default to square for unknown shops
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
                    itemPriceWithModifiers: 0.0,
                    selectedSizeId: nil,
                    selectedModifierIdsByList: nil
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
    let id: String?
    let name: String
    let quantity: Int
    let price: Int // Price in cents
    let customizations: String?
    let selectedSizeId: String?
    let selectedModifierIdsByList: [String: [String]]?
    
    func toCartItem(coffeeShop: CoffeeShop) -> CartItem? {
        // Create a basic MenuItem from the stored data
        let menuItem = MenuItem(
            id: id ?? name, // Use Square id if available, fallback to name
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
            itemPriceWithModifiers: Double(price) / 100.0,
            selectedSizeId: selectedSizeId,
            selectedModifierIdsByList: selectedModifierIdsByList
        )
    }
}
