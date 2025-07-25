import Foundation

class SquareAPIService {
    static let shared = SquareAPIService()
    private let tokenService = TokenService()
    
    private init() {}
    
    // MARK: - Main Function to Fetch Menu Data
    
    func fetchMenuData(for shop: CoffeeShop) async throws -> [MenuCategory] {
        print("🔍 SquareAPIService: Starting menu fetch for shop: \(shop.name) (merchantId: \(shop.merchantId))")
        
        do {
            // First, fetch the merchant tokens from the backend
            print("🔍 SquareAPIService: Fetching tokens from backend...")
            let credentials = try await tokenService.getMerchantTokens(merchantId: shop.merchantId)
            print("🔍 SquareAPIService: Successfully got credentials, fetching catalog...")
            
            let catalogObjects = try await fetchCatalogObjects(credentials: credentials)
            print("🔍 SquareAPIService: Successfully fetched \(catalogObjects.count) catalog objects")
            
            let categories = processCatalogObjects(catalogObjects)
            print("🔍 SquareAPIService: Successfully processed into \(categories.count) menu categories")
            
            return categories
        } catch {
            print("❌ SquareAPIService: Error fetching menu data for \(shop.name): \(error)")
            print("❌ SquareAPIService: Error type: \(type(of: error))")
            print("❌ SquareAPIService: Error description: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Order Status Fetching
    
    func fetchOrderStatus(orderId: String, merchantId: String) async throws -> OrderStatus {
        do {
            // First, fetch the merchant tokens from the backend
            let credentials = try await tokenService.getMerchantTokens(merchantId: merchantId)
            
            let squareOrder = try await fetchSquareOrder(orderId: orderId, credentials: credentials)
            
            // Convert Square order state to our OrderStatus
            let orderStatus = convertSquareOrderToOrderStatus(squareOrder)
            
            return orderStatus
            
        } catch {
            print("❌ SquareAPIService: Error fetching order status: \(error)")
            throw error
        }
    }
    
    // MARK: - Private Functions
    
    private func fetchCatalogObjects(credentials: SquareCredentials) async throws -> [SquareCatalogObject] {
        let baseURL = "https://connect.squareup.com/v2/catalog/search"
        
        guard let url = URL(string: baseURL) else {
            throw SquareAPIError.invalidURL
        }
        
        // Create search request body to get items, categories, images, and modifier lists
        let searchRequest: [String: Any] = [
            "object_types": ["ITEM", "CATEGORY", "IMAGE", "MODIFIER_LIST"],
            "include_related_objects": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.oauth_token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: searchRequest)
        } catch {
            throw SquareAPIError.networkError(error)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SquareAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(SquareErrorResponse.self, from: data) {
                    throw SquareAPIError.apiError(errorResponse.errors?.first?.detail ?? "Unknown error")
                }
                throw SquareAPIError.httpError(httpResponse.statusCode)
            }
            
            let searchResponse = try JSONDecoder().decode(SquareCatalogSearchResponse.self, from: data)
            
            // Combine objects and related objects
            var allObjects: [SquareCatalogObject] = []
            if let objects = searchResponse.objects {
                allObjects.append(contentsOf: objects)
            }
            if let relatedObjects = searchResponse.relatedObjects {
                allObjects.append(contentsOf: relatedObjects)
            }
            
            return allObjects
            
        } catch {
            if error is SquareAPIError {
                throw error
            }
            throw SquareAPIError.networkError(error)
        }
    }
    
    private func processCatalogObjects(_ objects: [SquareCatalogObject]) -> [MenuCategory] {
        // Separate categories, items, images, and modifier lists
        let categories = objects.filter { $0.type == "CATEGORY" }
        let items = objects.filter { $0.type == "ITEM" }
        let images = objects.filter { $0.type == "IMAGE" }
        let modifierLists = objects.filter { $0.type == "MODIFIER_LIST" }
        
        // Create image mapping for quick lookup
        let imageMapping: [String: String] = Dictionary(uniqueKeysWithValues: images.compactMap { imageObject in
            guard let imageData = imageObject.imageData, let url = imageData.url else { return nil }
            return (imageObject.id, url)
        })
        
        // Create modifier list mapping for quick lookup
        let modifierListMapping: [String: MenuItemModifierList] = Dictionary(uniqueKeysWithValues: modifierLists.compactMap { modifierListObject in
            guard let modifierListData = modifierListObject.modifierListData else { return nil }
            
            // Convert SquareModifierListData to MenuItemModifierList
            let modifiers = modifierListData.modifiers?.compactMap { squareModifier -> MenuItemModifier? in
                guard let modifierData = squareModifier.modifierData else { return nil }
                
                // Convert price from cents to dollars
                let priceInCents = modifierData.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                return MenuItemModifier(
                    id: squareModifier.id,
                    name: modifierData.name,
                    price: price,
                    isDefault: modifierData.onByDefault ?? false
                )
            } ?? []
            
            return (modifierListObject.id, MenuItemModifierList(
                id: modifierListObject.id,
                name: modifierListData.name,
                selectionType: modifierListData.selectionType ?? "SINGLE",
                minSelections: 0, // Will be updated by getModifierLists
                maxSelections: 1, // Will be updated by getModifierLists
                modifiers: modifiers
            ))
        })
        
        // Process categories and their items
        var processedItemIds = Set<String>()
        var menuCategories: [MenuCategory] = []
        
        for categoryObject in categories {
            guard let categoryData = categoryObject.categoryData else { continue }
            
            // Find items belonging to this category
            let categoryItems = items.compactMap { itemObject -> MenuItem? in
                guard let itemData = itemObject.itemData else { return nil }
                
                // Get category IDs for this item
                let itemCategoryIds = itemData.categories?.map { $0.id } ?? []
                
                // Check if item belongs to this category
                guard itemCategoryIds.contains(categoryObject.id) else { return nil }
                
                // Mark this item as processed
                processedItemIds.insert(itemObject.id)
                
                // Process all variations to get size options
                let variations = processItemVariations(itemData.variations)
                
                // Get base price from first variation for backward compatibility
                let basePrice = variations.first?.price ?? 0.0
                
                // Get modifier lists for this item
                let modifierLists = getModifierLists(for: itemData, from: modifierListMapping)
                
                // Get image URL for this item
                let imageURL = getImageURL(for: itemData, from: imageMapping)
                
                // Keep legacy customizations for backward compatibility
                let customizations = extractCustomizationTypes(from: modifierLists)
                
                return MenuItem(
                    id: itemObject.id, // <-- Pass unique Square id
                    name: itemData.name,
                    price: basePrice,
                    variations: variations.isEmpty ? nil : variations,
                    customizations: customizations,
                    imageURL: imageURL,
                    modifierLists: modifierLists
                )
            }
            
            if !categoryItems.isEmpty {
                menuCategories.append(MenuCategory(name: categoryData.name, items: categoryItems))
            }
        }
        
        // Add any remaining items that weren't assigned to categories
        let remainingItems = items.compactMap { itemObject -> MenuItem? in
            guard let itemData = itemObject.itemData else { return nil }
            
            // Skip if already processed
            guard !processedItemIds.contains(itemObject.id) else { return nil }
            
            // Process all variations to get size options
            let variations = processItemVariations(itemData.variations)
            
            // Get base price from first variation for backward compatibility
            let basePrice = variations.first?.price ?? 0.0
            
            // Get modifier lists for this item
            let modifierLists = getModifierLists(for: itemData, from: modifierListMapping)
            
            // Get image URL for this item
            let imageURL = getImageURL(for: itemData, from: imageMapping)
            
            // Keep legacy customizations for backward compatibility
            let customizations = extractCustomizationTypes(from: modifierLists)
            
            return MenuItem(
                id: itemObject.id,
                name: itemData.name,
                price: basePrice,
                variations: variations.isEmpty ? nil : variations,
                customizations: customizations,
                imageURL: imageURL,
                modifierLists: modifierLists
            )
        }
        
        if !remainingItems.isEmpty {
            menuCategories.append(MenuCategory(name: "Other", items: remainingItems))
        }
        
        // Sort by ordinal to maintain consistent ordering
        return menuCategories.sorted { $0.name < $1.name }
    }
    
    private func createModifierListMapping(from modifierLists: [SquareCatalogObject]) -> [String: MenuItemModifierList] {
        var mapping: [String: MenuItemModifierList] = [:]
        
        for modifierListObject in modifierLists {
            guard let modifierListData = modifierListObject.modifierListData else { continue }
            
            // Convert Square modifiers to app modifiers
            let appModifiers = modifierListData.modifiers?.compactMap { squareModifier -> MenuItemModifier? in
                guard let modifierData = squareModifier.modifierData else { return nil }
                
                let priceInCents = modifierData.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                return MenuItemModifier(
                    id: squareModifier.id,
                    name: modifierData.name,
                    price: price,
                    isDefault: modifierData.onByDefault ?? false
                )
            } ?? []
            
            let appModifierList = MenuItemModifierList(
                id: modifierListObject.id,
                name: modifierListData.name,
                selectionType: modifierListData.selectionType ?? "SINGLE",
                minSelections: 0, // Will be updated when processing items
                maxSelections: 1, // Will be updated when processing items
                modifiers: appModifiers
            )
            
            mapping[modifierListObject.id] = appModifierList
        }
        
        print("DEBUG: Created modifier list mapping with \(mapping.count) modifier lists")
        return mapping
    }
    
    private func getModifierLists(for itemData: SquareItemData, from mapping: [String: MenuItemModifierList]) -> [MenuItemModifierList] {
        guard let modifierListInfos = itemData.modifierListInfo else { return [] }
        
        var modifierLists: [MenuItemModifierList] = []
        
        for modifierListInfo in modifierListInfos {
            // Skip if disabled or hidden from customer
            if modifierListInfo.enabled == false || modifierListInfo.hiddenFromCustomer == true {
                continue
            }
            
            guard var modifierList = mapping[modifierListInfo.modifierListId] else { continue }
            
            // Update min/max selections based on item's modifier list info
            let minSelections = max(0, modifierListInfo.minSelectedModifiers ?? 0)
            let maxSelections = modifierListInfo.maxSelectedModifiers ?? 1
            
            // Create updated modifier list with correct min/max selections
            let updatedModifierList = MenuItemModifierList(
                id: modifierList.id,
                name: modifierList.name,
                selectionType: modifierList.selectionType,
                minSelections: minSelections,
                maxSelections: maxSelections,
                modifiers: modifierList.modifiers
            )
            
            modifierLists.append(updatedModifierList)
        }
        
        return modifierLists
    }
    
    private func processItemVariations(_ squareVariations: [SquareItemVariation]?) -> [MenuItemVariation] {
        guard let squareVariations = squareVariations else { return [] }
        
        let variations = squareVariations.compactMap { variation -> MenuItemVariation? in
            guard let variationData = variation.itemVariationData else { return nil }
            
            // Convert price from cents to dollars
            let priceInCents = variationData.priceMoney?.amount ?? 0
            let price = Double(priceInCents) / 100.0
            
            return MenuItemVariation(
                id: variation.id,
                name: variationData.name ?? "Size",
                price: price,
                ordinal: variationData.ordinal ?? 0
            )
        }
        
        // Sort by ordinal to maintain consistent ordering
        return variations.sorted { $0.ordinal < $1.ordinal }
    }
    
    private func extractCustomizationTypes(from modifierLists: [MenuItemModifierList]) -> [String]? {
        guard !modifierLists.isEmpty else { return nil }
        
        var customizations: [String] = []
        
        for modifierList in modifierLists {
            let name = modifierList.name.lowercased()
            
            if name.contains("size") {
                customizations.append("size")
            } else if name.contains("ice") {
                customizations.append("ice")
            } else if name.contains("milk") {
                customizations.append("milk")
            } else if name.contains("sugar") || name.contains("sweet") {
                customizations.append("sugar")
            } else {
                // For other modifier lists, use a generic type
                customizations.append("other")
            }
        }
        
        return customizations.isEmpty ? nil : customizations
    }
    
    private func createImageMapping(from images: [SquareCatalogObject]) -> [String: String] {
        var mapping: [String: String] = [:]
        
        for imageObject in images {
            guard let imageData = imageObject.imageData,
                  let imageURL = imageData.url else { continue }
            
            mapping[imageObject.id] = imageURL
        }
        
        print("DEBUG: Created image mapping with \(mapping.count) images")
        return mapping
    }
    
    private func getImageURL(for itemData: SquareItemData, from imageMapping: [String: String]) -> String? {
        // Get the first image ID if available
        guard let imageIds = itemData.imageIds,
              let firstImageId = imageIds.first else { 
            print("DEBUG: No imageIds found for item '\(itemData.name)'")
            return nil 
        }
        
        let imageURL = imageMapping[firstImageId]
        print("DEBUG: Item '\(itemData.name)' -> imageId: \(firstImageId) -> URL: \(imageURL ?? "nil")")
        return imageURL
    }
    
    private func fetchSquareOrder(orderId: String, credentials: SquareCredentials) async throws -> SquareOrder {
        let baseURL = "https://connect.squareup.com/v2/orders/\(orderId)"
        
        guard let url = URL(string: baseURL) else {
            throw SquareAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.oauth_token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw SquareAPIError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(SquareErrorResponse.self, from: data) {
                    throw SquareAPIError.apiError(errorResponse.errors?.first?.detail ?? "Unknown error")
                }
                throw SquareAPIError.httpError(httpResponse.statusCode)
            }
            
            let orderResponse = try JSONDecoder().decode(SquareOrderResponse.self, from: data)
            
            guard let order = orderResponse.order else {
                throw SquareAPIError.apiError("Order not found")
            }
            
            return order
            
        } catch {
            if error is SquareAPIError {
                throw error
            }
            throw SquareAPIError.networkError(error)
        }
    }
    
