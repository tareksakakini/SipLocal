/**
 * CartItemRow.swift
 * SipLocal
 *
 * Individual cart item display component with quantity controls and customization parsing.
 * Extracted from CartView.swift for better organization and reusability.
 *
 * ## Features
 * - **Item Display**: Shows item name, size, and customizations
 * - **Quantity Controls**: Plus/minus buttons for quantity adjustment
 * - **Price Display**: Shows individual item total price
 * - **Customization Parsing**: Intelligently parses and displays customizations
 * - **Category Display**: Shows item category for context
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on cart item display and interaction
 * - **Reusable Component**: Can be used in any cart context
 * - **Clean Parsing**: Intelligent customization string parsing
 * - **Performance**: Efficient UI updates and state management
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

/**
 * Individual cart item row with quantity controls and customization display
 * 
 * Displays a cart item with its details, customizations, quantity controls,
 * and total price. Handles intelligent parsing of customization strings.
 */
struct CartItemRow: View {
    
    // MARK: - Properties
    
    let cartItem: CartItem
    @EnvironmentObject var cartManager: CartManager
    
    // MARK: - Design System
    
    private enum Design {
        // Layout
        static let spacing: CGFloat = 16
        static let itemSpacing: CGFloat = 4
        static let modifierSpacing: CGFloat = 2
        static let quantitySpacing: CGFloat = 8
        static let buttonSpacing: CGFloat = 12
        static let padding: CGFloat = 16
        
        // Typography
        static let itemNameFont: Font = .headline
        static let itemNameWeight: Font.Weight = .semibold
        static let sizeFont: Font = .subheadline
        static let sizeWeight: Font.Weight = .medium
        static let modifierFont: Font = .caption2
        static let categoryFont: Font = .subheadline
        static let quantityFont: Font = .headline
        static let quantityWeight: Font.Weight = .semibold
        static let priceFont: Font = .subheadline
        static let priceWeight: Font.Weight = .semibold
        
        // Colors
        static let sizeColor: Color = .blue
        static let modifierColor: Color = .secondary
        static let categoryColor: Color = .secondary
        static let minusButtonColor: Color = .gray
        static let plusButtonColor: Color = .black
        
        // Sizing
        static let quantityMinWidth: CGFloat = 20
        static let cornerRadius: CGFloat = 12
        static let shadowOpacity: Double = 0.05
        static let shadowRadius: CGFloat = 8
        static let shadowOffset: CGSize = CGSize(width: 0, height: 2)
        
        // Spacing
        static let verticalPadding: CGFloat = 1
    }
    
    // MARK: - Body
    
    var body: some View {
        let (size, mods) = conciseCustomizations()
        
        HStack(spacing: Design.spacing) {
            // Item details section
            itemDetailsSection(size: size, mods: mods)
            
            Spacer()
            
            // Quantity and price section
            quantityAndPriceSection
        }
        .padding(Design.padding)
        .background(Color.white)
        .cornerRadius(Design.cornerRadius)
        .shadow(
            color: Color.black.opacity(Design.shadowOpacity),
            radius: Design.shadowRadius,
            x: Design.shadowOffset.width,
            y: Design.shadowOffset.height
        )
    }
    
    // MARK: - View Components
    
    /**
     * Item details section with name, size, customizations, and category
     */
    private func itemDetailsSection(size: String?, mods: [String]) -> some View {
        VStack(alignment: .leading, spacing: Design.itemSpacing) {
            // Item name
            Text(cartItem.menuItem.name)
                .font(Design.itemNameFont)
                .fontWeight(Design.itemNameWeight)
            
            // Size display
            if let size = size {
                Text(size)
                    .font(Design.sizeFont)
                    .fontWeight(Design.sizeWeight)
                    .foregroundColor(Design.sizeColor)
                    .padding(.vertical, Design.verticalPadding)
            }
            
            // Customizations display
            if !mods.isEmpty {
                customizationsSection(mods: mods)
            }
            
            // Category display
            Text(cartItem.category)
                .font(Design.categoryFont)
                .foregroundColor(Design.categoryColor)
        }
    }
    
