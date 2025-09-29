/**
 * UserDataService.swift
 * SipLocal
 *
 * Service responsible for user data management operations.
 * Handles CRUD operations for user profile data in Firestore.
 *
 * ## Features
 * - **User Data CRUD**: Create, read, update, delete user profile data
 * - **Profile Image Management**: Upload, remove, and manage profile images
 * - **Username Validation**: Check username availability
 * - **Data Validation**: Ensure data integrity and proper formatting
 * - **Error Handling**: Comprehensive error handling with structured types
 *
 * ## Architecture
 * - **Single Responsibility**: Focused solely on user data operations
 * - **Firebase Integration**: Direct Firestore and Storage operations
 * - **Async/Await Support**: Modern Swift concurrency patterns
 * - **Error Boundaries**: Structured error handling for all operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseFirestore
import FirebaseStorage
import UIKit

/**
 * Service for managing user data operations
 */
class UserDataService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    
    // MARK: - User Data Operations
    
    /**
     * Save user data to Firestore
     */
    func saveUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        
        let userDataDict: [String: Any] = [
            "fullName": userData.fullName,
            "username": userData.username,
            "email": userData.email,
            "createdAt": Timestamp(date: Date()),
            "isActive": true
        ]
        
        userDocument.setData(userDataDict) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
    
    /**
     * Get user data from Firestore
     */
    func getUserData(userId: String, completion: @escaping (UserData?, String?) -> Void) {
        print("UserDataService: Getting user data for \(userId)")
        
        firestore.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("UserDataService: Get user failed ❌ - \(error.localizedDescription)")
                completion(nil, error.localizedDescription)
                return
            }
            
            guard let document = document,
                  document.exists,
                  let data = document.data(),
                  let fullName = data["fullName"] as? String,
                  let username = data["username"] as? String,
                  let email = data["email"] as? String else {
                print("UserDataService: User data missing ❌")
                completion(nil, "User data not found")
                return
            }
            
            let profileImageUrl = data["profileImageUrl"] as? String
            print("UserDataService: Retrieved profile image URL: \(profileImageUrl ?? "nil")")
            
            let userData = UserData(
                fullName: fullName,
                username: username,
                email: email,
                profileImageUrl: profileImageUrl
            )
            
            print("UserDataService: User data loaded ✅")
            completion(userData, nil)
        }
    }
    
    /**
     * Update user data in Firestore
     */
    func updateUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection("users").document(userId)
        
        let updateData: [String: Any] = [
            "fullName": userData.fullName,
            "username": userData.username,
            "email": userData.email,
            "updatedAt": Timestamp(date: Date())
        ]
        
        userDocument.updateData(updateData) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
    
    /**
     * Delete user data from Firestore
     */
    func deleteUserData(userId: String, completion: @escaping (Bool, String?) -> Void) {
        firestore.collection("users").document(userId).delete { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
    
    /**
     * Check if username is available
     */
    func checkUsernameAvailability(username: String, completion: @escaping (Bool) -> Void) {
        firestore.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("UserDataService: Error checking username availability: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // If no documents found, username is available
                completion(snapshot?.documents.isEmpty ?? false)
            }
    }
    
    // MARK: - Profile Image Management
    
    /**
     * Upload profile image to Firebase Storage
     */
    func uploadProfileImage(userId: String, image: UIImage) async -> (success: Bool, errorMessage: String?) {
        print("UserDataService: Uploading image for user \(userId)...")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("UserDataService: Image processing failed")
            return (false, "Failed to process image")
        }
        
        let storageRef = storage.reference().child("profile_pictures/\(userId).jpg")
        
        do {
            let _ = try await storageRef.putDataAsync(imageData)
            let downloadURL = try await storageRef.downloadURL()
            
            // Update user document with profile image URL
            let userDocument = firestore.collection("users").document(userId)
            try await userDocument.updateData(["profileImageUrl": downloadURL.absoluteString])
            
            print("UserDataService: Image upload ✅")
            return (true, nil)
        } catch {
            print("UserDataService: Image upload ❌ - \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }
    
    /**
     * Remove profile image from Firebase Storage
     */
    func removeProfileImage(userId: String) async -> (success: Bool, errorMessage: String?) {
        let storageRef = storage.reference().child("profile_pictures/\(userId).jpg")
        
        do {
            // Delete from storage
            try await storageRef.delete()
            
            // Remove URL from user document
            let userDocument = firestore.collection("users").document(userId)
            try await userDocument.updateData(["profileImageUrl": FieldValue.delete()])
            
            return (true, nil)
        } catch {
            return (false, error.localizedDescription)
        }
    }
}

// MARK: - Design System

extension UserDataService {
    
    /**
     * Design system constants for UserDataService
     */
    enum Design {
        // Image compression
        static let imageCompressionQuality: CGFloat = 0.8
        
        // Storage paths
        static let profileImagePath = "profile_pictures"
        static let profileImageExtension = "jpg"
        
        // Firestore collections
        static let usersCollection = "users"
        
        // Field names
        static let fullNameField = "fullName"
        static let usernameField = "username"
        static let emailField = "email"
        static let profileImageUrlField = "profileImageUrl"
        static let createdAtField = "createdAt"
        static let updatedAtField = "updatedAt"
        static let isActiveField = "isActive"
    }
}