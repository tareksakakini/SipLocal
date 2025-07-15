import Foundation
import CoreLocation

struct MenuItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let price: Double
    let customizations: [String]?
}

struct MenuCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let items: [MenuItem]
}

// Square credentials structure
struct SquareCredentials: Codable {
    let appID: String
    let accessToken: String
    let locationId: String
}

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
    let menu: SquareCredentials
    
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
        
        do {
            let coffeeShops = try decoder.decode([CoffeeShop].self, from: data)
            return coffeeShops
        } catch {
            print("JSON decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("JSON content: \(jsonString)")
            }
            fatalError("Could not decode CoffeeShops.json from the bundle. Error: \(error)")
        }
    }
} 