import SwiftUI
import MapKit

struct ExploreView: View {
    @State private var coffeeShops: [CoffeeShop] = DataService.loadCoffeeShops()
    @State private var searchText: String = ""
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.5816, longitude: -121.4944),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var filteredCoffeeShops: [CoffeeShop] {
        if searchText.isEmpty {
            return coffeeShops
        } else {
            return coffeeShops.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: filteredCoffeeShops) { shop in
                MapAnnotation(coordinate: shop.coordinate) {
                    VStack {
                        Image(systemName: "cup.and.saucer.fill")
                            .font(.title)
                            .foregroundColor(.accentColor)
                        Text(shop.name)
                            .font(.caption)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .edgesIgnoringSafeArea(.top)

            VStack {
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
                
                Spacer()
            }
            .padding(.top)
        }
    }
}

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
    }
} 