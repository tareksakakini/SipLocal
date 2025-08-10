import SwiftUI

struct MenuItemsView: View {
    let shop: CoffeeShop
    let category: MenuCategory
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var menuDataManager = MenuDataManager.shared
    @State private var showingCart = false
    @State private var customizingItem: MenuItem? = nil
    @State private var initialSelectedSizeId: String? = nil
    @State private var showingDifferentShopAlert = false
    @State private var showingClosedShopAlert = false
    @State private var pendingItem: (item: MenuItem, customizations: String?, price: Double)?
    // Store customization selections - maps modifier list ID to selected modifier IDs
    @State private var selectedModifiers: [String: Set<String>] = [:]
    @State private var showItemAddedPopup = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with category info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shop.name)
                            .font(.title)
                            .fontWeight(.semibold)
                        
                        HStack {
                            Image(systemName: categoryIcon(for: category.name))
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
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Menu Items Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(category.items) { item in
                            MenuItemCard(
                                item: item,
                                shop: shop,
                                category: category.name,
                                cartManager: cartManager,
                                onAdd: {
                                    // Check if shop is closed
                                    if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                                        showingClosedShopAlert = true
                                        return
                                    }
                                    
                                    // If the item has no modifier lists and no size variations, add directly to cart
                                    let hasCustomizations = (item.modifierLists != nil && !(item.modifierLists?.isEmpty ?? true)) || (item.variations != nil && item.variations!.count > 1)
                                    if !hasCustomizations {
                                        let success = cartManager.addItem(shop: shop, menuItem: item, category: category.name)
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
                                        // Initialize selections with defaults
                                        initializeModifierSelections(for: item)
                                    }
                                }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
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
                    initialSelectedSizeId: initialSelectedSizeId,
                    onAdd: { totalPriceWithModifiers, customizationDesc, selectedSizeIdOut, selectedModsOut in
                        // Check if shop is closed
                        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
                            showingClosedShopAlert = true
                            customizingItem = nil
                            return
                        }
                        
                        // Add to cart with customizations and pricing from the customization sheet
                        let success = cartManager.addItem(
                            shop: shop,
                            menuItem: item,
                            category: category.name,
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
                            // Store the pending item and show alert
                            pendingItem = (item: item, customizations: customizationDesc, price: totalPriceWithModifiers)
                            showingDifferentShopAlert = true
                            customizingItem = nil
                        }
                    },
                    onCancel: {
                        customizingItem = nil
                    }
                )
                .onDisappear {
                    initialSelectedSizeId = nil
                }
            }
            .alert("Different Coffee Shop", isPresented: $showingDifferentShopAlert) {
                Button("Clear Cart & Add Item", role: .destructive) {
                    cartManager.clearCart()
                    if let pending = pendingItem {
                        let _ = cartManager.addItem(shop: shop, menuItem: pending.item, category: category.name, customizations: pending.customizations, itemPriceWithModifiers: pending.price)
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
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToExploreTab"))) { _ in
                showingCart = false
            }
            .onAppear {
                // Fetch business hours when view appears
                Task {
                    await cartManager.fetchBusinessHours(for: shop)
                }
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
    
    // Initialize modifier selections with default values
    private func initializeModifierSelections(for item: MenuItem) {
        selectedModifiers.removeAll()
        
        // Size variations are now handled separately, no need to add to selectedModifiers
        
        guard let modifierLists = item.modifierLists else { return }
        
        for modifierList in modifierLists {
            initializeDefaultsForModifierList(modifierList)
        }
    }
    
    // Helper to initialize defaults for a modifier list
    private func initializeDefaultsForModifierList(_ modifierList: MenuItemModifierList) {
        var defaultSelections: Set<String> = []
        
        // Find default modifiers
        for modifier in modifierList.modifiers {
            if modifier.isDefault {
                defaultSelections.insert(modifier.id)
            }
        }
        
        // If no defaults found, select first modifier as fallback
        // For single-selection lists, always select first if no defaults
        // For multiple-selection lists, only select first if minimum selections required
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
    
    // Helper to create a modifier list from size variations
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
    
    // Helper to build customization description (always show size, only non-default for others)
    private func customizationDescription(for item: MenuItem) -> String {
        var desc: [String] = []
        
        // Add size variation description - we need to access the selectedSizeId from the customization sheet
        // For now, we'll handle this differently and pass the size info when adding to cart
        
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

struct MenuItemCard: View {
    let item: MenuItem
    let shop: CoffeeShop
    let category: String
    let cartManager: CartManager
    var onAdd: (() -> Void)? = nil
    
    private func formatPrice(for item: MenuItem) -> String {
        // Always show the smallest size price (starting price)
        if let variations = item.variations, variations.count > 1 {
            let minPrice = variations.map(\.price).min() ?? item.price
            return String(format: "$%.2f", minPrice)
        } else {
            // Single size or no variations - show base price
            return String(format: "$%.2f", item.price)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 115, height: 105)
                            .clipped()
                    case .failure(_):
                        // Show fallback placeholder
                        VStack {
                            Image(systemName: "photo.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 40, height: 40)
                                .foregroundColor(.gray)
                            Text("Image Not Available")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        .frame(width: 115, height: 105)
                        .background(Color(.systemGray5))
                    case .empty:
                        // Show loading state
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 115, height: 105)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                // Show fallback placeholder
                VStack {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                        .foregroundColor(.gray)
                    Text("Image Not Available")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(width: 115, height: 105)
                .background(Color(.systemGray5))
            }
            
            // Content Section
            VStack(spacing: 6) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundColor(.primary)
                    .frame(height: 35) // Fixed height to prevent layout shifts
                
                Text(formatPrice(for: item))
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.black)
                
                Button(action: {
                    onAdd?()
                }) {
                    Text("Add")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding(8)
        }
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    }
}

// Extension to add corner radius to specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// Size Selection Component - shows full prices prominently
struct SizeSelectionView: View {
    let variations: [MenuItemVariation]
    @Binding var selectedSizeId: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Size")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(variations) { variation in
                    SizeOptionCard(
                        variation: variation,
                        isSelected: selectedSizeId == variation.id,
                        onTap: {
                            selectedSizeId = variation.id
                        }
                    )
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// Individual size option card
struct SizeOptionCard: View {
    let variation: MenuItemVariation
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 6) {
                Text(variation.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Text(String(format: "$%.2f", variation.price))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.accentColor : Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Customization Sheet
struct DrinkCustomizationSheet: View {
    let item: MenuItem
    @Binding var selectedModifiers: [String: Set<String>]
    var initialSelectedSizeId: String? = nil
    var onAdd: (Double, String, String?, [String: [String]]?) -> Void
    var onCancel: () -> Void
    
    @State private var selectedSizeId: String?
    
    // Helper to create a modifier list from size variations
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
    
    var totalPrice: Double {
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
    
    // Build complete customization description including size
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Show size variations with special UI
                        if let variations = item.variations, variations.count > 1 {
                            SizeSelectionView(
                                variations: variations,
                                selectedSizeId: $selectedSizeId
                            )
                        }
                        
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
                        } else if item.variations == nil || item.variations!.count <= 1 {
                            // Show message if no modifiers or variations available
                            Text("No customization options available")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding()
                        }
                    }
                    .padding()
                }
                
                // --- Add to Cart Footer ---
                VStack(spacing: 12) {
                    Divider()
                    HStack {
                        Text("Price")
                            .font(.headline)
                        Spacer()
                        Text("$\(totalPrice, specifier: "%.2f")")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    .padding(.horizontal)
                    
                    Button(action: {
                        // Convert selection binding to plain [String: [String]] for persistence
                        var modsOut: [String: [String]] = [:]
                        for (listId, setIds) in selectedModifiers {
                            modsOut[listId] = Array(setIds)
                        }
                        onAdd(totalPrice, buildCustomizationDescription(), selectedSizeId, modsOut.isEmpty ? nil : modsOut)
                    }) {
                        Text("Add to Cart")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
                .background(Color(.systemGray6))
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
            // Initialize selected size to provided initial or first variation if not already set
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
    }
}

// Modifier List Section View
struct ModifierListSection: View {
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text(modifierList.name)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                // Show selection requirements
                if modifierList.minSelections > 0 || modifierList.maxSelections != 1 {
                    let requirementText = buildRequirementText()
                    if !requirementText.isEmpty {
                        Text(requirementText)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if modifierList.selectionType == "SINGLE" || modifierList.maxSelections == 1 {
                // Single selection - choose UI based on number of options
                if modifierList.modifiers.count <= 3 {
                    // Segmented picker for 3 or fewer options
                    SegmentedModifierPicker(
                        modifierList: modifierList,
                        selectedModifiers: $selectedModifiers
                    )
                } else {
                    // Default picker for more than 3 options
                    DefaultModifierPicker(
                        modifierList: modifierList,
                        selectedModifiers: $selectedModifiers
                    )
                }
            } else {
                // Multiple selection (checkboxes)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(modifierList.modifiers) { modifier in
                        MultipleSelectionRow(
                            modifier: modifier,
                            isSelected: selectedModifiers.contains(modifier.id),
                            onToggle: {
                                if selectedModifiers.contains(modifier.id) {
                                    // Don't allow deselection if at minimum
                                    if selectedModifiers.count > modifierList.minSelections {
                                        selectedModifiers.remove(modifier.id)
                                    }
                                } else {
                                    // Don't allow selection if at maximum (handle -1 as unlimited)
                                    if modifierList.maxSelections == -1 || selectedModifiers.count < modifierList.maxSelections {
                                        selectedModifiers.insert(modifier.id)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
    
    private func buildRequirementText() -> String {
        if modifierList.minSelections > 0 && modifierList.maxSelections > 1 {
            if modifierList.maxSelections == -1 {
                return "Select at least \(modifierList.minSelections)"
            } else if modifierList.minSelections == modifierList.maxSelections {
                return "Select \(modifierList.minSelections)"
            } else {
                return "Select \(modifierList.minSelections)-\(modifierList.maxSelections)"
            }
        } else if modifierList.minSelections > 0 {
            return "Select at least \(modifierList.minSelections)"
        } else if modifierList.maxSelections > 1 {
            return "Select up to \(modifierList.maxSelections)"
        }
        return ""
    }
}

// Multiple Selection Row (Checkbox Style)
struct MultipleSelectionRow: View {
    let modifier: MenuItemModifier
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.system(size: 20))
                
                Text(modifier.name)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if modifier.price > 0 {
                    Text("+$\(modifier.price, specifier: "%.2f")")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Segmented Modifier Picker (for 3 or fewer options)
struct SegmentedModifierPicker: View {
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    var selectedModifierId: String {
        selectedModifiers.first ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(modifierList.name, selection: Binding(
                get: { selectedModifierId },
                set: { newValue in
                    selectedModifiers.removeAll()
                    if !newValue.isEmpty {
                        selectedModifiers.insert(newValue)
                    }
                }
            )) {
                ForEach(modifierList.modifiers) { modifier in
                    Text(modifier.name)
                        .tag(modifier.id)
                }
            }
            .pickerStyle(.segmented)
            
            // Show pricing info below segmented control
            if let selectedId = selectedModifiers.first,
               let selectedModifier = modifierList.modifiers.first(where: { $0.id == selectedId }) {
                HStack {
                    Spacer()
                    if selectedModifier.price > 0 {
                        Text("+$\(selectedModifier.price, specifier: "%.2f")")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No extra charge")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

// Default Modifier Picker (for more than 3 options)
struct DefaultModifierPicker: View {
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    var selectedModifierId: String {
        selectedModifiers.first ?? ""
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Picker(modifierList.name, selection: Binding(
                get: { selectedModifierId },
                set: { newValue in
                    selectedModifiers.removeAll()
                    if !newValue.isEmpty {
                        selectedModifiers.insert(newValue)
                    }
                }
            )) {
                ForEach(modifierList.modifiers) { modifier in
                    HStack {
                        Text(modifier.name)
                        Spacer()
                        if modifier.price > 0 {
                            Text("+$\(modifier.price, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }
                    }
                    .tag(modifier.id)
                }
            }
            .pickerStyle(.wheel)
            .padding(.vertical, 4) // Adjust padding to reduce margin
            .frame(height: 100)
        }
    }
}

struct MenuItemsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        
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
