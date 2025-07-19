import SwiftUI
import SquareInAppPaymentsSDK
import Combine

struct CheckoutView: View {
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode
    @State private var isProcessingPayment = false
    @State private var paymentResult: String = ""
    @State private var showingCardEntry = false
    @State private var showingPaymentResult = false
    @State private var paymentSuccess = false
    @State private var transactionId: String?
    
    // Use @StateObject to create and manage the delegate
    @StateObject private var cardEntryDelegate = SquareCardEntryDelegate()
    
    // Add an instance of our payment service
    private let paymentService = PaymentService()
    
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
                                Text("Pay with Square")
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
                message: paymentResult
            ) {
                showingPaymentResult = false
                if paymentSuccess {
                    // Navigate back to main view on success
                    presentationMode.wrappedValue.dismiss()
                }
            }
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
        
        // Get the location ID from the first item in the cart
        // In a real app, you might want to validate that all items are from the same shop
        guard let firstItem = cartManager.items.first else {
            paymentResult = "No items in cart"
            isProcessingPayment = false
            return
        }
        
        let locationId = firstItem.shop.menu.locationId
        
        // Debug: Print the values we're sending
        print("Debug - Sending to Firebase:")
        print("  nonce: \(nonce)")
        print("  amount: \(cartManager.totalPrice)")
        print("  locationId: \(locationId)")
        
        Task {
            let result = await paymentService.processPayment(
                nonce: nonce, 
                amount: cartManager.totalPrice,
                locationId: locationId
            )
            
            // Update the UI on the main thread
            await MainActor.run {
                switch result {
                case .success(let transaction):
                    paymentResult = transaction.message
                    paymentSuccess = true
                    transactionId = transaction.transactionId
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
                
                Text(cartItem.shop.name)
                    .font(.caption)
                    .foregroundColor(.secondary)
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
    }
} 