import SwiftUI
import struct SipLocal.MenuItemCard

struct MenuCategorySelectionView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @EnvironmentObject var orderManager: OrderManager
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

                    // Order Again section
                    OrderAgainSection(shop: shop)

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
                    initialSelectedSizeId: nil,
                    onAdd: { totalPriceWithModifiers, customizationDesc, selectedSizeIdOut, selectedModsOut in
                        // Check if shop is closed
                        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                            showingClosedShopAlert = true
                            customizingItem = nil
                            return
                        }
                        
                        let success = cartManager.addItem(
                            shop: shop,
                            menuItem: item,
                            category: "",
                            customizations: customizationDesc,
                            itemPriceWithModifiers: totalPriceWithModifiers,
                            selectedSizeId: selectedSizeIdOut,
                            selectedModifierIdsByList: selectedModsOut
                        )
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
                // Prime menu for instant cached load + background refresh
                await menuDataManager.primeMenu(for: shop)
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

// MARK: - Order Again Section
struct OrderAgainSection: View {
    let shop: CoffeeShop
    @EnvironmentObject var orderManager: OrderManager
    @EnvironmentObject var cartManager: CartManager
    @State private var customizingItem: MenuItem? = nil
    @State private var selectedModifiers: [String: Set<String>] = [:]
    @State private var initialSelectedSizeId: String? = nil
    @State private var showingClosedShopAlert = false

    private struct RepeatKey: Hashable {
        let menuItemId: String
        let selectedSizeId: String?
        let selectedModifierIdsByList: [String: [String]]?
        let customizations: String?
        let name: String

        func hash(into hasher: inout Hasher) {
            hasher.combine(menuItemId)
            hasher.combine(selectedSizeId)
            // Normalize modifier lists for stable hashing
            if let lists = selectedModifierIdsByList {
                for key in lists.keys.sorted() {
                    hasher.combine(key)
                    for v in (lists[key] ?? []).sorted() {
                        hasher.combine(v)
                    }
                }
            } else {
                hasher.combine(0)
            }
            hasher.combine(customizations ?? "")
        }
    }

    // Build frequency map for this shop only
    private var frequentItems: [(key: RepeatKey, count: Int, sample: CartItem)] {
        var counts: [RepeatKey: (count: Int, sample: CartItem)] = [:]
        for order in orderManager.orders where order.coffeeShop.id == shop.id && [.completed, .cancelled].contains(order.status) {
            for item in order.items {
                let key = RepeatKey(
                    menuItemId: item.menuItemId,
                    selectedSizeId: item.selectedSizeId,
                    selectedModifierIdsByList: item.selectedModifierIdsByList,
                    customizations: item.customizations,
                    name: item.menuItem.name
                )
                let current = counts[key]
                counts[key] = ( (current?.count ?? 0) + item.quantity, current?.sample ?? item )
            }
        }
        return counts.map { ($0.key, $0.value.count, $0.value.sample) }
            .sorted { lhs, rhs in lhs.count > rhs.count }
    }

    // Find current menu item by stored id
    private func findMenuItem(by id: String, in categories: [MenuCategory]) -> MenuItem? {
        for category in categories {
            if let match = category.items.first(where: { $0.id == id }) { return match }
        }
        return nil
    }

    var body: some View {
        let categories = MenuDataManager.shared.getMenuCategories(for: shop)
        let items = frequentItems

        if items.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 12) {
                Text("Order Again")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items, id: \.key) { entry in
                            if let liveItem = findMenuItem(by: entry.key.menuItemId, in: categories) {
                                OrderAgainCard(
                                    displayName: liveItem.name,
                                    subtitle: entry.key.customizations ?? "",
                                    count: entry.count,
                                    imageURL: liveItem.imageURL,
                                    price: liveItem.price,
                                    onTap: {
                                        // If item has customizations, open sheet preloaded; else add directly
                                        let hasCustomizations = (liveItem.modifierLists != nil && !(liveItem.modifierLists?.isEmpty ?? true)) || (liveItem.variations != nil && liveItem.variations!.count > 1)
                                        if !hasCustomizations {
                                            let _ = cartManager.addItem(shop: shop, menuItem: liveItem, category: "Order Again")
                                        } else {
                                            customizingItem = liveItem
                                            // Preload size and modifiers
                                            initialSelectedSizeId = entry.key.selectedSizeId
                                            selectedModifiers.removeAll()
                                            if let map = entry.key.selectedModifierIdsByList {
                                                for (listId, ids) in map {
                                                    selectedModifiers[listId] = Set(ids)
                                                }
                                            }
                                        }
                                    }
                                )
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
        )
        .sheet(item: $customizingItem) { item in
            DrinkCustomizationSheet(
                item: item,
                selectedModifiers: $selectedModifiers,
                initialSelectedSizeId: initialSelectedSizeId,
                onAdd: { total, desc, selectedSizeIdOut, selectedModsOut in
                    if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                        showingClosedShopAlert = true
                        customizingItem = nil
                        return
                    }
                    let _ = cartManager.addItem(
                        shop: shop,
                        menuItem: item,
                        category: "Order Again",
                        customizations: desc,
                        itemPriceWithModifiers: total,
                        selectedSizeId: selectedSizeIdOut,
                        selectedModifierIdsByList: selectedModsOut
                    )
                    customizingItem = nil
                },
                onCancel: { customizingItem = nil }
            )
        }
        .alert("Shop is Closed", isPresented: $showingClosedShopAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This coffee shop is currently closed. Please try again during business hours.")
        }
    }
}

private struct OrderAgainCard: View {
    let displayName: String
    let subtitle: String
    let count: Int
    let imageURL: String?
    let price: Double
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Thumbnail
                if let imageURL, let url = URL(string: imageURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill().frame(width: 56, height: 56).clipped().cornerRadius(8)
                        default:
                            RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(width: 56, height: 56).overlay(Image(systemName: "photo").foregroundColor(.gray))
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)).frame(width: 56, height: 56).overlay(Image(systemName: "cup.and.saucer").foregroundColor(.gray))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(displayName).font(.subheadline).fontWeight(.semibold).foregroundColor(.primary).lineLimit(1)
                        Spacer()
                        Text("×\(count)").font(.caption).foregroundColor(.secondary)
                    }
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    Text(String(format: "$%.2f", price)).font(.caption).fontWeight(.medium).foregroundColor(.primary)
                }
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
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