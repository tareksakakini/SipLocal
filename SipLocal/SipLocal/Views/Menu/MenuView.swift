/**
 * MenuView.swift
 * SipLocal
 *
 * Main menu view displaying shop menu with categories and items.
 * Refactored with clean architecture and MVVM pattern.
 *
 * ## Features
 * - **Menu Display**: Shows menu categories and items in organized layout
 * - **Loading States**: Handles loading, error, and empty states
 * - **Navigation**: Back button and category/item navigation
 * - **Error Handling**: Retry functionality for failed loads
 * - **Performance**: Optimized loading with caching and background refresh
 *
 * ## Architecture
 * - **MVVM Pattern**: Uses MenuViewModel for business logic
 * - **Component-Based**: Uses extracted components (LoadingView, ErrorView, etc.)
 * - **Clean Separation**: UI logic separated from business logic
 * - **Reactive State**: Responds to ViewModel state changes
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI

struct MenuView: View {
    
    // MARK: - Properties
    
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var viewModel: MenuViewModel
    
    // MARK: - Initialization
    
    /**
     * Initialize with coffee shop
     */
    init(shop: CoffeeShop) {
        self.shop = shop
        self._viewModel = StateObject(wrappedValue: MenuViewModel(shop: shop))
    }
    
    // MARK: - Body
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Design.spacing.large) {
                    headerSection
                    contentSection
                    Spacer(minLength: Design.spacing.bottomPadding)
                }
            }
            .background(Design.colors.background)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    backButton
                }
            }
            .task {
                await viewModel.loadMenuData()
            }
            .refreshable {
                await viewModel.refreshMenuData()
            }
        }
    }
    
    // MARK: - View Components
    
    /**
     * Header section with shop name and menu title
     */
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: Design.spacing.small) {
            Text(shop.name)
                .font(Design.fonts.shopName)
                .fontWeight(Design.fonts.shopNameWeight)
            
            Text(Design.text.menuTitle)
                .font(Design.fonts.menuTitle)
                .foregroundColor(Design.colors.secondary)
        }
        .padding(.horizontal, Design.spacing.horizontal)
        .padding(.top, Design.spacing.top)
    }
    
    /**
     * Content section based on loading state
     */
    private var contentSection: some View {
        Group {
            if viewModel.isLoading {
                LoadingView()
            } else if let errorMessage = viewModel.errorMessage {
                ErrorView(errorMessage: errorMessage) {
                    Task {
                        await viewModel.retryLoading()
                    }
                }
            } else if viewModel.isMenuEmpty {
                EmptyMenuView()
            } else {
                MenuCategoriesView(
                    shop: shop,
                    categories: viewModel.menuCategories,
                    onCategoryTap: viewModel.navigateToCategory,
                    onItemTap: viewModel.navigateToMenuItem
                )
            }
        }
    }
    
    /**
     * Back button for navigation
     */
    private var backButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            HStack(spacing: Design.spacing.buttonIcon) {
                Image(systemName: Design.icons.back)
                    .font(Design.fonts.backIcon)
                Text(Design.text.backButton)
                    .font(Design.fonts.backText)
            }
            .foregroundColor(Design.colors.primary)
        }
    }
}

// MARK: - Design System

extension MenuView {
    
    /**
     * Design system constants for MenuView
     */
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let small: CGFloat = 8
            static let medium: CGFloat = 16
            static let large: CGFloat = 24
            static let horizontal: CGFloat = 16
            static let top: CGFloat = 16
            static let bottomPadding: CGFloat = 100
            static let buttonIcon: CGFloat = 4
        }
        
        // MARK: - Colors
        enum colors {
            static let primary = Color.primary
            static let secondary = Color.secondary
            static let background = Color(.systemGray6)
        }
        
        // MARK: - Fonts
        enum fonts {
            static let shopName = Font.largeTitle
            static let shopNameWeight = Font.Weight.bold
            static let menuTitle = Font.title2
            static let backIcon = Font.system(size: 16, weight: .medium)
            static let backText = Font.body
        }
        
        // MARK: - Icons
        enum icons {
            static let back = "chevron.left"
        }
        
        // MARK: - Text
        enum text {
            static let menuTitle = "Menu"
            static let backButton = "Back"
        }
    }
}

struct MenuCategoriesView: View {
    
    // MARK: - Properties
    
