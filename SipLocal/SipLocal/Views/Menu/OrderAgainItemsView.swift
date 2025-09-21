/**
 * OrderAgainItemsView.swift
 * SipLocal
 *
 * View for displaying previously ordered items that can be re-ordered.
 * Extracted from MenuItemsView.swift for better organization.
 *
 * ## Features
 * - **Order History Analysis**: Groups items by customization and shows order frequency
 * - **Quick Re-order**: One-tap ordering for simple items
 * - **Customization Support**: Opens customization sheet for complex items
 * - **Cart Integration**: Seamless integration with cart system
 * - **Business Hours Validation**: Checks if shop is open before ordering
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on order-again functionality
 * - **Reactive State**: Uses @State and @EnvironmentObject for state management
 * - **Component Composition**: Leverages DrinkCustomizationSheet and ItemAddedPopup
 * - **Performance**: Efficient grouping and sorting of order history
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - OrderAgainItemsView

/**
 * View for displaying and re-ordering previously ordered items
 * 
 * Analyzes order history to show frequently ordered items with their
 * customizations, allowing users to quickly re-order favorites.
 */
struct OrderAgainItemsView: View {
    
    // MARK: - Properties
    let shop: CoffeeShop
    
    // MARK: - Environment Objects
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var cartManager: CartManager
    
    // MARK: - State Management
    @State private var customizingItem: MenuItem? = nil
    @State private var selectedModifiers: [String: Set<String>] = [:]
    @State private var initialSelectedSizeId: String? = nil
    @State private var showingClosedShopAlert = false
    @State private var showingCart = false
    @State private var showItemAddedPopup = false
    
    // MARK: - Design System
    private enum Design {
        static let cardCornerRadius: CGFloat = 12
        static let cardShadowRadius: CGFloat = 8
        static let cardShadowOpacity: Double = 0.05
        static let thumbnailSize: CGFloat = 56
        static let spacing: CGFloat = 16
        static let padding: CGFloat = 16
        static let cartBadgeSize: CGFloat = 16
        static let cartIconSize: CGFloat = 20
    }
    
    // MARK: - Computed Properties
    
