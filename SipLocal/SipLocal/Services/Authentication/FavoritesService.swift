/**
 * FavoritesService.swift
 * SipLocal
 *
 * Service responsible for user favorites management.
 * Extracted from AuthenticationManager to follow Single Responsibility Principle.
 *
 * ## Responsibilities
 * - **Favorites CRUD**: Add, remove, fetch user favorite coffee shops
 * - **Real-time Updates**: Maintain synchronized favorites state
 * - **Optimistic Updates**: Provide immediate UI feedback with rollback
 * - **Performance**: Efficient Firestore operations with caching
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on favorites management
 * - **Reactive State**: Observable favorites with real-time updates
 * - **Error Boundaries**: Comprehensive error handling with recovery
 * - **Optimistic UI**: Immediate updates with failure rollback
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseFirestore
import Combine

// MARK: - FavoritesService

/**
 * Service for managing user favorites operations
 * 
 * Handles all favorites-related operations with optimistic updates and error handling.
 * Provides reactive state management for real-time UI updates.
 */
class FavoritesService: ObservableObject {
    
    // MARK: - Published State
    @Published var favoriteShops: Set<String> = []
    
    // MARK: - Dependencies
    private let firestore: Firestore
    private let userId: String?
    
    // MARK: - Configuration
    private enum Configuration {
        static let collectionName = "users"
        static let favoritesField = "favoriteShops"
        static let operationTimeout: TimeInterval = 10.0
        static let maxFavorites = 50
        static let batchSize = 10
    }
    
    // MARK: - Private State
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(firestore: Firestore = Firestore.firestore(), userId: String?) {
        self.firestore = firestore
        self.userId = userId
        
        if let userId = userId {
            setupRealTimeListener(for: userId)
        }
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /**
     * Add a shop to favorites with optimistic update
     */
    func addFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            print("FavoritesService: No user ID available ❌")
            completion(false)
            return
        }
        
        // Check favorites limit
        guard favoriteShops.count < Configuration.maxFavorites else {
            print("FavoritesService: Favorites limit reached ❌")
            completion(false)
            return
        }
        
        // Optimistic UI update
        let wasAlreadyFavorite = favoriteShops.contains(shopId)
        if !wasAlreadyFavorite {
            favoriteShops.insert(shopId)
        }
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.favoritesField: FieldValue.arrayUnion([shopId])
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                if !wasAlreadyFavorite {
                    DispatchQueue.main.async {
                        self?.favoriteShops.remove(shopId)
                    }
                }
                print("FavoritesService: Add favorite failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                print("FavoritesService: Add favorite successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Remove a shop from favorites with optimistic update
     */
    func removeFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            print("FavoritesService: No user ID available ❌")
            completion(false)
            return
        }
        
        // Optimistic UI update
        let wasCurrentlyFavorite = favoriteShops.contains(shopId)
        if wasCurrentlyFavorite {
            favoriteShops.remove(shopId)
        }
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.favoritesField: FieldValue.arrayRemove([shopId])
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                if wasCurrentlyFavorite {
                    DispatchQueue.main.async {
                        self?.favoriteShops.insert(shopId)
                    }
                }
                print("FavoritesService: Remove favorite failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                print("FavoritesService: Remove favorite successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Toggle favorite status for a shop
     */
    func toggleFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        if favoriteShops.contains(shopId) {
            removeFavorite(shopId: shopId, completion: completion)
        } else {
            addFavorite(shopId: shopId, completion: completion)
        }
    }
    
    /**
     * Check if a shop is in favorites
     */
    func isFavorite(shopId: String) -> Bool {
        return favoriteShops.contains(shopId)
    }
    
    /**
     * Get all favorite shop IDs
     */
    func getAllFavorites() -> Set<String> {
        return favoriteShops
    }
    
    /**
     * Get favorites count
     */
    var favoritesCount: Int {
        return favoriteShops.count
    }
    
