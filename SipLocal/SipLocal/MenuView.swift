import SwiftUI

struct MenuView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var menuDataManager = MenuDataManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with shop info
                    VStack(alignment: .leading, spacing: 8) {
                        Text(shop.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Menu")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
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
                        MenuCategoriesView(shop: shop, categories: menuDataManager.getMenuCategories(for: shop))
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
            }
            .task {
                // Load menu data when view appears
                if menuDataManager.getMenuCategories(for: shop).isEmpty {
                    await menuDataManager.fetchMenuData(for: shop)
                }
            }
        }
    }
}

struct MenuCategoriesView: View {
    let shop: CoffeeShop
    let categories: [MenuCategory]
    
    var body: some View {
        if categories.isEmpty {
            EmptyMenuView()
        } else {
            // Menu Categories
            ForEach(categories) { category in
                VStack(alignment: .leading, spacing: 16) {
                    // Category Header
                    Text(category.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .padding(.horizontal)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        ForEach(Array(category.items.enumerated()), id: \.element.id) { index, item in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                                
                                Text("$\(item.price, specifier: "%.2f")")
                                    .font(.body)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            
                            if index < category.items.count - 1 {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
        }
    }
}

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading menu...")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct ErrorView: View {
    let errorMessage: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Unable to load menu")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: onRetry) {
                Text("Try Again")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct EmptyMenuView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            
            Text("No menu items available")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            Text("Menu items will appear here when available")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 100)
    }
}

struct MenuView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleShop = DataService.loadCoffeeShops().first!
        MenuView(shop: sampleShop)
    }
} 