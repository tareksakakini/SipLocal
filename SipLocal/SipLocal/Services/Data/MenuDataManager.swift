import Foundation
import SwiftUI

/**
 * MenuDataManager - Coordinates menu data fetching, caching, and state management operations.
 *
 * ## Responsibilities
 * - **Menu Data Coordination**: Coordinates between data fetching and caching services
 * - **State Management**: Manages loading states and error messages for UI
 * - **Data Access**: Provides clean API for accessing menu data
 * - **Background Operations**: Handles silent refreshes and background updates
 *
 * ## Architecture
 * - **Service Extraction Pattern**: Delegates to specialized services
 * - **Coordinator Pattern**: Acts as a coordinator for menu-related operations
 * - **Singleton Pattern**: Provides shared instance for app-wide access
 * - **MainActor Isolation**: Ensures UI updates happen on main thread
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
@MainActor
class MenuDataManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = MenuDataManager()
    
    // MARK: - Published Properties
    
    @Published var menuData: [String: [MenuCategory]] = [:]
    @Published var loadingStates: [String: Bool] = [:]
    @Published var errorMessages: [String: String] = [:]
    
    // MARK: - Private Services
    
    private let menuCachingService: MenuCachingService
    
    // MARK: - Initialization
    
    private init() {
        self.menuCachingService = MenuCachingService()
        print("📋 MenuDataManager initialized with service extraction pattern")
    }
    
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
        if let cached = await menuCachingService.loadMenuFromDisk(for: shop.id) {
            menuData[shop.id] = cached.categories
            loadingStates[shop.id] = false
            errorMessages[shop.id] = nil
            
            // If cache is stale, refresh in background
            if menuCachingService.isCacheStale(cached) {
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
            await menuCachingService.saveMenuToDisk(for: shop.id, categories: categories)
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
    
    // MARK: - Private Methods
    
    private func refreshSilently(for shop: CoffeeShop) async {
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let categories = try await posService.fetchMenuData(for: shop)
            await MainActor.run {
                self.menuData[shop.id] = categories
                self.loadingStates[shop.id] = false
                self.errorMessages[shop.id] = nil
            }
            await menuCachingService.saveMenuToDisk(for: shop.id, categories: categories)
        } catch {
            // Keep showing cached data; optionally log error
            print("Silent refresh failed for shop \(shop.id): \(error.localizedDescription)")
        }
    }
} 