    /**
     * Customizations section with modifier details
     */
    private func customizationsSection(mods: [String]) -> some View {
        VStack(alignment: .leading, spacing: Design.modifierSpacing) {
            ForEach(mods, id: \.self) { mod in
                Text(mod)
                    .font(Design.modifierFont)
                    .foregroundColor(Design.modifierColor)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, Design.verticalPadding)
    }
    
    /**
     * Quantity controls and price section
     */
    private var quantityAndPriceSection: some View {
        VStack(spacing: Design.quantitySpacing) {
            // Quantity controls
            quantityControls
            
            // Price display
            Text("$\(cartItem.totalPrice, specifier: "%.2f")")
                .font(Design.priceFont)
                .fontWeight(Design.priceWeight)
        }
    }
    
    /**
     * Quantity control buttons and display
     */
    private var quantityControls: some View {
        HStack(spacing: Design.buttonSpacing) {
            // Decrease quantity button
            Button(action: {
                cartManager.updateQuantity(cartItem: cartItem, quantity: cartItem.quantity - 1)
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(Design.minusButtonColor)
            }
            
            // Quantity display
            Text("\(cartItem.quantity)")
                .font(Design.quantityFont)
                .fontWeight(Design.quantityWeight)
                .frame(minWidth: Design.quantityMinWidth)
            
            // Increase quantity button
            Button(action: {
                cartManager.updateQuantity(cartItem: cartItem, quantity: cartItem.quantity + 1)
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(Design.plusButtonColor)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Extract concise customizations from the customization string
     * 
     * Parses the customization string and returns size and modifier information
     * in a clean, displayable format.
     */
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
    
    /**
     * Simplify modifier names for cleaner display
     * 
     * Converts verbose modifier names to shorter, more user-friendly versions.
     */
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
}

// MARK: - Preview

struct CartItemRow_Previews: PreviewProvider {
    static var previews: some View {
        let sampleCartItem = CartItem(
            shop: CoffeeShop(
                id: "sample_shop",
                name: "Sample Coffee Shop",
                address: "123 Main St",
                latitude: 0,
                longitude: 0,
                phone: "555-0123",
                website: "https://example.com",
                description: "Sample shop",
                imageName: "sample",
                stampName: "sample_stamp",
                merchantId: "sample_merchant",
                posType: .square
            ),
            menuItem: MenuItem(
                id: "americano",
                name: "Americano",
                price: 3.50,
                variations: nil,
                customizations: ["size", "milk"],
                imageURL: nil,
                modifierLists: nil
            ),
            category: "Hot Coffee",
            quantity: 2,
            customizations: "Size: Large | Milk Options: Oat Milk | Add-ons: Extra Shot, Vanilla Syrup",
            itemPriceWithModifiers: 5.25,
            selectedSizeId: "large",
            selectedModifierIdsByList: ["size": ["large"], "milk": ["oat"], "addons": ["extra_shot", "vanilla"]]
        )
        
        VStack(spacing: 16) {
            CartItemRow(cartItem: sampleCartItem)
                .environmentObject(CartManager())
            
            CartItemRow(cartItem: CartItem(
                shop: sampleCartItem.shop,
                menuItem: MenuItem(
                    id: "drip_coffee",
                    name: "Drip Coffee",
                    price: 2.75,
                    variations: nil,
                    customizations: nil,
                    imageURL: nil,
                    modifierLists: nil
                ),
                category: "Hot Coffee",
                quantity: 1,
                customizations: nil,
                itemPriceWithModifiers: 2.75,
                selectedSizeId: nil,
                selectedModifierIdsByList: nil
            ))
            .environmentObject(CartManager())
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
