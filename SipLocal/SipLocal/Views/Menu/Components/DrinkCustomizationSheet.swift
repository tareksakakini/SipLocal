/**
 * DrinkCustomizationSheet.swift
 * SipLocal
 *
 * Full-screen customization sheet for menu items with sizes and modifiers.
 * Extracted from MenuItemsView.swift for better organization.
 *
 * ## Features
 * - **Size Selection**: Integration with SizeSelectionView for size variations
 * - **Modifier Management**: Support for single and multiple selection modifiers
 * - **Price Calculation**: Real-time price updates based on selections
 * - **Customization Description**: Builds detailed description for cart items
 * - **Add to Cart**: Complete customization flow with validation
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on item customization flow
 * - **Reusable Component**: Can be used for any menu item customization
 * - **State Management**: Clean binding-based state with callbacks
 * - **Performance**: Efficient price calculations and UI updates
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

// MARK: - DrinkCustomizationSheet

/**
 * Full-screen sheet for customizing menu items
 * 
 * Provides a complete customization experience with size selection,
 * modifier options, real-time pricing, and add-to-cart functionality.
 */
struct DrinkCustomizationSheet: View {
    
    // MARK: - Properties
    let item: MenuItem
    @Binding var selectedModifiers: [String: Set<String>]
    var initialSelectedSizeId: String? = nil
    var onAdd: (Double, String, String?, [String: [String]]?) -> Void
    var onCancel: () -> Void
    
    // MARK: - State
    @State private var selectedSizeId: String?
    
    // MARK: - Design System
    private enum Design {
        static let contentSpacing: CGFloat = 24
        static let contentPadding: CGFloat = 16
        static let footerSpacing: CGFloat = 12
        static let priceFont: Font = .title2
        static let priceWeight: Font.Weight = .bold
        static let buttonCornerRadius: CGFloat = 12
        static let buttonPadding: CGFloat = 16
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Main content
                customizationContent
                
