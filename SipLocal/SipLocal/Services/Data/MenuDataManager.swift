import Foundation
import SwiftUI

@MainActor
class MenuDataManager: ObservableObject {
    static let shared = MenuDataManager()
    
    @Published var menuData: [String: [MenuCategory]] = [:]
    @Published var loadingStates: [String: Bool] = [:]
    @Published var errorMessages: [String: String] = [:]
    
    // Remove direct service dependency - will use POSServiceFactory instead
    private let fileManager = FileManager.default
    private let cacheTTLSeconds: TimeInterval = 60 * 30 // 30 minutes
    
    private init() {}
    
    // MARK: - Public API
    
    /// Loads cached menu immediately if available, then refreshes from the network in the background.
    func primeMenu(for shop: CoffeeShop) async {
        // 1) If we already have data in memory, use it and optionally refresh in background
        if let existing = menuData[shop.id], !existing.isEmpty {
            // Kick off a silent refresh in the background
            Task.detached { [weak self] in
                guard let self else { return }
                await self.refreshSilently(for: shop)
            }
            return
        }
        
        // 2) Try disk cache first for instant UI
        if let cached = await loadMenuFromDisk(for: shop.id) {
            menuData[shop.id] = cached.categories
            loadingStates[shop.id] = false
            errorMessages[shop.id] = nil
            
            // If cache is stale, refresh in background
            if Date().timeIntervalSince1970 - cached.timestamp > cacheTTLSeconds {
                Task.detached { [weak self] in
                    guard let self else { return }
                    await self.refreshSilently(for: shop)
                }
            }
            return
        }
        
        // 3) Fallback to normal fetch if nothing cached
        await fetchMenuData(for: shop)
    }
    
    func fetchMenuData(for shop: CoffeeShop) async {
        // Set loading state
        loadingStates[shop.id] = true
        errorMessages[shop.id] = nil
        
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let categories = try await posService.fetchMenuData(for: shop)
            menuData[shop.id] = categories
            loadingStates[shop.id] = false
            // Save to disk cache
            await saveMenuToDisk(for: shop.id, categories: categories)
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
    
    // MARK: - Private helpers (caching)
    
    private func refreshSilently(for shop: CoffeeShop) async {
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let categories = try await posService.fetchMenuData(for: shop)
            await MainActor.run {
                self.menuData[shop.id] = categories
                self.loadingStates[shop.id] = false
                self.errorMessages[shop.id] = nil
            }
            await saveMenuToDisk(for: shop.id, categories: categories)
        } catch {
            // Keep showing cached data; optionally log error
            print("Silent refresh failed for shop \(shop.id): \(error.localizedDescription)")
        }
    }
    
    private struct CachedMenu: Codable {
        let categories: [MenuCategory]
        let timestamp: TimeInterval
    }
    
    private func cacheFileURL(for shopId: String) -> URL? {
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return cachesDir.appendingPathComponent("menu_cache_\(shopId).json")
    }
    
    private func saveMenuToDisk(for shopId: String, categories: [MenuCategory]) async {
        guard let url = cacheFileURL(for: shopId) else { return }
        let cached = CachedMenu(categories: categories, timestamp: Date().timeIntervalSince1970)
        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: url, options: .atomic)
        } catch {
            print("Failed to write menu cache for shop \(shopId): \(error)")
        }
    }
    
    private func loadMenuFromDisk(for shopId: String) async -> CachedMenu? {
        guard let url = cacheFileURL(for: shopId) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let cached = try JSONDecoder().decode(CachedMenu.self, from: data)
            return cached
        } catch {
            return nil
        }
    }
} 