import SwiftUI

struct CartView: View {
    @EnvironmentObject var cartManager: CartManager
    @Environment(\.presentationMode) var presentationMode
    @State private var showingClosedShopAlert = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if cartManager.items.isEmpty {
                    // Empty Cart State
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "cart")
                            .font(.system(size: 80))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text("Your cart is empty")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("Add some items to get started")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
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
                        
                        // Checkout Button - disabled if shop is closed
                        if let firstItem = cartManager.items.first,
                           let isOpen = cartManager.isShopOpen(shop: firstItem.shop),
                           !isOpen {
                            Button(action: {
                                showingClosedShopAlert = true
                            }) {
                                Text("Shop is Closed")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.red)
                                    .cornerRadius(12)
                            }
                            .padding(.horizontal)
                            .padding(.bottom)
                        } else {
                            NavigationLink(destination: CheckoutView().environmentObject(cartManager)) {
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
            .alert("Shop is Closed", isPresented: $showingClosedShopAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This coffee shop is currently closed. Please try again during business hours.")
            }
            .onAppear {
                // Fetch business hours for the shop in cart
                if let firstItem = cartManager.items.first {
                    Task {
                        await cartManager.fetchBusinessHours(for: firstItem.shop)
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
        
        // Parse customization string: "Size: Medium | Milk Options: Oat Milk | Add-ons: Extra Shot, Vanilla Syrup"
        let parts = customizations.split(separator: "|").map { $0.trimmingCharacters(in: .whitespaces) }
        
        for part in parts {
            if part.lowercased().contains("size") {
                // Extract size value
                if let colonIndex = part.firstIndex(of: ":") {
                    size = String(part[part.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                }
            } else {
                // For other modifications, include the full modifier list and its selections
                if let colonIndex = part.firstIndex(of: ":") {
                    let modifierName = String(part[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                    let selections = String(part[part.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                    
                    // Simplify common modifier names
                    let simplifiedName = simplifyModifierName(modifierName)
                    mods.append("\(simplifiedName): \(selections)")
                }
            }
        }
        return (size, mods)
    }
    
    // Helper to simplify modifier names for display
    private func simplifyModifierName(_ name: String) -> String {
        let lowercased = name.lowercased()
        if lowercased.contains("milk") {
            return "Milk"
        } else if lowercased.contains("add") || lowercased.contains("extra") {
            return "Add-ons"
        } else if lowercased.contains("syrup") || lowercased.contains("flavor") {
            return "Flavoring"
        } else if lowercased.contains("ice") {
            return "Ice"
        } else if lowercased.contains("sweet") || lowercased.contains("sugar") {
            return "Sweetener"
        } else {
            return name
        }
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
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.vertical, 1)
                }
                if !mods.isEmpty {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(mods, id: \.self) { mod in
                            Text(mod)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.vertical, 1)
                }
                
                Text(cartItem.category)
                    .font(.subheadline)
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