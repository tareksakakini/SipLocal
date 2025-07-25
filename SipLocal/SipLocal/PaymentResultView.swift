import SwiftUI

struct PaymentResultView: View {
    let isSuccess: Bool
    let transactionId: String?
    let message: String
    let coffeeShop: CoffeeShop?
    let orderItems: [CartItem]?
    let totalAmount: Double?
    let onDismiss: () -> Void
    let onTryAgain: (() -> Void)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isSuccess {
                        // Success Content
                        successContent
                    } else {
                        // Failure Content
                        failureContent
                    }
                }
                .padding()
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .background(Color(.systemGray6))
        }
    }
    
    private var successContent: some View {
        VStack(spacing: 24) {
            Spacer().frame(height: 20)
            
            // Success Icon and Title
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                VStack(spacing: 8) {
                    Text("Order Placed!")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Your payment was successful")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            // Pickup Information Card (moved to show first)
            if let coffeeShop = coffeeShop {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.orange)
                        Text("Pickup Location")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(coffeeShop.name)
                            .font(.body)
                            .fontWeight(.semibold)
                        
                        Text(coffeeShop.address)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            
            // Order Summary Card
            if let orderItems = orderItems, !orderItems.isEmpty {
                VStack(spacing: 16) {
                    HStack {
                        Text("Order Summary")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    
                    VStack(spacing: 12) {
                        ForEach(orderItems) { item in
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
                                    .fontWeight(.semibold)
                            }
                            
                            if item.id != orderItems.last?.id {
                                Divider()
                            }
                        }
                        
                        // Total
                        if let totalAmount = totalAmount {
                            Divider()
                                .padding(.top, 4)
                            
                            HStack {
                                Text("Total")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                Text("$\(totalAmount, specifier: "%.2f")")
                                    .font(.headline)
                                    .fontWeight(.bold)
                            }
                        }
                    }
                }
                .padding()
                .background(Color.white)
                .cornerRadius(12)
            }
            
            // Transaction ID
            if let transactionId = transactionId {
                VStack(spacing: 8) {
                    Text("Transaction ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .fontWeight(.medium)
                    
                    Text(transactionId)
                        .font(.caption)
                        .fontDesign(.monospaced)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            Spacer().frame(height: 20)
            
            // Action Button
            Button(action: onDismiss) {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
        }
    }
    
    private var failureContent: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Failure Icon and Message
            VStack(spacing: 16) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.red)
                
                VStack(spacing: 8) {
                    Text("Payment Failed")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // Action Buttons
            VStack(spacing: 12) {
                Button(action: {
                    onTryAgain?() ?? onDismiss()
                }) {
                    Text("Try Again")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                
                Button(action: onDismiss) {
                    Text("Go Back")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                }
            }
        }
    }
}

// Preview
struct PaymentResultView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentResultView(
                isSuccess: true,
                transactionId: "sq0idp-1234567890",
                message: "Your payment has been processed successfully.",
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
                    menu: SquareCredentials(appID: "", accessToken: "", locationId: "")
                ),
                orderItems: [
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
                            menu: SquareCredentials(appID: "", accessToken: "", locationId: "")
                        ),
                        menuItem: MenuItem(name: "Cappuccino", price: 4.50, customizations: nil, imageURL: nil, modifierLists: nil),
                        category: "Coffee",
                        quantity: 2,
                        customizations: "Extra shot, oat milk"
                    ),
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
                            menu: SquareCredentials(appID: "", accessToken: "", locationId: "")
                        ),
                        menuItem: MenuItem(name: "Blueberry Muffin", price: 3.25, customizations: nil, imageURL: nil, modifierLists: nil),
                        category: "Pastries",
                        quantity: 1,
                        customizations: nil
                    )
                ],
                totalAmount: 12.25,
                onDismiss: {
                    print("Dismissed")
                },
                onTryAgain: nil
            )
            .previewDisplayName("Success")
            
            PaymentResultView(
                isSuccess: false,
                transactionId: nil,
                message: "Your payment could not be processed. Please check your payment method and try again.",
                coffeeShop: nil,
                orderItems: nil,
                totalAmount: nil,
                onDismiss: {
                    print("Dismissed")
                },
                onTryAgain: {
                    print("Try Again")
                }
            )
            .previewDisplayName("Failure")
        }
    }
}