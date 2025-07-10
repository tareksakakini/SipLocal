import SwiftUI

struct MenuItemsView: View {
    let shop: CoffeeShop
    let category: MenuCategory
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @State private var showingCart = false
    @State private var customizingItem: MenuItem? = nil
    // Store customization selections
    @State private var selectedIce: String = "Regular"
    @State private var selectedMilk: String = "Whole"
    @State private var selectedSugar: String = "Regular"
    @State private var selectedSize: String = "Medium"
    
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
                                    // Reset selections
                                    selectedIce = "Regular"
                                    selectedMilk = "Whole"
                                    selectedSugar = "Regular"
                                    selectedSize = "Medium"
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
                    customizations: item.customizations ?? [],
                    selectedIce: $selectedIce,
                    selectedMilk: $selectedMilk,
                    selectedSugar: $selectedSugar,
                    selectedSize: $selectedSize,
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
    
    // Helper to build customization description
    private func customizationDescription(for item: MenuItem) -> String {
        var desc: [String] = []
        if item.customizations?.contains("ice") == true { desc.append("Ice: \(selectedIce)") }
        if item.customizations?.contains("milk") == true { desc.append("Milk: \(selectedMilk)") }
        if item.customizations?.contains("sugar") == true { desc.append("Sugar: \(selectedSugar)") }
        if item.customizations?.contains("size") == true { desc.append("Size: \(selectedSize)") }
        return desc.joined(separator: ", ")
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
            Image("sample_menu_pic")
                .resizable()
                .aspectRatio(1, contentMode: .fill)
                .frame(height: 100)
                .clipped()
                .cornerRadius(12, corners: [.topLeft, .topRight])
            
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
    let customizations: [String]
    @Binding var selectedIce: String
    @Binding var selectedMilk: String
    @Binding var selectedSugar: String
    @Binding var selectedSize: String
    var onAdd: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if customizations.contains("size") {
                            CustomizationSection(title: "Size") {
                                Picker("Size", selection: $selectedSize) {
                                    ForEach(["Small", "Medium", "Large"], id: \.self) { Text($0) }
                                }.pickerStyle(.segmented)
                            }
                        }
                        
                        if customizations.contains("ice") {
                            CustomizationSection(title: "Ice") {
                                Picker("Ice", selection: $selectedIce) {
                                    ForEach(["None", "Light", "Regular", "Extra"], id: \.self) { Text($0) }
                                }.pickerStyle(.segmented)
                            }
                        }
                        
                        if customizations.contains("milk") {
                            CustomizationSection(title: "Milk Options") {
                                Picker("Milk", selection: $selectedMilk) {
                                    ForEach(["None", "Whole", "Skim", "Oat", "Almond", "Soy"], id: \.self) { Text($0) }
                                }
                                .pickerStyle(.wheel)
                                .frame(height: 100)
                            }
                        }
                        
                        if customizations.contains("sugar") {
                            CustomizationSection(title: "Sugar") {
                                Picker("Sugar", selection: $selectedSugar) {
                                    ForEach(["No Sugar", "Regular"], id: \.self) { Text($0) }
                                }.pickerStyle(.segmented)
                            }
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
                        Text("$\(item.price, specifier: "%.2f")")
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

// Reusable Section View for Customizations
struct CustomizationSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
            
            content
        }
        .padding()
        .background(Color.white)
        .cornerRadius(12)
    }
}

struct MenuItemsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        let sampleCategory = sampleShop.menu.first!
        MenuItemsView(shop: sampleShop, category: sampleCategory)
            .environmentObject(CartManager())
    }
} 