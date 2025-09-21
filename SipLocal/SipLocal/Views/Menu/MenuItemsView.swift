/**
 * MenuItemsView.swift
 * SipLocal
 *
 * Main menu items view displaying items in a category with grid layout.
 * Refactored with clean architecture and MVVM pattern.
 *
 * ## Features
 * - **Grid Layout**: 3-column responsive grid for menu items
 * - **Category Header**: Shop name, category icon, and item count
 * - **Customization Flow**: Handle item customization through sheets
 * - **Cart Integration**: Add items with validation and conflict resolution
 * - **Business Hours**: Check shop availability before adding items
 * - **Navigation**: Back button and cart access
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses MenuItemsViewModel for business logic
 * - **Component-Based**: Uses extracted components (MenuItemCard, DrinkCustomizationSheet)
 * - **Clean Separation**: UI logic separated from business logic
 * - **Reactive State**: Responds to ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

struct MenuItemsView: View {
    
    // MARK: - Properties
    
    let shop: CoffeeShop
    let category: MenuCategory
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var viewModel: MenuItemsViewModel
    
    // MARK: - Initialization
    
    /**
     * Initialize with shop and category
     */
    init(shop: CoffeeShop, category: MenuCategory) {
        self.shop = shop
        self.category = category
        self._viewModel = StateObject(wrappedValue: MenuItemsViewModel(cartManager: CartManager()))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: MenuItemsViewModel.Design.sectionSpacing) {
                    // Header section
                    categoryHeader
                    
                    // Menu items grid
                    menuItemsGrid
                    
                    Spacer(minLength: MenuItemsViewModel.Design.bottomSpacer)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    cartButton
                }
            }
            .sheet(isPresented: $viewModel.showingCart) {
                CartView()
                    .environmentObject(cartManager)
            }
            .sheet(item: $viewModel.customizingItem) { item in
                customizationSheet(for: item)
            }
            .alert("Different Coffee Shop", isPresented: $viewModel.showingDifferentShopAlert) {
                Button("Clear Cart & Add Item", role: .destructive) {
                    viewModel.handleCartConflictResolution(shop: shop, category: category)
                }
                Button("Cancel", role: .cancel) {
                    viewModel.pendingItem = nil
                }
            } message: {
                Text("Your cart contains items from a different coffee shop. To add this item, you need to clear your current cart first.")
            }
            .alert("Shop is Closed", isPresented: $viewModel.showingClosedShopAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This coffee shop is currently closed. Please try again during business hours.")
            }
            .onAppear {
                viewModel.updateCartManager(cartManager)
                viewModel.fetchBusinessHours(for: shop)
            }
            .overlay {
                itemAddedPopup
            }
        }
    }
    
    // MARK: - View Components
    
    /**
     * Category header with shop name, icon, and item count
     */
    private var categoryHeader: some View {
        VStack(alignment: .leading, spacing: MenuItemsViewModel.Design.headerSpacing) {
            Text(shop.name)
                .font(.title)
                .fontWeight(.semibold)
            
            HStack {
                Image(systemName: viewModel.categoryIcon(for: category.name))
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text(category.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }
            
            Text("\(category.items.count) items available")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, MenuItemsViewModel.Design.horizontalPadding)
        .padding(.top, MenuItemsViewModel.Design.topPadding)
    }
    
    /**
     * Menu items grid layout
     */
    private var menuItemsGrid: some View {
        LazyVGrid(columns: MenuItemsViewModel.Design.gridColumns, spacing: MenuItemsViewModel.Design.gridSpacing) {
            ForEach(category.items) { item in
                MenuItemCard(
                    item: item,
                    shop: shop,
                    category: category.name,
                    cartManager: cartManager,
                    onAdd: {
                        viewModel.handleAddItem(item, shop: shop, category: category)
                    }
                )
            }
        }
        .padding(.horizontal, MenuItemsViewModel.Design.horizontalPadding)
    }
    
    /**
     * Back navigation button
     */
    private var backButton: some View {
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
    
    /**
     * Cart button with item count badge
     */
    private var cartButton: some View {
        Button(action: {
            viewModel.showingCart = true
        }) {
            ZStack {
                Image(systemName: "cart")
                    .font(.system(size: 20, weight: .medium))
                
                if cartManager.totalItems > 0 {
                    Text("\(cartManager.totalItems)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 10, y: -10)
                }
            }
            .foregroundColor(.primary)
        }
    }
    
    /**
     * Customization sheet for menu items
     */
    private func customizationSheet(for item: MenuItem) -> some View {
        DrinkCustomizationSheet(
            item: item,
            selectedModifiers: $viewModel.selectedModifiers,
            initialSelectedSizeId: viewModel.initialSelectedSizeId,
            onAdd: { totalPrice, customizationDesc, selectedSizeId, selectedMods in
                viewModel.handleCustomizationComplete(
                    item: item,
                    shop: shop,
                    category: category,
                    totalPrice: totalPrice,
                    customizationDesc: customizationDesc,
                    selectedSizeId: selectedSizeId,
                    selectedMods: selectedMods
                )
            },
            onCancel: {
                viewModel.cancelCustomization()
            }
        )
        .onDisappear {
            viewModel.initialSelectedSizeId = nil
        }
    }
    
    /**
     * Item added success popup
     */
    @ViewBuilder
    private var itemAddedPopup: some View {
        if viewModel.showItemAddedPopup {
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Text("Item added")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, MenuItemsViewModel.Design.popupHorizontalPadding)
                        .padding(.vertical, MenuItemsViewModel.Design.popupVerticalPadding)
                        .background(Color.black.opacity(MenuItemsViewModel.Design.popupBackgroundOpacity))
                        .cornerRadius(MenuItemsViewModel.Design.popupCornerRadius)
                        .shadow(radius: MenuItemsViewModel.Design.popupShadowRadius)
                    Spacer()
                }
                .padding(.bottom, MenuItemsViewModel.Design.popupBottomPadding)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.easeInOut(duration: MenuItemsViewModel.Design.popupAnimationDuration), value: viewModel.showItemAddedPopup)
        }
    }
}





