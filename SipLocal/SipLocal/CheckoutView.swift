import SwiftUI
import SquareInAppPaymentsSDK
import Combine

struct CheckoutView: View {
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var orderManager: OrderManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isProcessingPayment = false
    @State private var paymentResult: String = ""
    @State private var showingCardEntry = false
    @State private var showingPaymentResult = false
    @State private var paymentSuccess = false
    @State private var transactionId: String?
    @State private var completedOrderItems: [CartItem] = []
    @State private var completedOrderTotal: Double = 0.0
    @State private var completedOrderShop: CoffeeShop?
    
    // Use @StateObject to create and manage the delegate
    @StateObject private var cardEntryDelegate = SquareCardEntryDelegate()
    
    // Add an instance of our payment service
    private let paymentService = PaymentService()
    private let tokenService = TokenService()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Cart Summary
                ScrollView {
                    VStack(spacing: 16) {
                        // Order Summary Header
                        HStack {
                            Text("Order Summary")
                                .font(.title2)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.top)
                        
                        // Coffee Shop Header
                        if let firstItem = cartManager.items.first {
                            VStack(spacing: 4) {
                                HStack {
                                    Image(systemName: "house.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    
                                    Text(firstItem.shop.name)
                                        .font(.headline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        
                        // Cart Items
                        LazyVStack(spacing: 12) {
                            ForEach(cartManager.items) { item in
                                CheckoutItemRow(cartItem: item)
                            }
                        }
                        .padding(.horizontal)
                        
                        Spacer().frame(height: 20)
                    }
                }
                
                // Payment Section
                VStack(spacing: 16) {
                    Divider()
                    
                    // Total
                    HStack {
                        Text("Total")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("$\(cartManager.totalPrice, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    
                    // Payment Button
                    Button(action: {
                        self.showingCardEntry = true
                    }) {
                        HStack {
                            if isProcessingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("Processing...")
                            } else {
                                Text("Pay")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessingPayment ? Color.gray : Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessingPayment)
                    .padding(.horizontal)
                    .padding(.bottom)
                    
                }
                .background(Color(.systemGray6))
            }
            .background(Color(.systemGray6))
            .navigationTitle("Checkout")
            .navigationBarBackButtonHidden(true)
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
        .sheet(isPresented: $showingCardEntry) {
            CardEntryView(delegate: self.cardEntryDelegate)
        }
        .sheet(isPresented: $showingPaymentResult) {
            PaymentResultView(
                isSuccess: paymentSuccess,
                transactionId: transactionId,
                message: paymentResult,
                coffeeShop: paymentSuccess ? completedOrderShop : nil,
                orderItems: paymentSuccess ? completedOrderItems : nil,
                totalAmount: paymentSuccess ? completedOrderTotal : nil,
                onDismiss: {
                    showingPaymentResult = false
                    if paymentSuccess {
                        // Switch to Explore tab first, then dismiss checkout
                        NotificationCenter.default.post(name: NSNotification.Name("SwitchToExploreTab"), object: nil)
                        
                        // Dismiss the checkout view after a brief delay to ensure tab switch completes
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            presentationMode.wrappedValue.dismiss()
                        }
                    } else {
                        // For failed payments, just dismiss normally
                        presentationMode.wrappedValue.dismiss()
                    }
                },
                onTryAgain: paymentSuccess ? nil : {
                    // For failed payments, show card entry again
                    showingPaymentResult = false
                    showingCardEntry = true
                }
            )
        }
        .onReceive(cardEntryDelegate.$cardDetails) { cardDetails in
            if let details = cardDetails {
                // We have the nonce, now process the payment
                processPayment(nonce: details.nonce)
            }
        }
        .onReceive(cardEntryDelegate.$wasCancelled) { wasCancelled in
            if wasCancelled {
                self.paymentResult = "Card entry was canceled."
                self.showingCardEntry = false
            }
        }
    }
    
    private func processPayment(nonce: String) {
        isProcessingPayment = true
        paymentResult = "Processing payment..."
        
        // Get the merchant ID from the first item in the cart
        // In a real app, you might want to validate that all items are from the same shop
        guard let firstItem = cartManager.items.first else {
            paymentResult = "No items in cart"
            isProcessingPayment = false
            return
        }
        
        let merchantId = firstItem.shop.merchantId
        
        Task {
            do {
                // First, fetch the tokens from the backend
                let credentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
                
                // Debug: Print the values we're sending
                print("Debug - Sending to Firebase:")
                print("  nonce: \(nonce)")
                print("  amount: \(cartManager.totalPrice)")
                print("  merchantId: \(merchantId)")
                print("  oauth_token: \(credentials.oauth_token.prefix(10))...)")
                
                // Now process the payment with the fetched tokens
                let result = await paymentService.processPayment(
                    nonce: nonce, 
                    amount: cartManager.totalPrice,
                    merchantId: merchantId,
                    oauthToken: credentials.oauth_token,
                    cartItems: cartManager.items
                )
                
                // Update the UI on the main thread
                await MainActor.run {
                    switch result {
                    case .success(let transaction):
                        paymentResult = transaction.message
                        paymentSuccess = true
                        transactionId = transaction.transactionId
                        // Store order details before clearing the cart
                        completedOrderItems = cartManager.items
                        completedOrderTotal = cartManager.totalPrice
                        completedOrderShop = cartManager.items.first?.shop
                        
                        // Save the order to order history
                        if let shop = cartManager.items.first?.shop {
                            orderManager.addOrder(
                                coffeeShop: shop,
                                items: cartManager.items,
                                totalAmount: cartManager.totalPrice,
                                transactionId: transaction.transactionId
                            )
                        }
                        
                        // Clear the cart on successful payment
                        cartManager.clearCart()
                    case .failure(let error):
                        paymentResult = error.localizedDescription
                        paymentSuccess = false
                        transactionId = nil
                    }
                    isProcessingPayment = false
                    self.showingCardEntry = false
                    self.showingPaymentResult = true
                }
            } catch {
                // Handle token fetching errors
                await MainActor.run {
                    paymentResult = "Failed to retrieve payment credentials: \(error.localizedDescription)"
                    paymentSuccess = false
                    transactionId = nil
                    isProcessingPayment = false
                    self.showingCardEntry = false
                    self.showingPaymentResult = true
                }
            }
        }
    }
}

// 2. Create a UIViewControllerRepresentable to wrap the Square SDK's view controller
struct CardEntryView: UIViewControllerRepresentable {
    var delegate: SQIPCardEntryViewControllerDelegate
    
    func makeUIViewController(context: Context) -> UINavigationController {
        // Customize the card entry form theme
        let theme = SQIPTheme()
        theme.tintColor = .black
        theme.saveButtonTitle = "Pay"
        
        let cardEntryViewController = SQIPCardEntryViewController(theme: theme)
        cardEntryViewController.delegate = delegate
        
        let navigationController = UINavigationController(rootViewController: cardEntryViewController)
        return navigationController
    }
    
    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {
        // No update needed
    }
}


struct CheckoutItemRow: View {
    let cartItem: CartItem
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cartItem.menuItem.name)
                    .font(.body)
                    .fontWeight(.medium)
                
                if let customizations = cartItem.customizations, !customizations.isEmpty {
                    Text(customizations)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("×\(cartItem.quantity)")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("$\(cartItem.totalPrice, specifier: "%.2f")")
                    .font(.body)
                    .fontWeight(.medium)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

// Preview
struct CheckoutView_Previews: PreviewProvider {
    static var previews: some View {
        CheckoutView()
            .environmentObject(CartManager())
            .environmentObject(OrderManager())
    }
} 