/**
 * MenuItemsViewModel.swift
 * SipLocal
 *
 * ViewModel for MenuItemsView - handles menu item display, customization,
 * cart operations, and business logic separation.
 *
 * ## Features
 * - **Menu Item Management**: Display and organization of menu items
 * - **Customization Flow**: Handle item customization and modifier selection
 * - **Cart Operations**: Add items to cart with validation
 * - **Business Hours**: Check shop availability
 * - **State Management**: Manage UI state and user interactions
 * - **Error Handling**: Handle cart conflicts and shop closures
 *
 * ## Architecture
 * - **MVVM Pattern**: Separates business logic from UI
 * - **Dependency Injection**: Receives CartManager and other services
 * - **Reactive State**: Uses @Published for UI updates
 * - **Error Boundaries**: Structured error handling
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

/**
 * ViewModel for MenuItemsView
 * 
 * Manages menu item display, customization flow, cart operations,
 * and business logic for the menu items view.
 */
@MainActor
class MenuItemsViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Currently customizing item
    @Published var customizingItem: MenuItem? = nil
    
    /// Initial selected size ID for customization
    @Published var initialSelectedSizeId: String? = nil
    
    /// Show different shop alert
    @Published var showingDifferentShopAlert = false
    
    /// Show closed shop alert
    @Published var showingClosedShopAlert = false
    
    /// Pending item for cart conflict resolution
    @Published var pendingItem: (item: MenuItem, customizations: String?, price: Double)?
    
    /// Modifier selections - maps modifier list ID to selected modifier IDs
    @Published var selectedModifiers: [String: Set<String>] = [:]
    
    /// Show item added popup
    @Published var showItemAddedPopup = false
    
    /// Show cart view
    @Published var showingCart = false
    
    // MARK: - Dependencies
    
    private var cartManager: CartManager
    private let menuDataManager: MenuDataManager
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Constants
    
    private enum Constants {
        static let popupDisplayDuration: TimeInterval = 1.5
        static let popupAnimationDuration: TimeInterval = 0.3
        static let gridColumns = 3
        static let gridSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
        static let headerSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomSpacer: CGFloat = 100
    }
    
    // MARK: - Initialization
    
    /**
     * Initialize with dependencies
     */
    init(cartManager: CartManager, menuDataManager: MenuDataManager = MenuDataManager.shared) {
        self.cartManager = cartManager
        self.menuDataManager = menuDataManager
        
        setupNotificationObservers()
    }
    
    // MARK: - Public Methods
    
    /**
     * Update the CartManager reference
     */
    func updateCartManager(_ cartManager: CartManager) {
        self.cartManager = cartManager
    }
    
    /**
     * Handle adding item to cart
     */
    func handleAddItem(_ item: MenuItem, shop: CoffeeShop, category: MenuCategory) {
        // Check if shop is closed
        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
            showingClosedShopAlert = true
            return
        }
        
        // Check if item has customizations
        let hasCustomizations = hasItemCustomizations(item)
        
        if !hasCustomizations {
            addSimpleItemToCart(item, shop: shop, category: category)
        } else {
            startCustomizationFlow(for: item)
        }
    }
    
    /**
     * Handle customization completion
     */
    func handleCustomizationComplete(
        item: MenuItem,
        shop: CoffeeShop,
        category: MenuCategory,
        totalPrice: Double,
        customizationDesc: String?,
        selectedSizeId: String?,
        selectedMods: [String: [String]]?
    ) {
        // Check if shop is closed
        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
            showingClosedShopAlert = true
            customizingItem = nil
            return
        }
        
        // Add to cart with customizations
        let success = cartManager.addItem(
            shop: shop,
            menuItem: item,
            category: category.name,
            customizations: customizationDesc,
            itemPriceWithModifiers: totalPrice,
            selectedSizeId: selectedSizeId,
            selectedModifierIdsByList: selectedMods
        )
        
        if success {
            customizingItem = nil
            showItemAddedSuccess()
        } else {
            // Store pending item and show alert
            pendingItem = (item: item, customizations: customizationDesc, price: totalPrice)
            showingDifferentShopAlert = true
            customizingItem = nil
        }
    }
    
    /**
     * Handle cart conflict resolution
     */
    func handleCartConflictResolution(shop: CoffeeShop, category: MenuCategory) {
        cartManager.clearCart()
        
        if let pending = pendingItem {
            let _ = cartManager.addItem(
                shop: shop,
                menuItem: pending.item,
                category: category.name,
                customizations: pending.customizations,
                itemPriceWithModifiers: pending.price
            )
            showItemAddedSuccess()
        }
        
        pendingItem = nil
    }
    
    /**
     * Cancel customization
     */
    func cancelCustomization() {
        customizingItem = nil
    }
    
    /**
     * Fetch business hours for shop
     */
    func fetchBusinessHours(for shop: CoffeeShop) {
        Task {
            await cartManager.fetchBusinessHours(for: shop)
        }
    }
    
    /**
     * Get category icon for display
     */
    func categoryIcon(for categoryName: String) -> String {
        switch categoryName.lowercased() {
        case "hot":
            return "cup.and.saucer.fill"
        case "iced":
            return "snowflake"
        case "frappe":
            return "hurricane"
        default:
            return "cup.and.saucer"
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Check if item has customizations
     */
    private func hasItemCustomizations(_ item: MenuItem) -> Bool {
        let hasModifierLists = item.modifierLists != nil && !(item.modifierLists?.isEmpty ?? true)
        let hasVariations = item.variations != nil && item.variations!.count > 1
        return hasModifierLists || hasVariations
    }
    
    /**
     * Add simple item to cart (no customizations)
     */
    private func addSimpleItemToCart(_ item: MenuItem, shop: CoffeeShop, category: MenuCategory) {
        let success = cartManager.addItem(shop: shop, menuItem: item, category: category.name)
        
        if success {
            showItemAddedSuccess()
        } else {
            pendingItem = (item: item, customizations: nil, price: item.price)
            showingDifferentShopAlert = true
        }
    }
    
    /**
     * Start customization flow for item
     */
    private func startCustomizationFlow(for item: MenuItem) {
        customizingItem = item
        initializeModifierSelections(for: item)
    }
    
    /**
     * Show item added success popup
     */
    private func showItemAddedSuccess() {
        showItemAddedPopup = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.popupDisplayDuration) {
            withAnimation(.easeInOut(duration: Constants.popupAnimationDuration)) {
                self.showItemAddedPopup = false
            }
        }
    }
    
    /**
     * Initialize modifier selections with default values
     */
    private func initializeModifierSelections(for item: MenuItem) {
        selectedModifiers.removeAll()
        
        guard let modifierLists = item.modifierLists else { return }
        
        for modifierList in modifierLists {
            initializeDefaultsForModifierList(modifierList)
        }
    }
    
    /**
     * Initialize defaults for a modifier list
     */
    private func initializeDefaultsForModifierList(_ modifierList: MenuItemModifierList) {
        var defaultSelections: Set<String> = []
        
        // Find default modifiers
        for modifier in modifierList.modifiers {
            if modifier.isDefault {
                defaultSelections.insert(modifier.id)
            }
        }
        
        // If no defaults found, select first modifier as fallback
        if defaultSelections.isEmpty {
            if modifierList.selectionType == "SINGLE" || modifierList.maxSelections == 1 {
                // Single selection - always select first option
                if let firstModifier = modifierList.modifiers.first {
                    defaultSelections.insert(firstModifier.id)
                }
            } else if modifierList.minSelections > 0 {
                // Multiple selection - only preselect if minimum required
                if let firstModifier = modifierList.modifiers.first {
                    defaultSelections.insert(firstModifier.id)
                }
            }
        }
        
        selectedModifiers[modifierList.id] = defaultSelections
    }
    
    /**
     * Setup notification observers
     */
    private func setupNotificationObservers() {
        NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExploreTab"))
            .sink { [weak self] _ in
                self?.showingCart = false
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Helper Methods
    
    /**
     * Create size modifier list from variations
     */
    func createSizeModifierList(from variations: [MenuItemVariation]) -> MenuItemModifierList {
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
    
    /**
     * Build customization description
     */
    func customizationDescription(for item: MenuItem) -> String {
        var desc: [String] = []
        
        guard let modifierLists = item.modifierLists else { 
            return desc.joined(separator: " | ")
        }
        
        var modifierDesc: [String] = []
        
        for modifierList in modifierLists {
            if let selectedModifierIds = selectedModifiers[modifierList.id], !selectedModifierIds.isEmpty {
                let isSize = modifierList.name.lowercased().contains("size")
                
                let modifierNames = modifierList.modifiers.compactMap { modifier in
                    if selectedModifierIds.contains(modifier.id) {
                        // Always include size modifiers, only include non-default for others
                        if isSize || !modifier.isDefault {
                            return modifier.name
                        }
                    }
                    return nil
                }
                
                if !modifierNames.isEmpty {
                    modifierDesc.append("\(modifierList.name): \(modifierNames.joined(separator: ", "))")
                }
            }
        }
        
        // Combine size description with other modifier descriptions
        desc.append(contentsOf: modifierDesc)
        
        return desc.joined(separator: " | ")
    }
}

// MARK: - Design System

extension MenuItemsViewModel {
    
    /**
     * Design system constants for the view
     */
    enum Design {
        static let gridColumns = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        static let gridSpacing: CGFloat = 12
        static let sectionSpacing: CGFloat = 24
        static let headerSpacing: CGFloat = 8
        static let horizontalPadding: CGFloat = 16
        static let topPadding: CGFloat = 16
        static let bottomSpacer: CGFloat = 100
        
        // Popup design
        static let popupBackgroundOpacity: Double = 0.85
        static let popupCornerRadius: CGFloat = 16
        static let popupShadowRadius: CGFloat = 8
        static let popupBottomPadding: CGFloat = 40
        static let popupHorizontalPadding: CGFloat = 24
        static let popupVerticalPadding: CGFloat = 12
        
        // Animation
        static let popupDisplayDuration: TimeInterval = 1.5
        static let popupAnimationDuration: TimeInterval = 0.3
    }
}
