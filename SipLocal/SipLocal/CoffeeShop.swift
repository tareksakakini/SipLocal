import Foundation
import CoreLocation

struct CoffeeShop: Codable, Identifiable {
    let id: String
    let name: String
    let address: String
    let latitude: Double
    let longitude: Double
    let phone: String
    let website: String
    let description: String
    let imageName: String
    let stampName: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

class DataService {
    static func loadCoffeeShops() -> [CoffeeShop] {
        guard let url = Bundle.main.url(forResource: "CoffeeShops", withExtension: "json") else {
            fatalError("Could not find CoffeeShops.json in the bundle.")
        }
        
        guard let data = try? Data(contentsOf: url) else {
            fatalError("Could not load CoffeeShops.json from the bundle.")
        }
        
        let decoder = JSONDecoder()
        
        guard let coffeeShops = try? decoder.decode([CoffeeShop].self, from: data) else {
            fatalError("Could not decode CoffeeShops.json from the bundle.")
        }
        
        return coffeeShops
    }
} 