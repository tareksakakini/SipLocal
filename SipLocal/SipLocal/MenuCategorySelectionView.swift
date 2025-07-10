import SwiftUI

struct MenuCategorySelectionView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var cartManager: CartManager
    @State private var showingCart = false
    
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
                    
                    // Category Cards
                    VStack(spacing: 16) {
                        ForEach(shop.menu) { category in
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

struct MenuCategorySelectionView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        MenuCategorySelectionView(shop: sampleShop)
    }
} 