    /**
     * Clear all favorites
     */
    func clearAllFavorites(completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        let previousFavorites = favoriteShops
        favoriteShops.removeAll()
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.favoritesField: []
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                DispatchQueue.main.async {
                    self?.favoriteShops = previousFavorites
                }
                print("FavoritesService: Clear favorites failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                print("FavoritesService: Clear favorites successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Fetch favorites from server (manual refresh)
     */
    func fetchFavorites(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("FavoritesService: Fetch favorites failed ❌ - \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data(),
                      let favorites = data[Configuration.favoritesField] as? [String] else {
                    print("FavoritesService: No favorites data found")
                    self?.favoriteShops = []
                    completion(true)
                    return
                }
                
                self?.favoriteShops = Set(favorites)
                print("FavoritesService: Fetch favorites successful ✅ - \(favorites.count) favorites")
                completion(true)
            }
        }
    }
    
    /**
     * Update user ID and setup listener
     */
    func updateUserId(_ newUserId: String?) {
        // Remove existing listener
        listener?.remove()
        listener = nil
        
        if let newUserId = newUserId {
            setupRealTimeListener(for: newUserId)
        } else {
            favoriteShops.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRealTimeListener(for userId: String) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        listener = userDocument.addSnapshotListener { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("FavoritesService: Real-time listener error ❌ - \(error.localizedDescription)")
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("FavoritesService: User document not found")
                    self?.favoriteShops = []
                    return
                }
                
                if let favorites = data[Configuration.favoritesField] as? [String] {
                    let newFavorites = Set(favorites)
                    if self?.favoriteShops != newFavorites {
                        self?.favoriteShops = newFavorites
                        print("FavoritesService: Real-time update ✅ - \(favorites.count) favorites")
                    }
                }
            }
        }
    }
}

// MARK: - Async/Await Interface

extension FavoritesService {
    
    /**
     * Add favorite using async/await
     */
    func addFavorite(shopId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            addFavorite(shopId: shopId) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FavoritesError.addFailed(shopId))
                }
            }
        }
    }
    
    /**
     * Remove favorite using async/await
     */
    func removeFavorite(shopId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            removeFavorite(shopId: shopId) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FavoritesError.removeFailed(shopId))
                }
            }
        }
    }
    
    /**
     * Fetch favorites using async/await
     */
    func fetchFavorites() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fetchFavorites { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: FavoritesError.fetchFailed)
                }
            }
        }
    }
}

// MARK: - FavoritesError

/**
 * Structured error types for favorites operations
 */
enum FavoritesError: LocalizedError {
    case addFailed(String)
    case removeFailed(String)
    case fetchFailed
    case limitReached(Int)
    case userNotAuthenticated
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .addFailed(let shopId):
            return "Failed to add shop \(shopId) to favorites"
        case .removeFailed(let shopId):
            return "Failed to remove shop \(shopId) from favorites"
        case .fetchFailed:
            return "Failed to fetch favorites"
        case .limitReached(let limit):
            return "Favorites limit reached (\(limit) maximum)"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .addFailed, .removeFailed, .fetchFailed:
            return "Please check your network connection and try again."
        case .limitReached:
            return "Please remove some favorites before adding new ones."
        case .userNotAuthenticated:
            return "Please sign in to manage favorites."
        case .networkUnavailable:
            return "Please check your internet connection."
        }
    }
}

// MARK: - Analytics Extensions

extension FavoritesService {
    
    /**
     * Track favorites operations for analytics
     */
    func trackFavoritesOperation(_ operation: String, shopId: String, success: Bool) {
        // In a real app, this would send analytics data
        let status = success ? "✅" : "❌"
        print("📊 FavoritesService: \(operation) for shop \(shopId) \(status)")
    }
    
    /**
     * Get favorites analytics data
     */
    var analyticsData: [String: Any] {
        return [
            "total_favorites": favoritesCount,
            "favorites_percentage": favoritesCount > 0 ? Double(favoritesCount) / 100.0 : 0.0,
            "last_updated": Date().timeIntervalSince1970
        ]
    }
}

// MARK: - Utility Extensions

extension FavoritesService {
    
    /**
     * Export favorites as array for sharing/backup
     */
    func exportFavorites() -> [String] {
        return Array(favoriteShops).sorted()
    }
    
    /**
     * Import favorites from array
     */
    func importFavorites(_ favorites: [String], completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        // Validate favorites count
        let validFavorites = Array(favorites.prefix(Configuration.maxFavorites))
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.favoritesField: validFavorites
        ]) { [weak self] error in
            if let error = error {
                print("FavoritesService: Import favorites failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self?.favoriteShops = Set(validFavorites)
                }
                print("FavoritesService: Import favorites successful ✅")
                completion(true)
            }
        }
    }
}
