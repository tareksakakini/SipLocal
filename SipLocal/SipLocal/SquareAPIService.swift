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
        let baseURL = "https://connect.squareupsandbox.com/v2/catalog/list"
        
        guard let url = URL(string: baseURL) else {
            throw SquareAPIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
            
            let catalogResponse = try JSONDecoder().decode(SquareCatalogResponse.self, from: data)
            return catalogResponse.objects ?? []
            
        } catch {
            if error is SquareAPIError {
                throw error
            }
            throw SquareAPIError.networkError(error)
        }
    }
    
    private func processCatalogObjects(_ objects: [SquareCatalogObject]) -> [MenuCategory] {
        // Separate categories and items
        let categories = objects.filter { $0.type == "CATEGORY" }
        let items = objects.filter { $0.type == "ITEM" }
        
        // Create menu categories
        var menuCategories: [MenuCategory] = []
        
        for categoryObject in categories {
            guard let categoryData = categoryObject.categoryData else { continue }
            
            // Find items belonging to this category
            let categoryItems = items.compactMap { itemObject -> MenuItem? in
                guard let itemData = itemObject.itemData,
                      itemData.categoryId == categoryObject.id else { return nil }
                
                // Get the primary variation (usually the first one)
                let variation = itemData.variations?.first
                let variationData = variation?.itemVariationData
                
                // Convert price from cents to dollars
                let priceInCents = variationData?.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                // Determine customizations based on item type/name
                let customizations = determineCustomizations(for: itemData.name)
                
                return MenuItem(
                    name: itemData.name,
                    price: price,
                    customizations: customizations
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
        
        // If no categories found, create a default "Menu" category with all items
        if menuCategories.isEmpty && !items.isEmpty {
            let allItems = items.compactMap { itemObject -> MenuItem? in
                guard let itemData = itemObject.itemData else { return nil }
                
                let variation = itemData.variations?.first
                let variationData = variation?.itemVariationData
                
                let priceInCents = variationData?.priceMoney?.amount ?? 0
                let price = Double(priceInCents) / 100.0
                
                let customizations = determineCustomizations(for: itemData.name)
                
                return MenuItem(
                    name: itemData.name,
                    price: price,
                    customizations: customizations
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