    private func convertSquareOrderStateToOrderStatus(_ squareState: String) -> OrderStatus {
        switch squareState.uppercased() {
        case "OPEN":
            // For Square, OPEN means the order is active and being processed
            // We'll check fulfillment states to determine the exact status
            return .inProgress
        case "COMPLETED":
            return .completed
        case "CANCELED":
            return .cancelled
        case "DRAFT":
            return .draft
        case "PENDING":
            return .pending
        default:
            // Default to submitted for unknown states
            return .submitted
        }
    }
    
    private func convertSquareOrderToOrderStatus(_ squareOrder: SquareOrder) -> OrderStatus {
        // First check the main order state
        let baseStatus = convertSquareOrderStateToOrderStatus(squareOrder.state)
        
        // If the order is OPEN, check fulfillment states for more specific status
        if baseStatus == .inProgress {
            // Check fulfillment states to determine if it's ready for pickup
            if let fulfillments = squareOrder.fulfillments {
                for fulfillment in fulfillments {
                    if fulfillment.type == "PICKUP" {
                        switch fulfillment.state.uppercased() {
                        case "PROPOSED":
                            return .submitted // Order submitted, waiting for merchant
                        case "RESERVED":
                            return .inProgress // Merchant has accepted and is preparing
                        case "PREPARED":
                            return .ready // Order is ready for pickup
                        case "FULFILLED":
                            return .completed // Order has been picked up
                        case "CANCELED":
                            return .cancelled
                        default:
                            return .inProgress
                        }
                    }
                }
            }
        }
        
        return baseStatus
    }
}

// MARK: - Error Types

enum SquareAPIError: Error, LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case apiError(String)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response"
        case .httpError(let code):
            return "HTTP Error: \(code)"
        case .apiError(let message):
            return "API Error: \(message)"
        case .networkError(let error):
            return "Network Error: \(error.localizedDescription)"
        }
    }
} 