import Foundation

struct CartItem: Identifiable, Codable {
    let id: UUID
    let shop: CoffeeShop
    let menuItem: MenuItem
    // Persist the Square item identifier to reliably match current menu
    let menuItemId: String
    let category: String
    var quantity: Int
    var customizations: String?
    let itemPriceWithModifiers: Double
    // Detailed selections to enable re-ordering with preloaded customizations
    var selectedSizeId: String?
    // Mapping of modifierListId -> selected modifier ids
    var selectedModifierIdsByList: [String: [String]]?
    
    init(
        shop: CoffeeShop,
        menuItem: MenuItem,
        category: String,
        quantity: Int,
        customizations: String? = nil,
        itemPriceWithModifiers: Double? = nil,
        selectedSizeId: String? = nil,
        selectedModifierIdsByList: [String: [String]]? = nil
    ) {
        self.id = UUID()
        self.shop = shop
        self.menuItem = menuItem
        self.menuItemId = menuItem.id
        self.category = category
        self.quantity = quantity
        self.customizations = customizations
        self.itemPriceWithModifiers = itemPriceWithModifiers ?? menuItem.price
        self.selectedSizeId = selectedSizeId
        self.selectedModifierIdsByList = selectedModifierIdsByList
    }
    
    var totalPrice: Double {
        return itemPriceWithModifiers * Double(quantity)
    }
}

class CartManager: ObservableObject {
    @Published var items: [CartItem] = []
    @Published var shopBusinessHours: [String: BusinessHoursInfo] = [:]
    @Published var isLoadingBusinessHours: [String: Bool] = [:]
    
    var totalPrice: Double {
        return items.reduce(0) { $0 + $1.totalPrice }
    }
    
    var totalItems: Int {
        return items.reduce(0) { $0 + $1.quantity }
    }
    
    // Check if a shop is currently open
    func isShopOpen(shop: CoffeeShop) -> Bool? {
        return shopBusinessHours[shop.id]?.isCurrentlyOpen
    }
    
    // Fetch business hours for a shop
    func fetchBusinessHours(for shop: CoffeeShop) async {
        // Don't fetch if already loading or already fetched
        if isLoadingBusinessHours[shop.id] == true || shopBusinessHours[shop.id] != nil {
            return
        }
        
        await MainActor.run {
            isLoadingBusinessHours[shop.id] = true
        }
        
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let hoursInfo = try await posService.fetchBusinessHours(for: shop)
            await MainActor.run {
                if let hoursInfo = hoursInfo {
                    self.shopBusinessHours[shop.id] = hoursInfo
                }
                self.isLoadingBusinessHours[shop.id] = false
            }
        } catch {
            await MainActor.run {
                print("❌ CartManager: Error fetching business hours for \(shop.name): \(error)")
                self.isLoadingBusinessHours[shop.id] = false
            }
        }
    }
    
    func addItem(
        shop: CoffeeShop,
        menuItem: MenuItem,
        category: String,
        customizations: String? = nil,
        itemPriceWithModifiers: Double? = nil,
        selectedSizeId: String? = nil,
        selectedModifierIdsByList: [String: [String]]? = nil
    ) -> Bool {
        // Check if cart has items from a different coffee shop
        if !items.isEmpty && items.first?.shop.id != shop.id {
            return false // Cannot add item from different shop
        }
        
        // Check if shop is open (if we have business hours data)
        if let isOpen = isShopOpen(shop: shop), !isOpen {
            return false // Cannot add item from closed shop
        }
        
        let priceWithModifiers = itemPriceWithModifiers ?? menuItem.price
        
        if let existingIndex = items.firstIndex(where: {
            // Consider item identity including menu item id and exact selections
            $0.shop.id == shop.id &&
            $0.menuItemId == menuItem.id &&
            $0.customizations == customizations &&
            $0.itemPriceWithModifiers == priceWithModifiers &&
            $0.selectedSizeId == selectedSizeId &&
            normalizeModifierMap($0.selectedModifierIdsByList) == normalizeModifierMap(selectedModifierIdsByList)
        }) {
            items[existingIndex].quantity += 1
        } else {
            let newItem = CartItem(
                shop: shop,
                menuItem: menuItem,
                category: category,
                quantity: 1,
                customizations: customizations,
                itemPriceWithModifiers: priceWithModifiers,
                selectedSizeId: selectedSizeId,
                selectedModifierIdsByList: selectedModifierIdsByList
            )
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
    
    // Clear business hours cache when cart is cleared
    func clearBusinessHoursCache() {
        shopBusinessHours.removeAll()
        isLoadingBusinessHours.removeAll()
    }
} 

// MARK: - Private helpers
private func normalizeModifierMap(_ map: [String: [String]]?) -> [String: [String]]? {
    guard let map else { return nil }
    var normalized: [String: [String]] = [:]
    for (key, value) in map {
        normalized[key] = value.sorted()
    }
    return normalized
}