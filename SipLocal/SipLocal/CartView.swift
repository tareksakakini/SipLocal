import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationStack {
            VStack {
                if cartManager.items.isEmpty {
                    // Empty Cart State
                    VStack(spacing: 20) {
                        Image(systemName: "cart")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("Your cart is empty")
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Text("Add some delicious drinks to get started!")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Cart Items List
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(cartManager.items) { item in
                                CartItemRow(cartItem: item)
                            }
                        }
                        .padding()
                    }
                    
                    // Total Section
                    VStack(spacing: 16) {
                        Divider()
                        
                        HStack {
                            Text("Total (\(cartManager.totalItems) items)")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Text("$\(cartManager.totalPrice, specifier: "%.2f")")
                                .font(.title2)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal)
                        
                        Button(action: {
                            // TODO: Implement checkout
                        }) {
                            Text("Checkout")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.black)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .background(Color(.systemGray6))
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Cart")
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
                
                if !cartManager.items.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear") {
                            cartManager.clearCart()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
    }
}

struct CartItemRow: View {
    let cartItem: CartItem
    @EnvironmentObject var cartManager: CartManager
    
    // Helper to extract concise customizations
    private func conciseCustomizations() -> (size: String?, mods: [String]) {
        guard let customizations = cartItem.customizations else { return (nil, []) }
        var size: String? = nil
        var mods: [String] = []
        // Parse customization string: "Ice: X, Milk: Y, Sugar: Z, Size: W"
        let parts = customizations.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        for part in parts {
            if part.hasPrefix("Size: ") {
                size = String(part.dropFirst(6))
            } else if part.hasPrefix("Ice: ") {
                let value = String(part.dropFirst(5))
                if value != "Regular" { mods.append("Ice: " + value) }
            } else if part.hasPrefix("Milk: ") {
                let value = String(part.dropFirst(6))
                if value != "Whole" { mods.append("Milk: " + value) }
            } else if part.hasPrefix("Sugar: ") {
                let value = String(part.dropFirst(7))
                if value != "Regular" { mods.append("Sugar: " + value) }
            }
        }
        return (size, mods)
    }
    
    var body: some View {
        let (size, mods) = conciseCustomizations()
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(cartItem.menuItem.name)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                if let size = size {
                    Text(size)
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.vertical, 1)
                }
                if !mods.isEmpty {
                    Text(mods.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)
                        .padding(.vertical, 1)
                }
                
                Text("\(cartItem.category) • \(cartItem.shop.name)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Text("$\(cartItem.menuItem.price, specifier: "%.2f") each")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Button(action: {
                        cartManager.updateQuantity(cartItem: cartItem, quantity: cartItem.quantity - 1)
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(cartItem.quantity)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .frame(minWidth: 20)
                    
                    Button(action: {
                        cartManager.updateQuantity(cartItem: cartItem, quantity: cartItem.quantity + 1)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                }
                
                Text("$\(cartItem.totalPrice, specifier: "%.2f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct CartView_Previews: PreviewProvider {
    static var previews: some View {
        CartView()
            .environmentObject(CartManager())
    }
} 