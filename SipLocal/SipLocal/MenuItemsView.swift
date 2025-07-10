import SwiftUI

struct MenuItemsView: View {
    let shop: CoffeeShop
    let category: MenuCategory
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @State private var showingCart = false
    
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
                                cartManager: cartManager
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

struct MenuItemCard: View {
    let item: MenuItem
    let shop: CoffeeShop
    let category: String
    let cartManager: CartManager
    
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
                    cartManager.addItem(shop: shop, menuItem: item, category: category)
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

struct MenuItemsView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        let sampleCategory = sampleShop.menu.first!
        MenuItemsView(shop: sampleShop, category: sampleCategory)
            .environmentObject(CartManager())
    }
} 