import Foundation

class SquareAPIService {
    static let shared = SquareAPIService()
    
    private init() {}
    
    // MARK: - Main Function to Fetch Menu Data
    
    func fetchMenuData(for shop: CoffeeShop) async throws -> [MenuCategory] {
        let catalogObjects = try await fetchCatalogObjects(credentials: shop.menu)
        return processCatalogObjects(catalogObjects)
    }
    
    // MARK: - Private Functions
    
    private func fetchCatalogObjects(credentials: SquareCredentials) async throws -> [SquareCatalogObject] {
        let baseURL = "https://connect.squareupsandbox.com/v2/catalog/search"
        
        guard let url = URL(string: baseURL) else {
            throw SquareAPIError.invalidURL
        }
        
        // Create search request body to get items, categories, and images
        let searchRequest: [String: Any] = [
            "object_types": ["ITEM", "CATEGORY", "IMAGE"],
            "include_related_objects": true
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
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
        // Separate categories, items, and images
        let categories = objects.filter { $0.type == "CATEGORY" }
        let items = objects.filter { $0.type == "ITEM" }
        let images = objects.filter { $0.type == "IMAGE" }
        
        print("DEBUG: Found \(categories.count) categories, \(items.count) items, and \(images.count) images")
        
        // Debug: Print image information
        print("DEBUG: Images:")
        for image in images {
            print("  - ID: \(image.id), URL: \(image.imageData?.url ?? "nil")")
        }
        
        // Debug: Print items with their imageIds
        print("DEBUG: Items with imageIds:")
        for item in items {
            let imageIds = item.itemData?.imageIds ?? []
            print("  - \(item.itemData?.name ?? "Unknown"): imageIds = \(imageIds)")
        }
        
        // Create image mapping (image ID -> image URL)
        let imageMapping = createImageMapping(from: images)
        
        // Create menu categories
        var menuCategories: [MenuCategory] = []
        var processedItemIds: Set<String> = []
        
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
                
                // Get the primary variation (usually the first one)
                let variation = itemData.variations?.first
                let variationData = variation?.itemVariationData
                
                // Convert price from cents to dollars
                let priceInCents = variationData?.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                // Determine customizations based on item type/name
                let customizations = determineCustomizations(for: itemData.name)
                
                // Get image URL for this item
                let imageURL = getImageURL(for: itemData, from: imageMapping)
                
                return MenuItem(
                    name: itemData.name,
                    price: price,
                    customizations: customizations,
                    imageURL: imageURL
                )
            }
            
            if !categoryItems.isEmpty {
                let menuCategory = MenuCategory(
                    name: categoryData.name,
                    items: categoryItems
                )
                menuCategories.append(menuCategory)
            }
        }
        
        // Handle uncategorized items (items without a category or items that didn't match any category)
        let uncategorizedItems = items.compactMap { itemObject -> MenuItem? in
            guard let itemData = itemObject.itemData else { return nil }
            
            // Skip items that were already processed
            guard !processedItemIds.contains(itemObject.id) else { return nil }
            
            // Get the primary variation (usually the first one)
            let variation = itemData.variations?.first
            let variationData = variation?.itemVariationData
            
            // Convert price from cents to dollars
            let priceInCents = variationData?.priceMoney?.amount ?? 0
            let price = Double(priceInCents) / 100.0
            
            // Determine customizations based on item type/name
            let customizations = determineCustomizations(for: itemData.name)
            
            // Get image URL for this item
            let imageURL = getImageURL(for: itemData, from: imageMapping)
            
            return MenuItem(
                name: itemData.name,
                price: price,
                customizations: customizations,
                imageURL: imageURL
            )
        }
        
        // If there are uncategorized items, add them to an "Other" category
        if !uncategorizedItems.isEmpty {
            menuCategories.append(MenuCategory(name: "Other", items: uncategorizedItems))
        }
        
        // If no categories found at all, create a default "Menu" category with all items
        if menuCategories.isEmpty && !items.isEmpty {
            let allItems = items.compactMap { itemObject -> MenuItem? in
                guard let itemData = itemObject.itemData else { return nil }
                
                let variation = itemData.variations?.first
                let variationData = variation?.itemVariationData
                
                let priceInCents = variationData?.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                let customizations = determineCustomizations(for: itemData.name)
                
                // Get image URL for this item
                let imageURL = getImageURL(for: itemData, from: imageMapping)
                
                return MenuItem(
                    name: itemData.name,
                    price: price,
                    customizations: customizations,
                    imageURL: imageURL
                )
            }
            
            if !allItems.isEmpty {
                menuCategories.append(MenuCategory(name: "Menu", items: allItems))
            }
        }
        
        return menuCategories
    }
    
    private func determineCustomizations(for itemName: String) -> [String]? {
        let lowercaseName = itemName.lowercased()
        
        // Determine if item is customizable based on name
        if lowercaseName.contains("coffee") || lowercaseName.contains("latte") || 
           lowercaseName.contains("cappuccino") || lowercaseName.contains("espresso") ||
           lowercaseName.contains("americano") || lowercaseName.contains("mocha") {
            return ["size", "milk", "sugar"]
        } else if lowercaseName.contains("iced") || lowercaseName.contains("cold") ||
                  lowercaseName.contains("frappe") || lowercaseName.contains("smoothie") {
            return ["size", "ice", "milk", "sugar"]
        } else if lowercaseName.contains("tea") {
            return ["size", "sugar"]
        }
        
        return nil
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