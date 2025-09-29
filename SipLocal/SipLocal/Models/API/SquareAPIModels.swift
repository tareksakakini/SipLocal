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
    let modifierListData: SquareModifierListData?
    let presentAtAllLocations: Bool?
    let presentAtLocationIds: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case categoryData = "category_data"
        case itemData = "item_data"
        case imageData = "image_data"
        case modifierListData = "modifier_list_data"
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
    let modifierListInfo: [SquareModifierListInfo]?
    
    enum CodingKeys: String, CodingKey {
        case name, description, categories, variations
        case imageIds = "image_ids"
        case modifierListInfo = "modifier_list_info"
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

// MARK: - Modifier Models

struct SquareModifierListInfo: Codable {
    let modifierListId: String
    let minSelectedModifiers: Int?
    let maxSelectedModifiers: Int?
    let enabled: Bool?
    let hiddenFromCustomer: Bool?
    
    enum CodingKeys: String, CodingKey {
        case modifierListId = "modifier_list_id"
        case minSelectedModifiers = "min_selected_modifiers"
        case maxSelectedModifiers = "max_selected_modifiers"
        case enabled = "enabled"
        case hiddenFromCustomer = "hidden_from_customer"
    }
}

struct SquareModifierListData: Codable {
    let name: String
    let ordinal: Int?
    let selectionType: String?
    let modifiers: [SquareModifier]?
    
    enum CodingKeys: String, CodingKey {
        case name, ordinal, modifiers
        case selectionType = "selection_type"
    }
}

struct SquareModifier: Codable, Identifiable {
    let id: String
    let type: String
    let modifierData: SquareModifierData?
    
    enum CodingKeys: String, CodingKey {
        case id, type
        case modifierData = "modifier_data"
    }
}

struct SquareModifierData: Codable {
    let name: String
    let priceMoney: SquareMoney?
    let ordinal: Int?
    let modifierListId: String?
    let onByDefault: Bool?
    
    enum CodingKeys: String, CodingKey {
        case name, ordinal
        case priceMoney = "price_money"
        case modifierListId = "modifier_list_id"
        case onByDefault = "on_by_default"
    }
}

// MARK: - Square Order API Response Models

struct SquareOrderResponse: Codable {
    let order: SquareOrder?
    let errors: [SquareError]?
}

struct SquareOrder: Codable {
    let id: String
    let locationId: String
    let state: String
    let lineItems: [SquareOrderLineItem]?
    let fulfillments: [SquareOrderFulfillment]?
    let createdAt: String?
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case locationId = "location_id"
        case state
        case lineItems = "line_items"
        case fulfillments
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SquareOrderLineItem: Codable {
    let uid: String?
    let name: String
    let quantity: String
    let basePriceMoney: SquareMoney?
    let totalMoney: SquareMoney?
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case uid, name, quantity, note
        case basePriceMoney = "base_price_money"
        case totalMoney = "total_money"
    }
}

struct SquareOrderFulfillment: Codable {
    let uid: String?
    let type: String
    let state: String
    let pickupDetails: SquarePickupDetails?
    
    enum CodingKeys: String, CodingKey {
        case uid, type, state
        case pickupDetails = "pickup_details"
    }
}

struct SquarePickupDetails: Codable {
    let recipient: SquareRecipient?
    let pickupAt: String?
    let note: String?
    
    enum CodingKeys: String, CodingKey {
        case recipient
        case pickupAt = "pickup_at"
        case note
    }
}

struct SquareRecipient: Codable {
    let displayName: String?
    
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
    }
}

// MARK: - Business Hours Models

struct SquareLocationResponse: Codable {
    let location: SquareLocation?
    let errors: [SquareError]?
}

struct SquareLocationsResponse: Codable {
    let locations: [SquareLocation]?
    let errors: [SquareError]?
}

struct SquareLocation: Codable {
    let id: String
    let name: String?
    let businessHours: SquareBusinessHours?
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case businessHours = "business_hours"
    }
}

struct SquareBusinessHours: Codable {
    let periods: [SquareBusinessHoursPeriod]?
    let specialDayPeriods: [SquareSpecialDayPeriod]?
    
    enum CodingKeys: String, CodingKey {
        case periods
        case specialDayPeriods = "special_day_periods"
    }
}

struct SquareBusinessHoursPeriod: Codable {
    let dayOfWeek: String
    let startLocalTime: String?
    let endLocalTime: String?
    
    enum CodingKeys: String, CodingKey {
        case dayOfWeek = "day_of_week"
        case startLocalTime = "start_local_time"
        case endLocalTime = "end_local_time"
    }
}

struct SquareSpecialDayPeriod: Codable {
    let startDate: String?
    let endDate: String?
    let periods: [SquareBusinessHoursPeriod]?
    
    enum CodingKeys: String, CodingKey {
        case startDate = "start_date"
        case endDate = "end_date"
        case periods
    }
}

// MARK: - App Business Hours Models

struct BusinessHoursInfo: Codable {
    let weeklyHours: [String: [BusinessHoursPeriod]]
    let isCurrentlyOpen: Bool
}

struct BusinessHoursPeriod: Codable {
    let startTime: String
    let endTime: String
} 
