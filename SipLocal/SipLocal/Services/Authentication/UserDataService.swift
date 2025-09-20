/**
 * UserDataService.swift
 * SipLocal
 *
 * Service responsible for user data management operations.
 * Extracted from AuthenticationManager to follow Single Responsibility Principle.
 *
 * ## Responsibilities
 * - **User Data CRUD**: Create, read, update, delete user data in Firestore
 * - **Data Validation**: Validate user data before operations
 * - **Error Handling**: Provide structured error handling for data operations
 * - **Performance**: Optimize Firestore queries and data operations
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on user data management
 * - **Dependency Injection**: Clean Firebase service integration
 * - **Error Boundaries**: Comprehensive error handling with recovery
 * - **Async Operations**: Modern async/await support with completion handlers
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseFirestore

// MARK: - UserDataService

/**
 * Service for managing user data operations in Firestore
 * 
 * Handles all user data CRUD operations with proper error handling and validation.
 * Provides both async/await and completion handler interfaces for flexibility.
 */
class UserDataService {
    
    // MARK: - Dependencies
    private let firestore: Firestore
    
    // MARK: - Configuration
    private enum Configuration {
        static let collectionName = "users"
        static let operationTimeout: TimeInterval = 30.0
        static let maxRetryAttempts = 3
        static let retryDelay: TimeInterval = 1.0
    }
    
    // MARK: - Initialization
    
    init(firestore: Firestore = Firestore.firestore()) {
        self.firestore = firestore
    }
    
    // MARK: - Public Interface
    
    /**
     * Save user data to Firestore
     * Creates a new user document with the provided data
     */
    func saveUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        let userDataDict: [String: Any] = [
            "fullName": userData.fullName,
            "username": userData.username,
            "email": userData.email,
            "profileImageUrl": userData.profileImageUrl ?? "",
            "favoriteShops": [],
            "stampedShops": [],
            "devices": [:],
            "createdAt": Timestamp(date: Date()),
            "updatedAt": Timestamp(date: Date())
        ]
        