    /**
     * Processed entries for display, grouped by customization and sorted by frequency
     */
    private var entries: [OrderAgainEntry] {
        let categories = MenuDataManager.shared.getMenuCategories(for: shop)
        
        func findMenuItem(id: String) -> MenuItem? {
            for category in categories {
                if let menuItem = category.items.first(where: { $0.id == id }) {
                    return menuItem
                }
            }
            return nil
        }
        
        var counts: [RepeatKey: (count: Int, sample: CartItem)] = [:]
        
        // Analyze order history for this shop
        for order in orderManager.orders 
        where order.coffeeShop.id == shop.id && 
              [.completed, .cancelled].contains(order.status) {
            
            for item in order.items {
                let key = RepeatKey(
                    menuItemId: item.menuItemId,
                    selectedSizeId: item.selectedSizeId,
                    selectedModifierIdsByList: item.selectedModifierIdsByList
                )
                
                let current = counts[key]
                counts[key] = (
                    (current?.count ?? 0) + item.quantity,
                    current?.sample ?? item
                )
            }
        }
        
        // Sort by frequency and create entries
        let sorted = counts.map { ($0.key, $0.value.count, $0.value.sample) }
                          .sorted { $0.1 > $1.1 }
        
        return sorted.compactMap { (key, count, sample) in
            guard let menuItem = findMenuItem(id: key.menuItemId) else { return nil }
            return OrderAgainEntry(
                key: key,
                count: count,
                sample: sample,
                menuItem: menuItem
            )
        }
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                orderAgainContent
            }
            .background(Color(.systemGray6))
            .navigationTitle("Order Again")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                cartToolbarButton
            }
        }
        .sheet(isPresented: $showingCart) {
            CartView()
                .environmentObject(cartManager)
        }
        .sheet(item: $customizingItem) { item in
            customizationSheet(for: item)
        }
        .alert("Shop is Closed", isPresented: $showingClosedShopAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This coffee shop is currently closed. Please try again during business hours.")
        }
        .overlay(
            ItemAddedPopup(isVisible: $showItemAddedPopup)
        )
    }
    
    // MARK: - View Components
    
    /**
     * Main content area with order again items
     */
    private var orderAgainContent: some View {
        VStack(alignment: .leading, spacing: Design.spacing) {
            ForEach(entries) { entry in
                OrderAgainItemCard(
                    entry: entry,
                    onTap: { handleItemTap(entry) }
                )
            }
        }
        .padding(Design.padding)
    }
    
    /**
     * Cart button in toolbar
     */
    private var cartToolbarButton: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button(action: { showingCart = true }) {
                ZStack {
                    Image(systemName: "cart")
                        .font(.system(size: Design.cartIconSize, weight: .medium))
                    
                    if cartManager.totalItems > 0 {
                        Text("\(cartManager.totalItems)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(minWidth: Design.cartBadgeSize, minHeight: Design.cartBadgeSize)
                            .background(Color.red)
                            .clipShape(Circle())
                            .offset(x: 10, y: -10)
                    }
                }
                .foregroundColor(.primary)
            }
        }
    }
    
    /**
     * Customization sheet for complex items
     */
    private func customizationSheet(for item: MenuItem) -> some View {
        DrinkCustomizationSheet(
            item: item,
            selectedModifiers: $selectedModifiers,
            initialSelectedSizeId: initialSelectedSizeId,
            onAdd: { total, description, selectedSizeId, selectedModifiers in
                handleCustomizationAdd(
                    item: item,
                    total: total,
                    description: description,
                    selectedSizeId: selectedSizeId,
                    selectedModifiers: selectedModifiers
                )
            },
            onCancel: { customizingItem = nil }
        )
    }
    
    // MARK: - Action Handlers
    
    /**
     * Handle tap on order again item
     */
    private func handleItemTap(_ entry: OrderAgainEntry) {
        let liveItem = entry.menuItem
        let hasCustomizations = hasItemCustomizations(liveItem)
        
        if !hasCustomizations {
            // Simple item - add directly to cart
            addSimpleItemToCart(liveItem)
        } else {
            // Complex item - open customization sheet
            openCustomizationSheet(for: liveItem, with: entry.key)
        }
    }
    
    /**
     * Add simple item directly to cart
     */
    private func addSimpleItemToCart(_ item: MenuItem) {
        let categoryName = getCategoryName(for: item.id)
        let success = cartManager.addItem(
            shop: shop,
            menuItem: item,
            category: categoryName
        )
        
        if success {
            ItemAddedPopup.show(isVisible: $showItemAddedPopup)
        }
    }
    
    /**
     * Open customization sheet with pre-selected options
     */
    private func openCustomizationSheet(for item: MenuItem, with key: RepeatKey) {
        customizingItem = item
        initialSelectedSizeId = key.selectedSizeId
        selectedModifiers.removeAll()
        
        if let modifierMap = key.selectedModifierIdsByList {
            for (listId, ids) in modifierMap {
                selectedModifiers[listId] = Set(ids)
            }
        }
    }
    
    /**
     * Handle adding customized item to cart
     */
    private func handleCustomizationAdd(
        item: MenuItem,
        total: Double,
        description: String,
        selectedSizeId: String?,
        selectedModifiers: [String: [String]]?
    ) {
        // Check if shop is open
        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
            showingClosedShopAlert = true
            customizingItem = nil
            return
        }
        
        let categoryName = getCategoryName(for: item.id)
        let success = cartManager.addItem(
            shop: shop,
            menuItem: item,
            category: categoryName,
            customizations: description,
            itemPriceWithModifiers: total,
            selectedSizeId: selectedSizeId,
            selectedModifierIdsByList: selectedModifiers
        )
        
        if success {
            ItemAddedPopup.show(isVisible: $showItemAddedPopup)
        }
        
        customizingItem = nil
    }
    
    // MARK: - Helper Methods
    
    /**
     * Check if item has customizations (sizes or modifiers)
     */
    private func hasItemCustomizations(_ item: MenuItem) -> Bool {
        let hasModifiers = item.modifierLists != nil && !(item.modifierLists?.isEmpty ?? true)
        let hasSizes = item.variations != nil && item.variations!.count > 1
        return hasModifiers || hasSizes
    }
    
    /**
     * Get category name for menu item
     */
    private func getCategoryName(for itemId: String) -> String {
        let categories = MenuDataManager.shared.getMenuCategories(for: shop)
        for category in categories {
            if category.items.contains(where: { $0.id == itemId }) {
                return category.name
            }
        }
        return "Other"
    }
}