                // Footer with price and add button
                customizationFooter
            }
            .background(Color(.systemGray6))
            .navigationTitle("Customize \(item.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .onAppear {
            initializeSizeSelection()
        }
    }
    
    // MARK: - View Components
    
    /**
     * Main customization content area
     */
    private var customizationContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Design.contentSpacing) {
                // Size selection (if applicable)
                sizeSelectionSection
                
                // Modifier sections
                modifierSections
                
                // No options message (if applicable)
                noOptionsMessage
            }
            .padding(Design.contentPadding)
        }
    }
    
    /**
     * Size selection section
     */
    @ViewBuilder
    private var sizeSelectionSection: some View {
        if let variations = item.variations, variations.count > 1 {
            SizeSelectionView(
                variations: variations,
                selectedSizeId: $selectedSizeId
            )
        }
    }
    
    /**
     * Modifier sections
     */
    @ViewBuilder
    private var modifierSections: some View {
        if let modifierLists = item.modifierLists {
            ForEach(modifierLists) { modifierList in
                ModifierListSection(
                    modifierList: modifierList,
                    selectedModifiers: Binding(
                        get: { selectedModifiers[modifierList.id] ?? [] },
                        set: { selectedModifiers[modifierList.id] = $0 }
                    )
                )
            }
        }
    }
    
    /**
     * No options message
     */
    @ViewBuilder
    private var noOptionsMessage: some View {
        if item.modifierLists == nil && (item.variations == nil || item.variations!.count <= 1) {
            Text("No customization options available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding()
        }
    }
    
    /**
     * Footer with price and add button
     */
    private var customizationFooter: some View {
        VStack(spacing: Design.footerSpacing) {
            Divider()
            
            // Price display
            priceDisplay
            
            // Add to cart button
            addToCartButton
        }
        .background(Color(.systemGray6))
    }
    
    /**
     * Price display section
     */
    private var priceDisplay: some View {
        HStack {
            Text("Price")
                .font(.headline)
            
            Spacer()
            
            Text("$\(totalPrice, specifier: "%.2f")")
                .font(Design.priceFont)
                .fontWeight(Design.priceWeight)
        }
        .padding(.horizontal, Design.contentPadding)
    }
    
    /**
     * Add to cart button
     */
    private var addToCartButton: some View {
        Button(action: addToCart) {
            Text("Add to Cart")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(Design.buttonPadding)
                .background(Color.black)
                .cornerRadius(Design.buttonCornerRadius)
        }
        .padding(.horizontal, Design.contentPadding)
        .padding(.bottom, Design.contentPadding)
    }
    
    // MARK: - Computed Properties
    
    /**
     * Calculate total price including size and modifiers
     */
    private var totalPrice: Double {
        var total: Double = 0.0
        
        // Get size price (full price, not incremental)
        if let variations = item.variations, variations.count > 1 {
            if let selectedSizeId = selectedSizeId,
               let selectedVariation = variations.first(where: { $0.id == selectedSizeId }) {
                total = selectedVariation.price
            } else {
                // Default to first variation if nothing selected
                total = variations.first?.price ?? item.basePrice
            }
        } else {
            // No size variations, use base price
            total = item.basePrice
        }
        
        // Add other modifier pricing (incremental)
        guard let modifierLists = item.modifierLists else { return total }
        
        for modifierList in modifierLists {
            if let selectedModifierIds = selectedModifiers[modifierList.id] {
                for modifier in modifierList.modifiers {
                    if selectedModifierIds.contains(modifier.id) {
                        total += modifier.price
                    }
                }
            }
        }
        
        return total
    }
    
    // MARK: - Helper Methods
    
    /**
     * Initialize size selection on appear
     */
    private func initializeSizeSelection() {
        if selectedSizeId == nil {
            if let initial = initialSelectedSizeId {
                selectedSizeId = initial
            } else if let variations = item.variations,
                      variations.count > 1,
                      let firstVariation = variations.first {
                selectedSizeId = firstVariation.id
            }
        }
    }
    
    /**
     * Build complete customization description
     */
    private func buildCustomizationDescription() -> String {
        var desc: [String] = []
        
        // Add size if multiple variations exist
        if let variations = item.variations, variations.count > 1,
           let selectedSizeId = selectedSizeId,
           let selectedVariation = variations.first(where: { $0.id == selectedSizeId }) {
            desc.append("Size: \(selectedVariation.name)")
        }
        
        // Add other modifiers (only non-default ones)
        guard let modifierLists = item.modifierLists else {
            return desc.joined(separator: " | ")
        }
        
        for modifierList in modifierLists {
            if let selectedModifierIds = selectedModifiers[modifierList.id], !selectedModifierIds.isEmpty {
                let modifierNames = modifierList.modifiers.compactMap { modifier in
                    if selectedModifierIds.contains(modifier.id) && !modifier.isDefault {
                        return modifier.name
                    }
                    return nil
                }
                
                if !modifierNames.isEmpty {
                    desc.append("\(modifierList.name): \(modifierNames.joined(separator: ", "))")
                }
            }
        }
        
        return desc.joined(separator: " | ")
    }
    
    /**
     * Handle add to cart action
     */
    private func addToCart() {
        // Convert selection binding to plain [String: [String]] for persistence
        var modsOut: [String: [String]] = [:]
        for (listId, setIds) in selectedModifiers {
            modsOut[listId] = Array(setIds)
        }
        
        onAdd(
            totalPrice,
            buildCustomizationDescription(),
            selectedSizeId,
            modsOut.isEmpty ? nil : modsOut
        )
    }
    
    /**
     * Helper to create a modifier list from size variations
     */
    private func createSizeModifierList(from variations: [MenuItemVariation]) -> MenuItemModifierList {
        let sizeModifiers = variations.map { variation in
            MenuItemModifier(
                id: variation.id,
                name: variation.name,
                price: variation.price - variations.first!.price, // Price difference from base
                isDefault: variation.id == variations.first?.id // First variation is default
            )
        }
        
        return MenuItemModifierList(
            id: "size_variations",
            name: "Size",
            selectionType: "SINGLE",
            minSelections: 1,
            maxSelections: 1,
            modifiers: sizeModifiers
        )
    }
}

// MARK: - Preview

struct DrinkCustomizationSheet_Previews: PreviewProvider {
    static var previews: some View {
        let sampleItem = MenuItem(
            id: "sample",
            name: "Sample Coffee",
            price: 4.50,
            variations: [
                MenuItemVariation(id: "small", name: "Small", price: 4.50, ordinal: 1),
                MenuItemVariation(id: "large", name: "Large", price: 5.50, ordinal: 2)
            ],
            customizations: nil,
            imageURL: nil,
            modifierLists: [
                MenuItemModifierList(
                    id: "milk",
                    name: "Milk",
                    selectionType: "SINGLE",
                    minSelections: 1,
                    maxSelections: 1,
                    modifiers: [
                        MenuItemModifier(id: "whole", name: "Whole Milk", price: 0.0, isDefault: true),
                        MenuItemModifier(id: "oat", name: "Oat Milk", price: 0.75, isDefault: false)
                    ]
                )
            ]
        )
        
        DrinkCustomizationSheet(
            item: sampleItem,
            selectedModifiers: .constant([:]),
            onAdd: { total, description, sizeId, modifiers in
                print("Add to cart: \(total), \(description)")
            },
            onCancel: {
                print("Cancel customization")
            }
        )
    }
}