    let shop: CoffeeShop
    let categories: [MenuCategory]
    let onCategoryTap: (MenuCategory) -> Void
    let onItemTap: (MenuItem, MenuCategory) -> Void
    
    // MARK: - Body
    
    var body: some View {
        if categories.isEmpty {
            EmptyMenuView()
        } else {
            ForEach(categories) { category in
                MenuCategorySection(
                    category: category,
                    onCategoryTap: { onCategoryTap(category) },
                    onItemTap: { item in onItemTap(item, category) }
                )
            }
        }
    }
}

// MARK: - MenuCategorySection

struct MenuCategorySection: View {
    
    // MARK: - Properties
    
    let category: MenuCategory
    let onCategoryTap: () -> Void
    let onItemTap: (MenuItem) -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(alignment: .leading, spacing: Design.spacing.medium) {
            // Category Header
            Button(action: onCategoryTap) {
                Text(category.name)
                    .font(Design.fonts.categoryTitle)
                    .fontWeight(Design.fonts.categoryTitleWeight)
                    .foregroundColor(Design.colors.primary)
            }
            .padding(.horizontal, Design.spacing.horizontal)
            
            // Menu Items
            VStack(spacing: 0) {
                ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                    MenuItemRow(
                        item: item,
                        onTap: { onItemTap(item) }
                    )
                    
                    if index < category.items.count - 1 {
                        Divider()
                            .padding(.horizontal, Design.spacing.horizontal)
                    }
                }
            }
            .background(Design.colors.cardBackground)
            .cornerRadius(Design.cornerRadius.card)
            .shadow(
                color: Design.shadows.card,
                radius: Design.shadows.cardRadius,
                x: Design.shadows.cardOffset.x,
                y: Design.shadows.cardOffset.y
            )
            .padding(.horizontal, Design.spacing.horizontal)
        }
    }
}

// MARK: - MenuItemRow

struct MenuItemRow: View {
    
    // MARK: - Properties
    
    let item: MenuItem
    let onTap: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: Design.spacing.itemText) {
                    Text(item.name)
                        .font(Design.fonts.itemName)
                        .fontWeight(Design.fonts.itemNameWeight)
                        .foregroundColor(Design.colors.primary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Text("$\(item.price, specifier: "%.2f")")
                    .font(Design.fonts.itemPrice)
                    .fontWeight(Design.fonts.itemPriceWeight)
                    .foregroundColor(Design.colors.primary)
            }
            .padding(.horizontal, Design.spacing.horizontal)
            .padding(.vertical, Design.spacing.itemVertical)
            .background(Design.colors.cardBackground)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Design System for Menu Components

extension MenuCategorySection {
    
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let medium: CGFloat = 16
            static let horizontal: CGFloat = 16
        }
        
        // MARK: - Colors
        enum colors {
            static let primary = Color.primary
            static let cardBackground = Color.white
        }
        
        // MARK: - Fonts
        enum fonts {
            static let categoryTitle = Font.title2
            static let categoryTitleWeight = Font.Weight.semibold
        }
        
        // MARK: - Corner Radius
        enum cornerRadius {
            static let card: CGFloat = 12
        }
        
        // MARK: - Shadows
        enum shadows {
            static let card = Color.black.opacity(0.05)
            static let cardRadius: CGFloat = 8
            static let cardOffset = (x: CGFloat(0), y: CGFloat(2))
        }
    }
}

extension MenuItemRow {
    
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let itemText: CGFloat = 4
            static let horizontal: CGFloat = 16
            static let itemVertical: CGFloat = 12
        }
        
        // MARK: - Colors
        enum colors {
            static let primary = Color.primary
            static let cardBackground = Color.white
        }
        
        // MARK: - Fonts
        enum fonts {
            static let itemName = Font.body
            static let itemNameWeight = Font.Weight.medium
            static let itemPrice = Font.body
            static let itemPriceWeight = Font.Weight.semibold
        }
    }
}

// MARK: - LoadingView

struct LoadingView: View {
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Design.spacing.medium) {
            ProgressView()
                .scaleEffect(Design.progressView.scale)
            
            Text(Design.text.loadingMessage)
                .font(Design.fonts.loadingTitle)
                .foregroundColor(Design.colors.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Design.spacing.topPadding)
    }
}

// MARK: - ErrorView

struct ErrorView: View {
    
