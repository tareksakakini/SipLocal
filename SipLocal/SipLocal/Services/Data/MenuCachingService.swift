import Foundation

/**
 * MenuCachingService - Handles menu data caching operations to disk.
 *
 * ## Responsibilities
 * - **Disk Caching**: Saves and loads menu data to/from disk cache
 * - **Cache Management**: Manages cache TTL and stale data detection
 * - **File Operations**: Handles file system operations for cache storage
 * - **Data Serialization**: Handles JSON encoding/decoding of cached data
 *
 * ## Architecture
 * - **Service Layer Pattern**: Encapsulates caching logic
 * - **File System Integration**: Uses FileManager for disk operations
 * - **JSON Serialization**: Uses Codable for data persistence
 * - **Cache TTL**: Implements time-based cache expiration
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class MenuCachingService {
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let cacheTTLSeconds: TimeInterval = 60 * 30 // 30 minutes
    
    // MARK: - Design System
    
    enum Design {
        static let cacheFileNamePrefix = "menu_cache_"
        static let cacheFileExtension = "json"
        
        // Error Messages
        static let cacheWriteError = "Failed to write menu cache"
        static let cacheReadError = "Failed to read menu cache"
        static let cacheDirectoryError = "Failed to access cache directory"
        
        // Logging Messages
        static let cacheSaved = "Menu cache saved for shop"
        static let cacheLoaded = "Menu cache loaded for shop"
        static let cacheExpired = "Menu cache expired for shop"
        static let cacheNotFound = "Menu cache not found for shop"
    }
    
    // MARK: - Public Methods
    
    /**
     * Save menu data to disk cache
     */
    func saveMenuToDisk(for shopId: String, categories: [MenuCategory]) async {
        guard let url = cacheFileURL(for: shopId) else {
            logError("\(Design.cacheDirectoryError): \(shopId)")
            return
        }
        
        let cached = CachedMenu(categories: categories, timestamp: Date().timeIntervalSince1970)
        
        do {
            let data = try JSONEncoder().encode(cached)
            try data.write(to: url, options: .atomic)
            logInfo("\(Design.cacheSaved): \(shopId) - \(categories.count) categories")
        } catch {
            logError("\(Design.cacheWriteError): \(shopId) - \(error.localizedDescription)")
        }
    }
    
    /**
     * Load menu data from disk cache
     */
    func loadMenuFromDisk(for shopId: String) async -> CachedMenu? {
        guard let url = cacheFileURL(for: shopId) else {
            logError("\(Design.cacheDirectoryError): \(shopId)")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            let cached = try JSONDecoder().decode(CachedMenu.self, from: data)
            logInfo("\(Design.cacheLoaded): \(shopId) - \(cached.categories.count) categories")
            return cached
        } catch {
            logInfo("\(Design.cacheNotFound): \(shopId)")
            return nil
        }
    }
    
    /**
     * Check if cached data is stale
     */
    func isCacheStale(_ cached: CachedMenu) -> Bool {
        let isStale = Date().timeIntervalSince1970 - cached.timestamp > cacheTTLSeconds
        if isStale {
            logInfo("\(Design.cacheExpired): timestamp \(cached.timestamp)")
        }
        return isStale
    }
    
    /**
     * Clear cache for a specific shop
     */
    func clearCache(for shopId: String) async {
        guard let url = cacheFileURL(for: shopId) else { return }
        
        do {
            try fileManager.removeItem(at: url)
            logInfo("Cache cleared for shop: \(shopId)")
        } catch {
            logError("Failed to clear cache for shop \(shopId): \(error.localizedDescription)")
        }
    }
    
    /**
     * Clear all menu caches
     */
    func clearAllCaches() async {
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        
        do {
            let cacheFiles = try fileManager.contentsOfDirectory(at: cachesDir, includingPropertiesForKeys: nil)
            let menuCacheFiles = cacheFiles.filter { $0.lastPathComponent.hasPrefix(Design.cacheFileNamePrefix) }
            
            for file in menuCacheFiles {
                try fileManager.removeItem(at: file)
            }
            
            logInfo("Cleared \(menuCacheFiles.count) menu cache files")
        } catch {
            logError("Failed to clear all caches: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Get cache file URL for a specific shop
     */
    private func cacheFileURL(for shopId: String) -> URL? {
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return nil
        }
        return cachesDir.appendingPathComponent("\(Design.cacheFileNamePrefix)\(shopId).\(Design.cacheFileExtension)")
    }
    
    // MARK: - Logging
    
    private func logInfo(_ message: String) {
        print("💾 [MenuCachingService] \(message)")
    }
    
    private func logError(_ message: String) {
        print("❌ [MenuCachingService] \(message)")
    }
}

// MARK: - Cached Menu Model

struct CachedMenu: Codable {
    let categories: [MenuCategory]
    let timestamp: TimeInterval
    
    init(categories: [MenuCategory], timestamp: TimeInterval) {
        self.categories = categories
        self.timestamp = timestamp
    }
}
