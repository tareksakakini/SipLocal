import Foundation

struct CartItem: Identifiable, Codable {
    let id: UUID
    let shop: CoffeeShop
    let menuItem: MenuItem
    let category: String
    var quantity: Int
    var customizations: String?
    
    init(shop: CoffeeShop, menuItem: MenuItem, category: String, quantity: Int, customizations: String? = nil) {
        self.id = UUID()
        self.shop = shop
        self.menuItem = menuItem
        self.category = category
        self.quantity = quantity
        self.customizations = customizations
    }
    
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
    
    func addItem(shop: CoffeeShop, menuItem: MenuItem, category: String, customizations: String? = nil) -> Bool {
        // Check if cart has items from a different coffee shop
        if !items.isEmpty && items.first?.shop.id != shop.id {
            return false // Cannot add item from different shop
        }
        
        if let existingIndex = items.firstIndex(where: { 
            $0.shop.id == shop.id && $0.menuItem.name == menuItem.name && $0.customizations == customizations
        }) {
            items[existingIndex].quantity += 1
        } else {
            let newItem = CartItem(shop: shop, menuItem: menuItem, category: category, quantity: 1, customizations: customizations)
            items.append(newItem)
        }
        return true
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