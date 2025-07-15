import Foundation
import SwiftUI

@MainActor
class MenuDataManager: ObservableObject {
    static let shared = MenuDataManager()
    
    @Published var menuData: [String: [MenuCategory]] = [:]
    @Published var loadingStates: [String: Bool] = [:]
    @Published var errorMessages: [String: String] = [:]
    
    private let squareService = SquareAPIService.shared
    
    private init() {}
    
    func fetchMenuData(for shop: CoffeeShop) async {
        // Set loading state
        loadingStates[shop.id] = true
        errorMessages[shop.id] = nil
        
        do {
            let categories = try await squareService.fetchMenuData(for: shop)
            menuData[shop.id] = categories
            loadingStates[shop.id] = false
        } catch {
            errorMessages[shop.id] = error.localizedDescription
            loadingStates[shop.id] = false
            print("Error fetching menu data for \(shop.name): \(error)")
        }
    }
    
    func getMenuCategories(for shop: CoffeeShop) -> [MenuCategory] {
        return menuData[shop.id] ?? []
    }
    
    func isLoading(for shop: CoffeeShop) -> Bool {
        return loadingStates[shop.id] ?? false
    }
    
    func getErrorMessage(for shop: CoffeeShop) -> String? {
        return errorMessages[shop.id]
    }
    
    func clearError(for shop: CoffeeShop) {
        errorMessages[shop.id] = nil
    }
    
    func refreshMenuData(for shop: CoffeeShop) async {
        await fetchMenuData(for: shop)
    }
} 