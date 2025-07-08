import SwiftUI
import MapKit

struct ExploreView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var coffeeShops: [CoffeeShop] = DataService.loadCoffeeShops()
    @State private var searchText: String = ""
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @State private var selectedShop: CoffeeShop?
    
    var searchResults: [CoffeeShop] {
        if searchText.isEmpty {
            return []
        } else {
            return coffeeShops.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }.prefix(3).map { $0 }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // Background tap detection
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            selectedShop = nil
                        }
                    }
                
                Map(coordinateRegion: $region, annotationItems: coffeeShops) { shop in
                    MapAnnotation(coordinate: shop.coordinate) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedShop = shop
                            }
                        }) {
                            VStack(spacing: 2) {
                                ZStack {
                                    Circle()
                                        .fill(Color.orange)
                                        .frame(width: 32, height: 32)
                                    
                                    Image(systemName: "cup.and.saucer.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .scaleEffect(selectedShop?.id == shop.id ? 1.3 : 1.0)
                                
                                Text(shop.name)
                                    .font(.caption2)
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.9))
                                    .cornerRadius(4)
                                    .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
                                    .scaleEffect(selectedShop?.id == shop.id ? 1.1 : 1.0)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .edgesIgnoringSafeArea(.top)

                VStack(spacing: 0) {
                    // Search bar at the top
                    HStack {
                        Image(systemName: "magnifyingglass")
                        TextField("Search for a coffee shop", text: $searchText)
                        if !searchText.isEmpty {
                            Button(action: {
                                self.searchText = ""
                            }) {
                                Image(systemName: "xmark.circle.fill")
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .padding(.horizontal)
                    .padding(.top)
                    
                    if !searchResults.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Suggestions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)

                            ForEach(searchResults) { shop in
                                Button(action: {
                                    selectShop(shop)
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "cup.and.saucer.fill")
                                            .foregroundColor(.orange)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(shop.name)
                                                .foregroundColor(.primary)
                                                .fontWeight(.medium)
                                            Text(shop.address)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(12)
                                }
                                if shop.id != searchResults.last?.id {
                                    Divider().padding(.leading, 46)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        .padding(.top, 4)
                    }
                    
                    Spacer()
                    
                    // Detail card at the bottom
                    if let shop = selectedShop {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(shop.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Spacer()
                                Button(action: {
                                    withAnimation {
                                        self.selectedShop = nil
                                    }
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Text(shop.address)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            Text(shop.phone)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            
                            NavigationLink(destination: CoffeeShopDetailView(shop: shop, authManager: authManager)) {
                                HStack {
                                    Text("View More")
                                        .fontWeight(.semibold)
                                    Spacer()
                                    Image(systemName: "arrow.right")
                                }
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.blue)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
                        .shadow(radius: 5)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
            }
        }
    }
    
    private func selectShop(_ shop: CoffeeShop) {
        searchText = ""
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            selectedShop = shop
            region.center = shop.coordinate
            region.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        }
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
} 