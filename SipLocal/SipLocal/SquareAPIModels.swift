import Foundation

// MARK: - Square Catalog API Response Models

struct SquareCatalogResponse: Codable {
    let objects: [SquareCatalogObject]?
    let cursor: String?
}

struct SquareCatalogSearchResponse: Codable {
    let objects: [SquareCatalogObject]?
    let relatedObjects: [SquareCatalogObject]?
    let cursor: String?
    
    enum CodingKeys: String, CodingKey {
        case objects, cursor
        case relatedObjects = "related_objects"
    }
}

struct SquareCatalogObject: Codable, Identifiable {
    let id: String
    let type: String
    let categoryData: SquareCategoryData?
    let itemData: SquareItemData?
    let imageData: SquareImageData?
    let presentAtAllLocations: Bool?
    let presentAtLocationIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case categoryData = "category_data"
        case itemData = "item_data"
        case imageData = "image_data"
        case presentAtAllLocations = "present_at_all_locations"
        case presentAtLocationIds = "present_at_location_ids"
    }
}

struct SquareCategoryData: Codable {
    let name: String
}

struct SquareItemData: Codable {
    let name: String
    let description: String?
    let categories: [SquareItemCategory]?
    let variations: [SquareItemVariation]?
    let imageIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case name, description, categories, variations
        case imageIds = "image_ids"
    }
}

struct SquareItemCategory: Codable {
    let id: String
    let ordinal: Int?
}

struct SquareItemVariation: Codable, Identifiable {
    let id: String
    let type: String
    let itemVariationData: SquareItemVariationData?
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case itemVariationData = "item_variation_data"
    }
}

struct SquareItemVariationData: Codable {
    let name: String?
    let pricingType: String?
    let priceMoney: SquareMoney?
    let ordinal: Int?
    
    enum CodingKeys: String, CodingKey {
        case name
        case pricingType = "pricing_type"
        case priceMoney = "price_money"
        case ordinal
    }
}

struct SquareMoney: Codable {
    let amount: Int
    let currency: String
}

// MARK: - Error Response Models

struct SquareErrorResponse: Codable {
    let errors: [SquareError]?
}

struct SquareError: Codable {
    let category: String
    let code: String
    let detail: String?
    let field: String?
}

// MARK: - Image Models

struct SquareImageData: Codable {
    let name: String?
    let url: String?
    let caption: String?
} 