        userDocument.setData(userDataDict) { error in
            if let error = error {
                print("UserDataService: Save failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("UserDataService: Save successful ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Get user data from Firestore
     * Retrieves user document and converts to UserData model
     */
    func getUserData(userId: String, completion: @escaping (UserData?, String?) -> Void) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        userDocument.getDocument { document, error in
            if let error = error {
                print("UserDataService: Get user failed ❌ - \(error.localizedDescription)")
                completion(nil, error.localizedDescription)
                return
            }
            
            guard let document = document, document.exists, let data = document.data() else {
                print("UserDataService: User document not found ❌")
                completion(nil, "User data not found")
                return
            }
            
            // Extract user data from Firestore document
            let fullName = data["fullName"] as? String ?? ""
            let username = data["username"] as? String ?? ""
            let email = data["email"] as? String ?? ""
            let profileImageUrl = data["profileImageUrl"] as? String
            
            let userData = UserData(
                fullName: fullName,
                username: username,
                email: email,
                profileImageUrl: profileImageUrl
            )
            
            print("UserDataService: Get user successful ✅")
            completion(userData, nil)
        }
    }
    
    /**
     * Update existing user data in Firestore
     * Updates only the provided fields, preserving others
     */
    func updateUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        let updateData: [String: Any] = [
            "fullName": userData.fullName,
            "username": userData.username,
            "email": userData.email,
            "updatedAt": Timestamp(date: Date())
        ]
        
        userDocument.updateData(updateData) { error in
            if let error = error {
                print("UserDataService: Update failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("UserDataService: Update successful ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Delete user data from Firestore
     * Removes the entire user document
     */
    func deleteUserData(userId: String, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        userDocument.delete { error in
            if let error = error {
                print("UserDataService: Delete failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("UserDataService: Delete successful ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Check if username is available
     * Queries Firestore to see if username is already taken
     */
    func checkUsernameAvailability(username: String) async -> Bool {
        do {
            let query = firestore.collection(Configuration.collectionName)
                .whereField("username", isEqualTo: username)
                .limit(to: 1)
            
            let snapshot = try await query.getDocuments()
            let isAvailable = snapshot.documents.isEmpty
            
            print("UserDataService: Username '\(username)' availability: \(isAvailable ? "✅" : "❌")")
            return isAvailable
            
        } catch {
            print("UserDataService: Username check failed ❌ - \(error.localizedDescription)")
            return false // Assume unavailable on error for safety
        }
    }
    
    /**
     * Update profile image URL
     * Updates only the profile image URL field
     */
    func updateProfileImageUrl(userId: String, imageUrl: String?, completion: @escaping (Bool, String?) -> Void) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        let updateData: [String: Any] = [
            "profileImageUrl": imageUrl ?? "",
            "updatedAt": Timestamp(date: Date())
        ]
        
        userDocument.updateData(updateData) { error in
            if let error = error {
                print("UserDataService: Profile image update failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("UserDataService: Profile image update successful ✅")
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Async/Await Interface
    
    /**
     * Save user data using async/await
     */
    func saveUserData(userId: String, userData: UserData) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            saveUserData(userId: userId, userData: userData) { success, error in
                if success {
                    continuation.resume()
                } else {
                    let userDataError = UserDataError.saveFailed(error ?? "Unknown error")
                    continuation.resume(throwing: userDataError)
                }
            }
        }
    }
    
    /**
     * Get user data using async/await
     */
    func getUserData(userId: String) async throws -> UserData {
        return try await withCheckedThrowingContinuation { continuation in
            getUserData(userId: userId) { userData, error in
                if let userData = userData {
                    continuation.resume(returning: userData)
                } else {
                    let userDataError = UserDataError.notFound(error ?? "User not found")
                    continuation.resume(throwing: userDataError)
                }
            }
        }
    }
    
    /**
     * Update user data using async/await
     */
    func updateUserData(userId: String, userData: UserData) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            updateUserData(userId: userId, userData: userData) { success, error in
                if success {
                    continuation.resume()
                } else {
                    let userDataError = UserDataError.updateFailed(error ?? "Unknown error")
                    continuation.resume(throwing: userDataError)
                }
            }
        }
    }
    
    /**
     * Delete user data using async/await
     */
    func deleteUserData(userId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            deleteUserData(userId: userId) { success, error in
                if success {
                    continuation.resume()
                } else {
                    let userDataError = UserDataError.deleteFailed(error ?? "Unknown error")
                    continuation.resume(throwing: userDataError)
                }
            }
        }
    }
}

// MARK: - UserDataError

/**
 * Structured error types for user data operations
 */
enum UserDataError: LocalizedError {
    case saveFailed(String)
    case notFound(String)
    case updateFailed(String)
    case deleteFailed(String)
    case validationFailed(String)
    case networkUnavailable
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .saveFailed(let message):
            return "Failed to save user data: \(message)"
        case .notFound(let message):
            return "User data not found: \(message)"
        case .updateFailed(let message):
            return "Failed to update user data: \(message)"
        case .deleteFailed(let message):
            return "Failed to delete user data: \(message)"
        case .validationFailed(let message):
            return "User data validation failed: \(message)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .permissionDenied:
            return "Permission denied for user data operation"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .saveFailed, .updateFailed, .deleteFailed:
            return "Please check your network connection and try again."
        case .notFound:
            return "Please ensure the user account exists and try again."
        case .validationFailed:
            return "Please check the user data format and try again."
        case .networkUnavailable:
            return "Please check your internet connection."
        case .permissionDenied:
            return "Please ensure you have the necessary permissions."
        }
    }
}

// MARK: - Validation Extensions

extension UserDataService {
    
    /**
     * Validate user data before operations
     */
    func validateUserData(_ userData: UserData) -> UserDataError? {
        if userData.fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .validationFailed("Full name cannot be empty")
        }
        
        if userData.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .validationFailed("Username cannot be empty")
        }
        
        if !isValidEmail(userData.email) {
            return .validationFailed("Invalid email format")
        }
        
        return nil
    }
    
    /**
     * Validate email format
     */
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
}

// MARK: - Analytics Extensions

extension UserDataService {
    
    /**
     * Track user data operations for analytics
     */
    func trackOperation(_ operation: String, userId: String, success: Bool) {
        // In a real app, this would send analytics data
        let status = success ? "✅" : "❌"
        print("📊 UserDataService: \(operation) for user \(userId) \(status)")
    }
}