struct MenuItemsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = CoffeeShopDataService.loadCoffeeShops().first!
        
        // Create sample modifier lists to demonstrate different picker types
        
        // Size modifier list (3 options - will use segmented picker)
        let sizeModifierList = MenuItemModifierList(
            id: "size_list",
            name: "Size",
            selectionType: "SINGLE",
            minSelections: 1,
            maxSelections: 1,
            modifiers: [
                MenuItemModifier(id: "small", name: "Small", price: 0.0, isDefault: false),
                MenuItemModifier(id: "medium", name: "Medium", price: 0.50, isDefault: true),
                MenuItemModifier(id: "large", name: "Large", price: 1.00, isDefault: false)
            ]
        )
        
        // Milk modifier list (6 options - will use wheel picker)
        let milkModifierList = MenuItemModifierList(
            id: "milk_list",
            name: "Milk Options",
            selectionType: "SINGLE",
            minSelections: 1,
            maxSelections: 1,
            modifiers: [
                MenuItemModifier(id: "whole", name: "Whole Milk", price: 0.0, isDefault: true),
                MenuItemModifier(id: "skim", name: "Skim Milk", price: 0.0, isDefault: false),
                MenuItemModifier(id: "almond", name: "Almond Milk", price: 0.65, isDefault: false),
                MenuItemModifier(id: "oat", name: "Oat Milk", price: 0.65, isDefault: false),
                MenuItemModifier(id: "soy", name: "Soy Milk", price: 0.60, isDefault: false),
                MenuItemModifier(id: "coconut", name: "Coconut Milk", price: 0.70, isDefault: false)
            ]
        )
        
        // Add-ons modifier list (multiple selection - will use checkbox list)
        let addonsModifierList = MenuItemModifierList(
            id: "addons_list",
            name: "Add-ons",
            selectionType: "MULTIPLE",
            minSelections: 0,
            maxSelections: 3,
            modifiers: [
                MenuItemModifier(id: "extra_shot", name: "Extra Shot", price: 0.75, isDefault: false),
                MenuItemModifier(id: "decaf", name: "Make it Decaf", price: 0.0, isDefault: false),
                MenuItemModifier(id: "whipped_cream", name: "Whipped Cream", price: 0.50, isDefault: false),
                MenuItemModifier(id: "vanilla_syrup", name: "Vanilla Syrup", price: 0.60, isDefault: false),
                MenuItemModifier(id: "caramel_syrup", name: "Caramel Syrup", price: 0.60, isDefault: false)
            ]
        )
        
        // Sample items with different modifier combinations
        let sampleCategory = MenuCategory(name: "Hot Coffee", items: [
            // Item with all three types of modifiers
            MenuItem(
                id: "item_americano",
                name: "Americano",
                price: 3.50,
                variations: nil,
                customizations: ["size", "milk", "other"],
                imageURL: nil,
                modifierLists: [sizeModifierList, milkModifierList, addonsModifierList]
            ),
            // Item with just size (segmented picker)
            MenuItem(
                id: "item_espresso",
                name: "Espresso",
                price: 2.25,
                variations: nil,
                customizations: ["size"],
                imageURL: nil,
                modifierLists: [sizeModifierList]
            ),
            // Item with size and milk (segmented + wheel)
            MenuItem(
                id: "item_latte",
                name: "Latte",
                price: 4.25,
                variations: nil,
                customizations: ["size", "milk"],
                imageURL: nil,
                modifierLists: [sizeModifierList, milkModifierList]
            ),
            // Item with no modifiers
            MenuItem(
                id: "item_drip_coffee",
                name: "Drip Coffee",
                price: 2.75,
                variations: nil,
                customizations: nil,
                imageURL: nil,
                modifierLists: nil
            )
        ])
        
        MenuItemsView(shop: sampleShop, category: sampleCategory)
            .environmentObject(CartManager())
    }
} 
