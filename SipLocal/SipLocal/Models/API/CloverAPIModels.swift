import Foundation

// MARK: - Clover Credentials
struct CloverCredentials: Codable {
    let accessToken: String
    let merchantId: String
}

// MARK: - Clover Menu API Response Models

struct CloverItemsResponse: Codable {
    let elements: [CloverItem]?
}

struct CloverItem: Codable, Identifiable {
    let id: String
    let name: String
    let price: Int? // Price in cents
    let priceType: String?
    let defaultTaxRates: Bool?
    let cost: Int?
    let isRevenue: Bool?
    let stockCount: Int?
    let unitName: String?
    let categories: CloverItemCategories?
    let modifierGroups: CloverItemModifierGroups?
    let hidden: Bool?
}

struct CloverItemCategories: Codable {
    let elements: [CloverCategory]?
}

struct CloverItemModifierGroups: Codable {
    let elements: [CloverModifierGroup]?
}

struct CloverCategoriesResponse: Codable {
    let elements: [CloverCategory]?
}

struct CloverCategory: Codable, Identifiable {
    let id: String
    let name: String
    let sortOrder: Int?
}

struct CloverModifierGroupsResponse: Codable {
    let elements: [CloverModifierGroup]?
}

struct CloverModifierGroup: Codable, Identifiable {
    let id: String
    let name: String
    let showByDefault: Bool?
    let alternateName: String?
    let minRequired: Int?
    let maxAllowed: Int?
    let modifiers: CloverModifiers?
}

struct CloverModifiers: Codable {
    let elements: [CloverModifier]?
}

struct CloverModifier: Codable, Identifiable {
    let id: String
    let name: String
    let price: Int? // Price in cents
    let available: Bool?
}

// MARK: - Clover Order API Models

struct CloverOrderRequest: Codable {
    let items: [CloverOrderLineItem]
    let state: String // "open", "locked", "paid"
    let orderType: CloverOrderType?
    let note: String?
    let manualTransaction: Bool?
    let groupLineItems: Bool?
    let testMode: Bool?
}

struct CloverOrderLineItem: Codable {
    let item: CloverOrderItem
    let name: String
    let alternateName: String?
    let price: Int // Price in cents
    let unitQty: Int?
    let note: String?
    let printed: Bool?
    let exchanged: Bool?
    let refunded: Bool?
    let isRevenue: Bool?
    let modifications: [CloverLineItemModification]?
}

struct CloverOrderItem: Codable {
    let id: String
}

struct CloverLineItemModification: Codable {
    let modifier: CloverOrderModifier
    let name: String?
    let alternateName: String?
    let amount: Int? // Amount in cents
}

struct CloverOrderModifier: Codable {
    let id: String
}

struct CloverOrderType: Codable {
    let id: String
}

struct CloverOrderResponse: Codable {
    let id: String
    let currency: String?
    let employee: CloverEmployee?
    let total: Int? // Total in cents
    let paymentState: String?
    let title: String?
    let note: String?
    let orderType: CloverOrderType?
    let taxRemoved: Bool?
    let isVat: Bool?
    let state: String?
    let manualTransaction: Bool?
    let groupLineItems: Bool?
    let testMode: Bool?
    let createdTime: Int64?
    let clientCreatedTime: Int64?
    let modifiedTime: Int64?
}

struct CloverEmployee: Codable {
    let id: String
}

// MARK: - Clover Merchant Info Models

struct CloverMerchant: Codable {
    let id: String
    let name: String
    let address: CloverAddress?
    let phone: String?
    let website: String?
    let timezone: String?
}

struct CloverAddress: Codable {
    let address1: String?
    let address2: String?
    let address3: String?
    let city: String?
    let state: String?
    let zip: String?
    let country: String?
}

// MARK: - Clover Business Hours Models

struct CloverOpeningHoursResponse: Codable {
    let elements: [CloverOpeningHours]?
    let href: String?
}

struct CloverOpeningHours: Codable, Identifiable {
    let id: String
    let name: String?
    let sunday: CloverDayHours?
    let monday: CloverDayHours?
    let tuesday: CloverDayHours?
    let wednesday: CloverDayHours?
    let thursday: CloverDayHours?
    let friday: CloverDayHours?
    let saturday: CloverDayHours?
}

struct CloverDayHours: Codable {
    let elements: [CloverTimeSlot]?
}

struct CloverTimeSlot: Codable {
    let start: Int // Time in minutes since midnight (e.g., 900 = 9:00 AM)
    let end: Int   // Time in minutes since midnight (e.g., 1700 = 5:00 PM)
}

// MARK: - Error Response Models

struct CloverErrorResponse: Codable {
    let message: String
    let type: String?
}

// MARK: - App Business Hours Models (reused from Square)

// BusinessHoursInfo and BusinessHoursPeriod are already defined in SquareAPIModels.swift
// We'll reuse those structures for consistency

// MARK: - Order Status Mapping

enum CloverOrderState: String, CaseIterable {
    case open = "open"
    case locked = "locked" 
    case paid = "paid"
}

enum CloverPaymentState: String, CaseIterable {
    case open = "OPEN"
    case paid = "PAID"
    case partially_paid = "PARTIALLY_PAID"
    case partially_refunded = "PARTIALLY_REFUNDED"
    case refunded = "REFUNDED"
}
