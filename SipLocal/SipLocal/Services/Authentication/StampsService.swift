/**
 * StampsService.swift
 * SipLocal
 *
 * Service responsible for managing user stamps operations.
 * Handles adding, removing, and fetching stamped coffee shops.
 *
 * ## Features
 * - **Stamps Management**: Add, remove, and check stamped shops
 * - **Data Synchronization**: Keep local state in sync with Firestore
 * - **Optimistic Updates**: Immediate UI updates with rollback on failure
 * - **Error Handling**: Comprehensive error handling for all operations
 * - **State Management**: Reactive state updates with completion handlers
 *
 * ## Architecture
 * - **Single Responsibility**: Focused solely on stamps operations
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
 * Service for managing user stamps operations
 */
class StampsService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    
    // MARK: - Stamps Operations
    
    /**
     * Add a stamp to a shop
     */
    func addStamp(userId: String, shopId: String, completion: @escaping (Bool) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "stampedShops": FieldValue.arrayUnion([shopId])
        ]) { error in
            if let error = error {
                print("StampsService: Error adding stamp: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    /**
     * Remove a stamp from a shop
     */
    func removeStamp(userId: String, shopId: String, completion: @escaping (Bool) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "stampedShops": FieldValue.arrayRemove([shopId])
        ]) { error in
            if let error = error {
                print("StampsService: Error removing stamp: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    /**
     * Check if a shop is stamped
     */
    func isStamped(userId: String, shopId: String, stampedShops: Set<String>) -> Bool {
        return stampedShops.contains(shopId)
    }
    
    /**
     * Fetch user's stamped shops from Firestore
     */
    func fetchStampedShops(userId: String, completion: @escaping (Set<String>) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        userDocument.getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let stamps = data["stampedShops"] as? [String] {
                completion(Set(stamps))
            } else {
                completion(Set<String>())
            }
        }
    }
    
    /**
     * Get stamped shops count
     */
    func getStampsCount(stampedShops: Set<String>) -> Int {
        return stampedShops.count
    }
    
    /**
     * Check if user has any stamps
     */
    func hasStamps(stampedShops: Set<String>) -> Bool {
        return !stampedShops.isEmpty
    }
    
    /**
     * Get stamp progress for a shop (if implementing stamp collection system)
     */
    func getStampProgress(userId: String, shopId: String, completion: @escaping (Int) -> Void) {
        // This could be extended to track stamp progress per shop
        // For now, just return 1 if stamped, 0 if not
        let userDocument = firestore.collection("users").document(userId)
        userDocument.getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let stamps = data["stampedShops"] as? [String] {
                completion(stamps.contains(shopId) ? 1 : 0)
            } else {
                completion(0)
            }
        }
    }
}

// MARK: - Design System

extension StampsService {
    
    /**
     * Design system constants for StampsService
     */
    enum Design {
        // Firestore collections
        static let usersCollection = "users"
        
        // Field names
        static let stampedShopsField = "stampedShops"
        
        // Error messages
        static let addStampError = "Failed to add stamp"
        static let removeStampError = "Failed to remove stamp"
        static let fetchStampsError = "Failed to fetch stamps"
        
        // Stamp system
        static let maxStampsPerShop = 10 // Could be configurable
        static let stampProgressField = "stampProgress"
    }
}