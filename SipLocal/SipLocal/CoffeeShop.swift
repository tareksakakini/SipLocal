import Foundation
import CoreLocation

struct MenuItemModifier: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let isDefault: Bool
}

struct MenuItemVariation: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let ordinal: Int
}

struct MenuItemModifierList: Codable, Identifiable {
    let id: String
    let name: String
    let selectionType: String // "SINGLE" or "MULTIPLE"
    let minSelections: Int
    let maxSelections: Int
    let modifiers: [MenuItemModifier]
}

struct MenuItem: Codable, Identifiable {
    let id: String // Unique Square item id
    let name: String
    let price: Double // Base price (from first variation for backward compatibility)
    let variations: [MenuItemVariation]?
    let customizations: [String]? // Keep for backward compatibility
    let imageURL: String?
    let modifierLists: [MenuItemModifierList]?
    
    // Helper to get the default variation price
    var basePrice: Double {
        return variations?.first?.price ?? price
    }
    
    // Helper to check if item has size variations
    var hasSizeVariations: Bool {
        return variations != nil && variations!.count > 1
    }
}

struct MenuCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let items: [MenuItem]
}

// Square credentials structure
struct SquareCredentials: Codable {
    let oauth_token: String
    let merchantId: String
    let refreshToken: String
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
    let merchantId: String
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    // Helper method to convert to dictionary for backend
    func toDictionary() -> [String: Any] {
        return [
            "id": id,
            "name": name,
            "address": address,
            "latitude": latitude,
            "longitude": longitude,
            "phone": phone,
            "website": website,
            "description": description,
            "imageName": imageName,
            "stampName": stampName,
            "merchantId": merchantId
        ]
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