// MARK: - Supporting Types

/**
 * Key for grouping similar order items
 */
private struct RepeatKey: Hashable, Equatable {
    let menuItemId: String
    let selectedSizeId: String?
    let selectedModifierIdsByList: [String: [String]]?
    
    static func == (lhs: RepeatKey, rhs: RepeatKey) -> Bool {
        guard lhs.menuItemId == rhs.menuItemId,
              lhs.selectedSizeId == rhs.selectedSizeId else {
            return false
        }
        return normalize(lhs.selectedModifierIdsByList) == normalize(rhs.selectedModifierIdsByList)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(menuItemId)
        hasher.combine(selectedSizeId)
        let lists = Self.normalize(selectedModifierIdsByList)
        for key in lists.keys.sorted() {
            hasher.combine(key)
            for value in (lists[key] ?? []) {
                hasher.combine(value)
            }
        }
    }
    
    private static func normalize(_ map: [String: [String]]?) -> [String: [String]] {
        guard let map = map else { return [:] }
        var normalized: [String: [String]] = [:]
        for (key, value) in map {
            normalized[key] = value.sorted()
        }
        return normalized
    }
}

/**
 * Entry for displaying order again items
 */
private struct OrderAgainEntry: Identifiable {
    let key: RepeatKey
    let count: Int
    let sample: CartItem
    let menuItem: MenuItem

    var id: RepeatKey { key }
}

// MARK: - OrderAgainItemCard

/**
 * Card component for displaying order again items
 */
private struct OrderAgainItemCard: View {
    let entry: OrderAgainEntry
    let onTap: () -> Void
    
    private enum Design {
        static let cornerRadius: CGFloat = 12
        static let shadowRadius: CGFloat = 8
        static let shadowOpacity: Double = 0.05
        static let thumbnailSize: CGFloat = 56
        static let spacing: CGFloat = 12
        static let padding: CGFloat = 16
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: Design.spacing) {
                // Item thumbnail
                itemThumbnail
                
                // Item details
                itemDetails
            }
            .padding(Design.padding)
            .background(Color.white)
            .cornerRadius(Design.cornerRadius)
            .shadow(
                color: Color.black.opacity(Design.shadowOpacity),
                radius: Design.shadowRadius,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    /**
     * Item thumbnail image
     */
    private var itemThumbnail: some View {
        Group {
            if let imageURL = entry.menuItem.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: Design.thumbnailSize, height: Design.thumbnailSize)
                            .clipped()
                            .cornerRadius(8)
                    default:
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                            .frame(width: Design.thumbnailSize, height: Design.thumbnailSize)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: Design.thumbnailSize, height: Design.thumbnailSize)
                    .overlay(
                        Image(systemName: "cup.and.saucer")
                            .foregroundColor(.gray)
                    )
            }
        }
    }
    
    /**
     * Item details section
     */
    private var itemDetails: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Item name and order count
            HStack {
                Text(entry.menuItem.name)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                Text("Ordered \(entry.count) times")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Customizations (if any)
            if let customizations = entry.sample.customizations, !customizations.isEmpty {
                Text(customizations)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            // Price
            Text(String(format: "$%.2f", entry.sample.itemPriceWithModifiers))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

struct OrderAgainItemsView_Previews: PreviewProvider {
    static var previews: some View {
        OrderAgainItemsView(shop: CoffeeShop(id: "sample", name: "Sample Shop", address: "123 Main St", latitude: 0, longitude: 0, phone: "555-0123", website: "https://example.com", description: "Sample coffee shop", imageName: "sample", stampName: "sample_stamp", merchantId: "sample_merchant", posType: .square))
            .environmentObject(OrderManager())
            .environmentObject(CartManager())
    }
}
