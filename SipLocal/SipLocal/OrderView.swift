import SwiftUI

struct OrderView: View {
    @State private var searchText = ""
    @State private var isSearching = false
    @EnvironmentObject var cartManager: CartManager
    let coffeeShops = DataService.loadCoffeeShops()
    
    var filteredShops: [CoffeeShop] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return coffeeShops
        }
        let lowercased = searchText.lowercased()
        return coffeeShops.filter {
            $0.name.lowercased().contains(lowercased) || $0.address.lowercased().contains(lowercased)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search by name or address", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .onTapGesture { isSearching = true }
                    if isSearching && !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            isSearching = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray5))
                .cornerRadius(12)
                .padding([.horizontal, .top])
                
                Spacer().frame(height: 8)
                
                // Coffee Shop List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredShops) { shop in
                            NavigationLink(destination: MenuCategorySelectionView(shop: shop)) {
                                HStack(spacing: 16) {
                                    Image(shop.imageName)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text(shop.name)
                                                .font(.headline)
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            // Business Hours Status
                                            if let isLoading = cartManager.isLoadingBusinessHours[shop.id], isLoading {
                                                ProgressView()
                                                    .scaleEffect(0.6)
                                            } else if let isOpen = cartManager.isShopOpen(shop: shop) {
                                                HStack(spacing: 4) {
                                                    Text(isOpen ? "Open" : "Closed")
                                                        .font(.caption2)
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(.white)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(
                                                            Capsule()
                                                                .fill(isOpen ? Color.green : Color.red)
                                                        )
                                                }
                                            }
                                        }
                                        
                                        Text(shop.address)
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding(12)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .onAppear {
                                // Fetch business hours when card appears
                                Task {
                                    await cartManager.fetchBusinessHours(for: shop)
                                }
                            }
                        }
                        if filteredShops.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("No coffee shops found")
                                    .font(.body)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 40)
                        }
                    }
                    .padding([.horizontal, .bottom])
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Order")
        }
    }
}

struct OrderView_Previews: PreviewProvider {
    static var previews: some View {
        OrderView()
            .environmentObject(CartManager())
    }
} 