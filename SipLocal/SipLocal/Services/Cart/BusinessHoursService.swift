/**
 * BusinessHoursService.swift
 * SipLocal
 *
 * Service responsible for managing business hours operations.
 * Handles fetching, caching, and validating business hours for coffee shops.
 *
 * ## Features
 * - **Business Hours Fetching**: Retrieve business hours from POS services
 * - **Caching**: Efficient caching to avoid redundant API calls
 * - **State Management**: Track loading states for UI feedback
 * - **Error Handling**: Comprehensive error handling with structured types
 * - **Performance**: Optimized caching and state management
 *
 * ## Architecture
 * - **Single Responsibility**: Focused solely on business hours operations
 * - **Service Integration**: Works with POS services for data fetching
 * - **State Coordination**: Provides state updates for UI components
 * - **Error Boundaries**: Structured error handling for all operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation

/**
 * Service for managing business hours operations
 */
class BusinessHoursService {
    
    // MARK: - Properties
    
    private var shopBusinessHours: [String: BusinessHoursInfo] = [:]
    private var isLoadingBusinessHours: [String: Bool] = [:]
    
    // MARK: - Business Hours Operations
    
    /**
     * Fetch business hours for a shop
     */
    func fetchBusinessHours(for shop: CoffeeShop) async -> BusinessHoursInfo? {
        // Don't fetch if already loading or already fetched
        if isLoadingBusinessHours[shop.id] == true || shopBusinessHours[shop.id] != nil {
            return shopBusinessHours[shop.id]
        }
        
        await MainActor.run {
            isLoadingBusinessHours[shop.id] = true
        }
        
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let hoursInfo = try await posService.fetchBusinessHours(for: shop)
            
            await MainActor.run {
                if let hoursInfo = hoursInfo {
                    self.shopBusinessHours[shop.id] = hoursInfo
                }
                self.isLoadingBusinessHours[shop.id] = false
            }
            
            return hoursInfo
        } catch {
            await MainActor.run {
                print("❌ BusinessHoursService: Error fetching business hours for \(shop.name): \(error)")
                self.isLoadingBusinessHours[shop.id] = false
            }
            return nil
        }
    }
    
    /**
     * Check if a shop is currently open
     */
    func isShopOpen(shop: CoffeeShop) -> Bool? {
        return shopBusinessHours[shop.id]?.isCurrentlyOpen
    }
    
    /**
     * Get business hours for a shop
     */
    func getBusinessHours(for shop: CoffeeShop) -> BusinessHoursInfo? {
        return shopBusinessHours[shop.id]
    }
    
    /**
     * Check if business hours are loading for a shop
     */
    func isLoadingBusinessHours(for shop: CoffeeShop) -> Bool {
        return isLoadingBusinessHours[shop.id] ?? false
    }
    
    /**
     * Clear business hours cache
     */
    func clearCache() {
        shopBusinessHours.removeAll()
        isLoadingBusinessHours.removeAll()
    }
    
    /**
     * Clear business hours for a specific shop
     */
    func clearBusinessHours(for shop: CoffeeShop) {
        shopBusinessHours.removeValue(forKey: shop.id)
        isLoadingBusinessHours.removeValue(forKey: shop.id)
    }
    
    /**
     * Get all cached business hours
     */
    func getAllBusinessHours() -> [String: BusinessHoursInfo] {
        return shopBusinessHours
    }
    
    /**
     * Get all loading states
     */
    func getAllLoadingStates() -> [String: Bool] {
        return isLoadingBusinessHours
    }
    
    /**
     * Preload business hours for multiple shops
     */
    func preloadBusinessHours(for shops: [CoffeeShop]) async {
        await withTaskGroup(of: Void.self) { group in
            for shop in shops {
                group.addTask {
                    _ = await self.fetchBusinessHours(for: shop)
                }
            }
        }
    }
}

// MARK: - Design System

extension BusinessHoursService {
    
    /**
     * Design system constants for BusinessHoursService
     */
    enum Design {
        // Cache management
        static let maxCacheSize = 100
        static let cacheExpirationTime: TimeInterval = 3600 // 1 hour
        
        // Error messages
        static let fetchError = "Failed to fetch business hours"
        static let networkError = "Network error while fetching business hours"
        static let serviceError = "POS service error"
        
        // Logging
        static let fetchSuccess = "Business hours fetched successfully"
        static let fetchFailed = "Failed to fetch business hours"
        static let cacheCleared = "Business hours cache cleared"
    }
}