    // MARK: - Properties
    
    let errorMessage: String
    let onRetry: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Design.spacing.medium) {
            Image(systemName: Design.icons.error)
                .font(Design.fonts.errorIcon)
                .foregroundColor(Design.colors.errorIcon)
            
            Text(Design.text.errorTitle)
                .font(Design.fonts.errorTitle)
                .fontWeight(Design.fonts.errorTitleWeight)
            
            Text(errorMessage)
                .font(Design.fonts.errorMessage)
                .foregroundColor(Design.colors.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Design.spacing.horizontal)
            
            Button(action: onRetry) {
                Text(Design.text.retryButton)
                    .font(Design.fonts.retryButton)
                    .foregroundColor(Design.colors.retryButtonText)
                    .frame(maxWidth: .infinity)
                    .padding(Design.spacing.buttonPadding)
                    .background(Design.colors.retryButtonBackground)
                    .cornerRadius(Design.cornerRadius.button)
            }
            .padding(.horizontal, Design.spacing.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Design.spacing.topPadding)
    }
}

// MARK: - EmptyMenuView

struct EmptyMenuView: View {
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: Design.spacing.medium) {
            Image(systemName: Design.icons.empty)
                .font(Design.fonts.emptyIcon)
                .foregroundColor(Design.colors.emptyIcon)
            
            Text(Design.text.emptyTitle)
                .font(Design.fonts.emptyTitle)
                .fontWeight(Design.fonts.emptyTitleWeight)
                .foregroundColor(Design.colors.secondary)
            
            Text(Design.text.emptyMessage)
                .font(Design.fonts.emptyMessage)
                .foregroundColor(Design.colors.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, Design.spacing.topPadding)
    }
}

// MARK: - Design System for State Views

extension LoadingView {
    
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let medium: CGFloat = 16
            static let topPadding: CGFloat = 100
        }
        
        // MARK: - Colors
        enum colors {
            static let secondary = Color.secondary
        }
        
        // MARK: - Fonts
        enum fonts {
            static let loadingTitle = Font.headline
        }
        
        // MARK: - Progress View
        enum progressView {
            static let scale: CGFloat = 1.5
        }
        
        // MARK: - Text
        enum text {
            static let loadingMessage = "Loading menu..."
        }
    }
}

extension ErrorView {
    
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let medium: CGFloat = 16
            static let horizontal: CGFloat = 16
            static let topPadding: CGFloat = 100
            static let buttonPadding: CGFloat = 16
        }
        
        // MARK: - Colors
        enum colors {
            static let errorIcon = Color.orange
            static let secondary = Color.secondary
            static let retryButtonText = Color.white
            static let retryButtonBackground = Color.blue
        }
        
        // MARK: - Fonts
        enum fonts {
            static let errorIcon = Font.system(size: 48)
            static let errorTitle = Font.headline
            static let errorTitleWeight = Font.Weight.semibold
            static let errorMessage = Font.subheadline
            static let retryButton = Font.headline
        }
        
        // MARK: - Icons
        enum icons {
            static let error = "exclamationmark.triangle"
        }
        
        // MARK: - Corner Radius
        enum cornerRadius {
            static let button: CGFloat = 12
        }
        
        // MARK: - Text
        enum text {
            static let errorTitle = "Unable to load menu"
            static let retryButton = "Try Again"
        }
    }
}

extension EmptyMenuView {
    
    enum Design {
        
        // MARK: - Spacing
        enum spacing {
            static let medium: CGFloat = 16
            static let topPadding: CGFloat = 100
        }
        
        // MARK: - Colors
        enum colors {
            static let emptyIcon = Color.gray
            static let secondary = Color.secondary
        }
        
        // MARK: - Fonts
        enum fonts {
            static let emptyIcon = Font.system(size: 48)
            static let emptyTitle = Font.headline
            static let emptyTitleWeight = Font.Weight.semibold
            static let emptyMessage = Font.subheadline
        }
        
        // MARK: - Icons
        enum icons {
            static let empty = "cup.and.saucer"
        }
        
        // MARK: - Text
        enum text {
            static let emptyTitle = "No menu items available"
            static let emptyMessage = "Menu items will appear here when available"
        }
    }
}

// MARK: - Previews

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = CoffeeShopDataService.loadCoffeeShops().first!
        MenuView(shop: sampleShop)
    }
} 