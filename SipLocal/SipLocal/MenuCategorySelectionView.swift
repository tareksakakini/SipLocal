import SwiftUI
import struct SipLocal.MenuItemCard

struct MenuCategorySelectionView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var menuDataManager = MenuDataManager.shared
    @State private var showingCart = false
    @State private var searchText: String = ""
    @State private var showItemAddedPopup = false
    @State private var customizingItem: MenuItem? = nil
    @State private var selectedModifiers: [String: Set<String>] = [:]
    @State private var showingDifferentShopAlert = false
    @State private var showingClosedShopAlert = false
    @State private var pendingItem: (item: MenuItem, customizations: String?, price: Double)?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with shop info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shop.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Choose a drink category")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)

                    // --- Search Bar ---
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.gray)
                        TextField("Search menu items...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                    }
                    .padding(12)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // --- Search Results ---
                    if !searchText.isEmpty {
                        let allItems = menuDataManager.getMenuCategories(for: shop).flatMap { $0.items }
                        let filtered = allItems.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                        let topResults = Array(filtered.prefix(3))
                        if !topResults.isEmpty {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(topResults, id: \.id) { item in
                                    MenuItemCard(
                                        item: item,
                                        shop: shop,
                                        category: "",
                                        cartManager: cartManager,
                                        onAdd: {
                                            // Check if shop is closed
                                            if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                                                showingClosedShopAlert = true
                                                return
                                            }
                                            
                                            let hasCustomizations = (item.modifierLists != nil && !(item.modifierLists?.isEmpty ?? true)) || (item.variations != nil && item.variations!.count > 1)
                                            if !hasCustomizations {
                                                let success = cartManager.addItem(shop: shop, menuItem: item, category: "")
                                                if success {
                                                    showItemAddedPopup = true
                                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                                        withAnimation {
                                                            showItemAddedPopup = false
                                                        }
                                                    }
                                                } else {
                                                    pendingItem = (item: item, customizations: nil, price: item.price)
                                                    showingDifferentShopAlert = true
                                                }
                                            } else {
                                                customizingItem = item
                                                selectedModifiers.removeAll()
                                            }
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        } else {
                            Text("No results found.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                    }
                    // --- End Search Results ---

                    // Content based on loading state
                    if menuDataManager.isLoading(for: shop) {
                        LoadingView()
                    } else if let errorMessage = menuDataManager.getErrorMessage(for: shop) {
                        ErrorView(errorMessage: errorMessage) {
                            Task {
                                await menuDataManager.refreshMenuData(for: shop)
                            }
                        }
                    } else {
                        CategoryCardsView(shop: shop, categories: menuDataManager.getMenuCategories(for: shop))
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(Color(.systemGray6))
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingCart = true
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
            }
            .sheet(isPresented: $showingCart) {
                CartView()
                    .environmentObject(cartManager)
            }
            .sheet(item: $customizingItem) { item in
                DrinkCustomizationSheet(
                    item: item,
                    selectedModifiers: $selectedModifiers,
                    onAdd: { totalPriceWithModifiers, customizationDesc in
                        // Check if shop is closed
                        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                            showingClosedShopAlert = true
                            customizingItem = nil
                            return
                        }
                        
                        let success = cartManager.addItem(shop: shop, menuItem: item, category: "", customizations: customizationDesc, itemPriceWithModifiers: totalPriceWithModifiers)
                        if success {
                            customizingItem = nil
                            showItemAddedPopup = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation {
                                    showItemAddedPopup = false
                                }
                            }
                        } else {
                            pendingItem = (item: item, customizations: customizationDesc, price: totalPriceWithModifiers)
                            showingDifferentShopAlert = true
                            customizingItem = nil
                        }
                    },
                    onCancel: {
                        customizingItem = nil
                    }
                )
            }
            .alert("Different Coffee Shop", isPresented: $showingDifferentShopAlert) {
                Button("Clear Cart & Add Item", role: .destructive) {
                    cartManager.clearCart()
                    if let pending = pendingItem {
                        let _ = cartManager.addItem(shop: shop, menuItem: pending.item, category: "", customizations: pending.customizations, itemPriceWithModifiers: pending.price)
                        showItemAddedPopup = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            withAnimation {
                                showItemAddedPopup = false
                            }
                        }
                    }
                    pendingItem = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingItem = nil
                }
            } message: {
                Text("Your cart contains items from a different coffee shop. To add this item, you need to clear your current cart first.")
            }
            .alert("Shop is Closed", isPresented: $showingClosedShopAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("This coffee shop is currently closed. Please try again during business hours.")
            }
            .overlay(
                Group {
                    if showItemAddedPopup {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text("Item added")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.85))
                                    .cornerRadius(16)
                                    .shadow(radius: 8)
                                Spacer()
                            }
                            .padding(.bottom, 40)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeInOut(duration: 0.3), value: showItemAddedPopup)
                    }
                }
            )
            .task {
                // Load menu data when view appears
                if menuDataManager.getMenuCategories(for: shop).isEmpty {
                    await menuDataManager.fetchMenuData(for: shop)
                }
            }
            .onAppear {
                // Fetch business hours when view appears
                Task {
                    await cartManager.fetchBusinessHours(for: shop)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExploreTab"))) { _ in
                showingCart = false
            }
        }
    }
}

struct CategoryCardsView: View {
    let shop: CoffeeShop
    let categories: [MenuCategory]
    
    var body: some View {
        if categories.isEmpty {
            EmptyMenuView()
        } else {
            // Category Cards
            VStack(spacing: 16) {
                ForEach(categories) { category in
                    NavigationLink(destination: MenuItemsView(shop: shop, category: category)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: categoryIcon(for: category.name))
                                        .font(.title2)
                                        .foregroundColor(.primary)
                                    
                                    Text(category.name)
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                Text("\(category.items.count) items")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                // Show first few item names as preview
                                Text(category.items.prefix(3).map { $0.name }.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.title3)
                                .foregroundColor(.secondary)
                        }
                        .padding(20)
                        .background(Color.white)
                        .cornerRadius(16)
                        .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal)
        }
    }
    
    private func categoryIcon(for categoryName: String) -> String {
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
}

struct MenuCategorySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        MenuCategorySelectionView(shop: sampleShop)
    }
} 