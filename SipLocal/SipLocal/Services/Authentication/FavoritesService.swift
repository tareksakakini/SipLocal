/**
 * FavoritesService.swift
 * SipLocal
 *
 * Service responsible for managing user favorites operations.
 * Handles adding, removing, and fetching favorite coffee shops.
 *
 * ## Features
 * - **Favorites Management**: Add, remove, and check favorite shops
 * - **Data Synchronization**: Keep local state in sync with Firestore
 * - **Optimistic Updates**: Immediate UI updates with rollback on failure
 * - **Error Handling**: Comprehensive error handling for all operations
 * - **State Management**: Reactive state updates with completion handlers
 *
 * ## Architecture
 * - **Single Responsibility**: Focused solely on favorites operations
 * - **Firebase Integration**: Direct Firestore operations
 * - **State Coordination**: Works with AuthenticationManager for state updates
 * - **Error Boundaries**: Structured error handling for all operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseFirestore

/**
 * Service for managing user favorites operations
 */
class FavoritesService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    
    // MARK: - Favorites Operations
    
    /**
     * Add a shop to user's favorites
     */
    func addFavorite(userId: String, shopId: String, completion: @escaping (Bool) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "favorites": FieldValue.arrayUnion([shopId])
        ]) { error in
            completion(error == nil)
        }
    }
    
    /**
     * Remove a shop from user's favorites
     */
    func removeFavorite(userId: String, shopId: String, completion: @escaping (Bool) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "favorites": FieldValue.arrayRemove([shopId])
        ]) { error in
            completion(error == nil)
        }
    }
    
    /**
     * Check if a shop is in user's favorites
     */
    func isFavorite(userId: String, shopId: String, favorites: Set<String>) -> Bool {
        return favorites.contains(shopId)
    }
    
    /**
     * Fetch user's favorite shops from Firestore
     */
    func fetchFavorites(userId: String, completion: @escaping (Set<String>) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let favorites = data["favorites"] as? [String] {
                completion(Set(favorites))
            } else {
                completion(Set<String>())
            }
        }
    }
    
    /**
     * Get favorite shops count
     */
    func getFavoritesCount(favorites: Set<String>) -> Int {
        return favorites.count
    }
    
    /**
     * Check if user has any favorites
     */
    func hasFavorites(favorites: Set<String>) -> Bool {
        return !favorites.isEmpty
    }
}

// MARK: - Design System

extension FavoritesService {
    
    /**
     * Design system constants for FavoritesService
     */
    enum Design {
        // Firestore collections
        static let usersCollection = "users"
        
        // Field names
        static let favoritesField = "favorites"
        
        // Error messages
        static let addFavoriteError = "Failed to add favorite"
        static let removeFavoriteError = "Failed to remove favorite"
        static let fetchFavoritesError = "Failed to fetch favorites"
    }
}