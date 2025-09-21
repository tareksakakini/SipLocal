import Foundation
import CoreLocation

/**
 * CoffeeShop.swift - Core data models for the SipLocal app.
 *
 * ## Responsibilities
 * - **Menu Models**: Defines menu item structures with variations and modifiers
 * - **Coffee Shop Model**: Core coffee shop data structure with location and POS integration
 * - **POS Integration**: Handles different POS system types and credentials
 * - **Data Service**: Provides coffee shop data loading functionality
 *
 * ## Architecture
 * - **Model Layer**: Clean data models with proper Codable conformance
 * - **Service Extraction**: Data loading extracted to dedicated service
 * - **Type Safety**: Strong typing with enums and proper validation
 * - **Location Integration**: CoreLocation integration for mapping
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

// MARK: - Menu Item Models

struct MenuItemModifier: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let isDefault: Bool
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !id.isEmpty && !name.isEmpty && price >= 0
    }
    
    // MARK: - Computed Properties
    
    var displayPrice: String {
        return String(format: "$%.2f", price)
    }
}

struct MenuItemVariation: Codable, Identifiable {
    let id: String
    let name: String
    let price: Double
    let ordinal: Int
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !id.isEmpty && !name.isEmpty && price >= 0 && ordinal >= 0
    }
    
    // MARK: - Computed Properties
    
    var displayPrice: String {
        return String(format: "$%.2f", price)
    }
}

struct MenuItemModifierList: Codable, Identifiable {
    let id: String
    let name: String
    let selectionType: String // "SINGLE" or "MULTIPLE"
    let minSelections: Int
    let maxSelections: Int
    let modifiers: [MenuItemModifier]
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !id.isEmpty && !name.isEmpty && 
               minSelections >= 0 && maxSelections >= minSelections &&
               modifiers.allSatisfy { $0.isValid }
    }
    
    // MARK: - Computed Properties
    
    var isSingleSelection: Bool {
        return selectionType.uppercased() == "SINGLE"
    }
    
    var isMultipleSelection: Bool {
        return selectionType.uppercased() == "MULTIPLE"
    }
    
    var defaultModifiers: [MenuItemModifier] {
        return modifiers.filter { $0.isDefault }
    }
}

struct MenuItem: Codable, Identifiable {
    let id: String // Unique Square item id
    let name: String
    let price: Double // Base price (from first variation for backward compatibility)
    let variations: [MenuItemVariation]?
    let customizations: [String]? // Keep for backward compatibility
    let imageURL: String?
    let modifierLists: [MenuItemModifierList]?
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !id.isEmpty && !name.isEmpty && price >= 0 &&
               (variations?.allSatisfy { $0.isValid } ?? true) &&
               (modifierLists?.allSatisfy { $0.isValid } ?? true)
    }
    
    // MARK: - Computed Properties
    
    var basePrice: Double {
        return variations?.first?.price ?? price
    }
    
    var hasSizeVariations: Bool {
        return variations != nil && variations!.count > 1
    }
    
    var hasModifiers: Bool {
        return modifierLists != nil && !modifierLists!.isEmpty
    }
    
    var displayPrice: String {
        return String(format: "$%.2f", basePrice)
    }
    
    var sortedVariations: [MenuItemVariation] {
        return variations?.sorted { $0.ordinal < $1.ordinal } ?? []
    }
    
    var defaultVariation: MenuItemVariation? {
        return sortedVariations.first
    }
}

struct MenuCategory: Codable, Identifiable {
    var id: String { name }
    let name: String
    let items: [MenuItem]
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !name.isEmpty && items.allSatisfy { $0.isValid }
    }
    
    // MARK: - Computed Properties
    
    var itemCount: Int {
        return items.count
    }
    
    var hasItems: Bool {
        return !items.isEmpty
    }
    
    var validItems: [MenuItem] {
        return items.filter { $0.isValid }
    }
}

// MARK: - POS Integration Models

struct SquareCredentials: Codable {
    let oauth_token: String
    let merchantId: String
    let refreshToken: String
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !oauth_token.isEmpty && !merchantId.isEmpty && !refreshToken.isEmpty
    }
}

enum POSType: String, Codable, CaseIterable {
    case square = "square"
    case clover = "clover"
    
    // MARK: - Computed Properties
    
    var displayName: String {
        switch self {
        case .square:
            return "Square"
        case .clover:
            return "Clover"
        }
    }
    
    var isSquare: Bool {
        return self == .square
    }
    
    var isClover: Bool {
        return self == .clover
    }
}

// MARK: - Coffee Shop Model

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
    let posType: POSType
    
    // MARK: - Validation
    
    var isValid: Bool {
        return !id.isEmpty && !name.isEmpty && !address.isEmpty &&
               !phone.isEmpty && !merchantId.isEmpty &&
               latitude >= -90 && latitude <= 90 &&
               longitude >= -180 && longitude <= 180
    }
    
    // MARK: - Computed Properties
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var hasValidLocation: Bool {
        return latitude != 0 && longitude != 0
    }
    
    var hasWebsite: Bool {
        return !website.isEmpty
    }
    
    var hasDescription: Bool {
        return !description.isEmpty
    }
    
    var displayPhone: String {
        // Format phone number for display
        let digits = phone.filter { $0.isNumber }
        if digits.count == 10 {
            return String(format: "(%@) %@-%@", 
                         String(digits.prefix(3)),
                         String(digits.dropFirst(3).prefix(3)),
                         String(digits.suffix(4)))
        }
        return phone
    }
    
    var posDisplayName: String {
        return posType.displayName
    }
    
    // MARK: - Helper Methods
    
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
            "merchantId": merchantId,
            "posType": posType.rawValue
        ]
    }
    
    func distance(from location: CLLocation) -> CLLocationDistance {
        let shopLocation = CLLocation(latitude: latitude, longitude: longitude)
        return location.distance(from: shopLocation)
    }
}

// MARK: - Data Service

class CoffeeShopDataService {
    
    // MARK: - Design System
    
    enum Design {
        static let resourceName = "CoffeeShops"
        static let resourceExtension = "json"
        
        // Error Messages
        static let fileNotFoundError = "Could not find CoffeeShops.json in the bundle"
        static let dataLoadError = "Could not load CoffeeShops.json from the bundle"
        static let decodingError = "Could not decode CoffeeShops.json from the bundle"
    }
    
    // MARK: - Public Methods
    
    static func loadCoffeeShops() -> [CoffeeShop] {
        guard let url = Bundle.main.url(forResource: Design.resourceName, withExtension: Design.resourceExtension) else {
            logError("\(Design.fileNotFoundError)")
            fatalError(Design.fileNotFoundError)
        }
        
        guard let data = try? Data(contentsOf: url) else {
            logError("\(Design.dataLoadError)")
            fatalError(Design.dataLoadError)
        }
        
        let decoder = JSONDecoder()
        
        do {
            let coffeeShops = try decoder.decode([CoffeeShop].self, from: data)
            let validShops = coffeeShops.filter { $0.isValid }
            
            if validShops.count != coffeeShops.count {
                logWarning("Filtered out \(coffeeShops.count - validShops.count) invalid coffee shops")
            }
            
            logInfo("Loaded \(validShops.count) valid coffee shops")
            return validShops
            
        } catch {
            logError("JSON decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                logError("JSON content: \(jsonString)")
            }
            fatalError("\(Design.decodingError). Error: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    private static func logInfo(_ message: String) {
        print("📊 [CoffeeShopDataService] \(message)")
    }
    
    private static func logWarning(_ message: String) {
        print("⚠️ [CoffeeShopDataService] \(message)")
    }
    
    private static func logError(_ message: String) {
        print("❌ [CoffeeShopDataService] \(message)")
    }
} 