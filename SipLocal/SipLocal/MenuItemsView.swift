import SwiftUI

struct MenuItemsView: View {
    let shop: CoffeeShop
    let category: MenuCategory
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @StateObject private var menuDataManager = MenuDataManager.shared
    @State private var showingCart = false
    @State private var customizingItem: MenuItem? = nil
    // Store customization selections - maps modifier list ID to selected modifier IDs
    @State private var selectedModifiers: [String: Set<String>] = [:]
    
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
                                    customizingItem = item
                                    // Initialize selections with defaults
                                    initializeModifierSelections(for: item)
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
                    onAdd: {
                        // Add to cart with customizations as a string description
                        let customizationDesc = customizationDescription(for: item)
                        cartManager.addItem(shop: shop, menuItem: item, category: category.name, customizations: customizationDesc)
                        customizingItem = nil
                    },
                    onCancel: {
                        customizingItem = nil
                    }
                )
            }
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
        
        guard let modifierLists = item.modifierLists else { return }
        
        for modifierList in modifierLists {
            var defaultSelections: Set<String> = []
            
            // Find default modifiers
            for modifier in modifierList.modifiers {
                if modifier.isDefault {
                    defaultSelections.insert(modifier.id)
                }
            }
            
            // If no defaults and minimum selection required, select first modifier
            if defaultSelections.isEmpty && modifierList.minSelections > 0 {
                if let firstModifier = modifierList.modifiers.first {
                    defaultSelections.insert(firstModifier.id)
                }
            }
            
            selectedModifiers[modifierList.id] = defaultSelections
        }
    }
    
    // Helper to build customization description
    private func customizationDescription(for item: MenuItem) -> String {
        guard let modifierLists = item.modifierLists else { return "" }
        
        var desc: [String] = []
        
        for modifierList in modifierLists {
            if let selectedModifierIds = selectedModifiers[modifierList.id], !selectedModifierIds.isEmpty {
                let selectedModifierNames = modifierList.modifiers.compactMap { modifier in
                    selectedModifierIds.contains(modifier.id) ? modifier.name : nil
                }
                
                if !selectedModifierNames.isEmpty {
                    desc.append("\(modifierList.name): \(selectedModifierNames.joined(separator: ", "))")
                }
            }
        }
        
        return desc.joined(separator: " | ")
    }
}

struct MenuItemCard: View {
    let item: MenuItem
    let shop: CoffeeShop
    let category: String
    let cartManager: CartManager
    var onAdd: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Image Section
            if let imageURL = item.imageURL, let url = URL(string: imageURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(12, corners: [.topLeft, .topRight])
                    case .failure(_):
                        // Show fallback image on error
                        Image("sample_menu_pic")
                            .resizable()
                            .aspectRatio(1, contentMode: .fill)
                            .frame(height: 100)
                            .clipped()
                            .cornerRadius(12, corners: [.topLeft, .topRight])
                    case .empty:
                        // Show loading state
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 100)
                            .cornerRadius(12, corners: [.topLeft, .topRight])
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
                Image("sample_menu_pic")
                    .resizable()
                    .aspectRatio(1, contentMode: .fill)
                    .frame(height: 100)
                    .clipped()
                    .cornerRadius(12, corners: [.topLeft, .topRight])
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
                
                Text("$\(item.price, specifier: "%.2f")")
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

// Customization Sheet
struct DrinkCustomizationSheet: View {
    let item: MenuItem
    @Binding var selectedModifiers: [String: Set<String>]
    var onAdd: () -> Void
    var onCancel: () -> Void
    
    var totalPrice: Double {
        var total = item.price
        
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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
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
                        } else {
                            // Show message if no modifiers available
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
                    
                    Button(action: onAdd) {
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
    }
}

// Modifier List Section View
struct ModifierListSection: View {
    let modifierList: MenuItemModifierList
    @Binding var selectedModifiers: Set<String>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                // Single selection (radio buttons)
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(modifierList.modifiers) { modifier in
                        SingleSelectionRow(
                            modifier: modifier,
                            isSelected: selectedModifiers.contains(modifier.id),
                            onSelect: {
                                selectedModifiers.removeAll()
                                selectedModifiers.insert(modifier.id)
                            }
                        )
                    }
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
                                    // Don't allow selection if at maximum
                                    if selectedModifiers.count < modifierList.maxSelections {
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
            if modifierList.minSelections == modifierList.maxSelections {
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

// Single Selection Row (Radio Button Style)
struct SingleSelectionRow: View {
    let modifier: MenuItemModifier
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
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

struct MenuItemsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        // Create a sample category since we can't access shop.menu directly anymore
        let sampleCategory = MenuCategory(name: "Hot Coffee", items: [
            MenuItem(name: "Americano", price: 3.50, customizations: ["size", "milk", "sugar"], imageURL: nil, modifierLists: nil),
            MenuItem(name: "Latte", price: 4.25, customizations: ["size", "milk", "sugar"], imageURL: nil, modifierLists: nil)
        ])
        MenuItemsView(shop: sampleShop, category: sampleCategory)
            .environmentObject(CartManager())
    }
} 