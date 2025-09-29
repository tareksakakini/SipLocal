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
    private var lastFetchedDates: [String: Date] = [:]
    private var backgroundRefreshShops: Set<String> = []
    private let cache: BusinessHoursCache
    
    // MARK: - Initialization
    
    init(cache: BusinessHoursCache = BusinessHoursCache()) {
        self.cache = cache
        loadCachedBusinessHours()
    }
    
    // MARK: - Business Hours Operations
    
    /**
     * Fetch business hours for a shop
     * - Parameters:
     *   - shop: Coffee shop to fetch hours for
     *   - forceRefresh: Force a fresh fetch even if cache is valid
     *   - showLoadingState: Whether to surface loading state to the UI
     */
    func fetchBusinessHours(
        for shop: CoffeeShop,
        forceRefresh: Bool = false,
        showLoadingState: Bool = true
    ) async -> BusinessHoursInfo? {
        let (cachedInfo, lastFetched, currentlyLoading) = await MainActor.run { () -> (BusinessHoursInfo?, Date?, Bool) in
            let info = self.shopBusinessHours[shop.id]
            let lastFetchDate = self.lastFetchedDates[shop.id]
            let loading = self.isLoadingBusinessHours[shop.id] ?? false
            return (info, lastFetchDate, loading)
        }
        
        let now = Date()
        
        if !forceRefresh {
            if let cachedInfo {
                if let lastFetched, isCacheValid(lastFetched: lastFetched, now: now) {
                    if shouldRefreshInBackground(lastFetched: lastFetched, now: now) {
                        scheduleBackgroundRefresh(for: shop)
                    }
                    return cachedInfo
                }
                // Cache present but stale; hand back stale data and refresh silently
                scheduleBackgroundRefresh(for: shop)
                return cachedInfo
            }
            
            if currentlyLoading {
                return cachedInfo
            }
        } else if currentlyLoading {
            return cachedInfo
        }
        
        if showLoadingState {
            await MainActor.run {
                self.isLoadingBusinessHours[shop.id] = true
            }
        }
        
        do {
            let posService = POSServiceFactory.createService(for: shop)
            let hoursInfo = try await posService.fetchBusinessHours(for: shop)
            let fetchTimestamp = Date()
            
            await MainActor.run {
                if let hoursInfo {
                    self.shopBusinessHours[shop.id] = hoursInfo
                    self.lastFetchedDates[shop.id] = fetchTimestamp
                }
                if showLoadingState {
                    self.isLoadingBusinessHours[shop.id] = false
                }
            }
            
            if hoursInfo != nil {
                Task { await self.persistCache() }
                return hoursInfo
            } else {
                return cachedInfo
            }
        } catch {
            await MainActor.run {
                if showLoadingState {
                    self.isLoadingBusinessHours[shop.id] = false
                }
                print("❌ BusinessHoursService: Error fetching business hours for \(shop.name): \(error)")
            }
            return cachedInfo
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
        lastFetchedDates.removeAll()
        backgroundRefreshShops.removeAll()
        Task { await self.cache.clear() }
    }
    
    /**
     * Clear business hours for a specific shop
     */
    func clearBusinessHours(for shop: CoffeeShop) {
        shopBusinessHours.removeValue(forKey: shop.id)
        isLoadingBusinessHours.removeValue(forKey: shop.id)
        lastFetchedDates.removeValue(forKey: shop.id)
        Task { await self.persistCache() }
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
                    _ = await self.fetchBusinessHours(for: shop, showLoadingState: false)
                }
            }
        }
    }
}

// MARK: - Private Helpers

private extension BusinessHoursService {
    func loadCachedBusinessHours() {
        Task { [weak self] in
            guard let self else { return }
            let cachedEntries = await self.cache.load()
            await MainActor.run {
                for (shopId, entry) in cachedEntries {
                    self.shopBusinessHours[shopId] = entry.info
                    self.lastFetchedDates[shopId] = entry.lastUpdated
                }
            }
        }
    }
    
    func isCacheValid(lastFetched: Date, now: Date) -> Bool {
        return now.timeIntervalSince(lastFetched) < Design.cacheExpirationTime
    }
    
    func shouldRefreshInBackground(lastFetched: Date, now: Date) -> Bool {
        return now.timeIntervalSince(lastFetched) >= Design.cacheBackgroundRefreshInterval
    }
    
    func scheduleBackgroundRefresh(for shop: CoffeeShop) {
        Task { [weak self] in
            guard let self else { return }
            let shouldRefresh = await MainActor.run { () -> Bool in
                if self.backgroundRefreshShops.contains(shop.id) || (self.isLoadingBusinessHours[shop.id] ?? false) {
                    return false
                }
                self.backgroundRefreshShops.insert(shop.id)
                return true
            }
            guard shouldRefresh else { return }
            _ = await self.fetchBusinessHours(for: shop, forceRefresh: true, showLoadingState: false)
            await MainActor.run {
                self.backgroundRefreshShops.remove(shop.id)
            }
        }
    }
    
    func persistCache() async {
        let entries = await MainActor.run { () -> [String: BusinessHoursCache.CacheEntry] in
            var pairs: [(String, BusinessHoursCache.CacheEntry)] = []
            for (shopId, info) in self.shopBusinessHours {
                guard let lastFetched = self.lastFetchedDates[shopId] else { continue }
                let entry = BusinessHoursCache.CacheEntry(info: info, lastUpdated: lastFetched)
                pairs.append((shopId, entry))
            }
            pairs.sort { $0.1.lastUpdated > $1.1.lastUpdated }
            if pairs.count > Design.maxCacheSize {
                pairs = Array(pairs.prefix(Design.maxCacheSize))
            }
            return Dictionary(uniqueKeysWithValues: pairs)
        }
        await cache.save(entries)
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
        static let cacheExpirationTime: TimeInterval = 86_400 // 24 hours
        static let cacheBackgroundRefreshInterval: TimeInterval = 21_600 // 6 hours
        
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
