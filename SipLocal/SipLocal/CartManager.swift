import Foundation

struct CartItem: Identifiable {
    let id = UUID()
    let shop: CoffeeShop
    let menuItem: MenuItem
    let category: String
    var quantity: Int
    
    var totalPrice: Double {
        return menuItem.price * Double(quantity)
    }
}

class CartManager: ObservableObject {
    @Published var items: [CartItem] = []
    
    var totalPrice: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
    
    func addItem(shop: CoffeeShop, menuItem: MenuItem, category: String) {
        if let existingIndex = items.firstIndex(where: { 
            $0.shop.id == shop.id && $0.menuItem.name == menuItem.name 
        }) {
            items[existingIndex].quantity += 1
        } else {
            let newItem = CartItem(shop: shop, menuItem: menuItem, category: category, quantity: 1)
            items.append(newItem)
        }
    }
    
    func removeItem(cartItem: CartItem) {
        items.removeAll { $0.id == cartItem.id }
    }
    
    func updateQuantity(cartItem: CartItem, quantity: Int) {
        if let index = items.firstIndex(where: { $0.id == cartItem.id }) {
            if quantity <= 0 {
                items.remove(at: index)
            } else {
                items[index].quantity = quantity
            }
        }
    }
    
    func clearCart() {
        items.removeAll()
    }
} 