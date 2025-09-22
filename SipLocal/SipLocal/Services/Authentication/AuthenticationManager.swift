/**
 * AuthenticationManager.swift
 * SipLocal
 *
 * Refactored AuthenticationManager following Single Responsibility Principle.
 * Acts as a coordinator for specialized authentication services.
 *
 * ## Responsibilities
 * - **Authentication Coordination**: Sign in, sign up, sign out operations
 * - **Service Management**: Coordinate UserDataService, FavoritesService, StampsService
 * - **State Management**: Maintain authentication state and user session
 * - **Email Verification**: Handle email verification flow
 * - **Device Management**: Coordinate device registration and management
 *
 * ## Architecture
 * - **Coordinator Pattern**: Manages specialized service classes
 * - **Single Responsibility**: Each service handles one concern
 * - **Observable**: Reactive state management with @Published properties
 * - **Error Handling**: Comprehensive error management with structured types
 * - **Performance**: Optimized service coordination and state management
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

/**
 * AuthenticationManager - Coordinator for authentication services
 * 
 * Manages authentication state and coordinates specialized services
 * for user data, favorites, stamps, and device management.
 */
class AuthenticationManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var currentUser: User?
    @Published var favoriteShops: Set<String> = []
    @Published var stampedShops: Set<String> = []
    
    // MARK: - Services
    
    private let auth = Auth.auth()
    private let deviceManager = DeviceManager()
    private let userDataService = UserDataService()
    private let favoritesService = FavoritesService()
    private let stampsService = StampsService()
    
    // MARK: - Private Properties
    
    private var lastKnownUserId: String?
    private var authListenerHandle: AuthStateDidChangeListenerHandle?
    
    // MARK: - Initialization
    
    init() {
        print("🔐 AuthenticationManager initialized")
        
        // Check if user is already authenticated
        self.currentUser = auth.currentUser
        self.isAuthenticated = currentUser != nil
        self.isEmailVerified = currentUser?.isEmailVerified ?? false
        self.lastKnownUserId = currentUser?.uid
        
        // Listen for authentication state changes
        authListenerHandle = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.handleAuthenticationStateChange(user: user)
            }
        }
    }
    
    deinit {
        if let handle = authListenerHandle {
            auth.removeStateDidChangeListener(handle)
        }
        print("🔐 AuthenticationManager deinitialized")
    }
    
    // MARK: - Authentication State Management
    
    /**
     * Handle authentication state changes
     */
    private func handleAuthenticationStateChange(user: User?) {
        currentUser = user
        isAuthenticated = user != nil
        isEmailVerified = user?.isEmailVerified ?? false
        lastKnownUserId = user?.uid
        
        if user != nil {
            // User signed in - fetch user data and register device
            fetchUserData()
            registerCurrentDevice()
        } else {
            // User signed out - clear data
            favoriteShops = []
            stampedShops = []
        }
    }
    
    // MARK: - Authentication Operations
    
    /**
     * Sign up a new user
     */
    func signUp(email: String, password: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        // First, create the user account
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            guard let user = result?.user else {
                completion(false, "Failed to create user account")
                return
            }
            
            // Save user data to Firestore using UserDataService
            self.userDataService.saveUserData(userId: user.uid, userData: userData) { success, error in
                if success {
                    // Send verification email
                    self.sendVerificationEmail { _, _ in
                        // The completion for sending the email can be ignored here,
                        // as the user will be prompted to verify on the next screen.
                    }
                    completion(true, nil)
                } else {
                    // If saving user data fails, we should delete the created account
                    user.delete { _ in
                        completion(false, error ?? "Failed to save user data")
                    }
                }
            }
        }
    }
    
    /**
     * Sign in an existing user
     */
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            completion(true, nil)
        }
    }
    
    /**
     * Sign out the current user
     */
    func signOut() {
        // First unregister the device while user is still authenticated
        if let userId = currentUser?.uid {
            deviceManager.unregisterDeviceForUser(userId: userId) { [weak self] success, error in
                if success {
                    print("Device unregistered successfully before sign out")
                } else {
                    print("Failed to unregister device before sign out: \(error ?? "Unknown error")")
                }
                
                // Now sign out regardless of device unregistration result
                DispatchQueue.main.async {
                    do {
                        try self?.auth.signOut()  
                    } catch {
                        print("Error signing out: \(error.localizedDescription)")
                    }
                }
            }
        } else {
            // No user to unregister, just sign out
            do {
                try auth.signOut()
            } catch {
                print("Error signing out: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - User Data Operations
    
    /**
     * Check if username is available
     */
    func checkUsernameAvailability(username: String, completion: @escaping (Bool) -> Void) {
        userDataService.checkUsernameAvailability(username: username, completion: completion)
    }
    
    /**
     * Get user data
     */
    func getUserData(userId: String, completion: @escaping (UserData?, String?) -> Void) {
        userDataService.getUserData(userId: userId, completion: completion)
    }
    
    /**
     * Update user data
     */
    func updateUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        userDataService.updateUserData(userId: userId, userData: userData, completion: completion)
    }
    
    /**
     * Delete user account
     */
    func deleteUserAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = currentUser else {
            completion(false, "No user is currently signed in")
            return
        }
        
        let userId = user.uid
        
        // First, delete user data from Firestore using UserDataService
        userDataService.deleteUserData(userId: userId) { success, error in
            if let error = error {
                completion(false, error)
                return
            }
            
            // Then delete the authentication account
            user.delete { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    completion(true, nil)
                }
            }
        }
    }
    
    // MARK: - Email Verification
    
    /**
     * Send email verification
     */
    func sendVerificationEmail(completion: @escaping (Bool, String?) -> Void) {
        guard let user = currentUser else {
            completion(false, "No user is signed in.")
            return
        }
        
        user.sendEmailVerification { error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            completion(true, nil)
        }
    }
    
    /**
     * Reload user data
     */
    func reloadUser(completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("Error reloading user: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                self?.currentUser = self?.auth.currentUser
                self?.isEmailVerified = self?.auth.currentUser?.isEmailVerified ?? false
                completion(true)
            }
        }
    }
    
    /**
     * Send password reset email
     */
    func sendPasswordReset(for email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            completion(true, nil)
        }
    }
    
    // MARK: - Favorites Operations
    
    /**
     * Add a shop to favorites
     */
    func addFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        favoritesService.addFavorite(userId: userId, shopId: shopId) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    self?.favoriteShops.insert(shopId)
                }
            }
            completion(success)
        }
    }
    
    /**
     * Remove a shop from favorites
     */
    func removeFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        favoritesService.removeFavorite(userId: userId, shopId: shopId) { [weak self] success in
            if success {
                DispatchQueue.main.async {
                    self?.favoriteShops.remove(shopId)
                }
            }
            completion(success)
        }
    }
    
    /**
     * Check if a shop is in favorites
     */
    func isFavorite(shopId: String) -> Bool {
        guard let userId = currentUser?.uid else { return false }
        return favoritesService.isFavorite(userId: userId, shopId: shopId, favorites: favoriteShops)
    }
    
    // MARK: - Stamps Operations
    
    /**
     * Add a stamp to a shop
     */
    func addStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        DispatchQueue.main.async {
            self.stampedShops.insert(shopId)
        }
        
        stampsService.addStamp(userId: userId, shopId: shopId) { [weak self] success in
            if !success {
                // Revert on failure
                DispatchQueue.main.async {
                    self?.stampedShops.remove(shopId)
                }
            }
            completion(success)
        }
    }
    
    /**
     * Remove a stamp from a shop
     */
    func removeStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        DispatchQueue.main.async {
            self.stampedShops.remove(shopId)
        }
        
        stampsService.removeStamp(userId: userId, shopId: shopId) { [weak self] success in
            if !success {
                // Revert on failure
                DispatchQueue.main.async {
                    self?.stampedShops.insert(shopId)
                }
            }
            completion(success)
        }
    }

    // MARK: - Profile Image Management
    
    /**
     * Upload profile image
     */
    func uploadProfileImage(_ image: UIImage) async -> (success: Bool, errorMessage: String?) {
        guard let userId = currentUser?.uid else {
            return (false, "No user is currently signed in")
        }
        
        return await userDataService.uploadProfileImage(userId: userId, image: image)
    }
    
    /**
     * Remove profile image
     */
    func removeProfileImage() async -> (success: Bool, errorMessage: String?) {
        guard let userId = currentUser?.uid else {
            return (false, "No user is currently signed in")
        }
        
        return await userDataService.removeProfileImage(userId: userId)
    }
    
    // MARK: - Data Fetching
    
    /**
     * Fetch user data (favorites and stamps)
     */
    private func fetchUserData() {
        guard let userId = currentUser?.uid else { return }
        
        // Fetch favorites
        favoritesService.fetchFavorites(userId: userId) { [weak self] favorites in
            DispatchQueue.main.async {
                self?.favoriteShops = favorites
            }
        }
        
        // Fetch stamps
        stampsService.fetchStampedShops(userId: userId) { [weak self] stamps in
            DispatchQueue.main.async {
                self?.stampedShops = stamps
            }
        }
    }
    
    // MARK: - Device Management
    
    /**
     * Register current device for user
     */
    private func registerCurrentDevice() {
        guard let userId = currentUser?.uid else { return }
        
        deviceManager.registerDeviceForUser(userId: userId) { success, error in
            if success {
                print("Device registered ✅")
            } else {
                print("Device registration failed ❌")
            }
        }
    }
    
    /**
     * Update device activity
     */
    func updateDeviceActivity() {
        guard let userId = currentUser?.uid else { return }
        
        deviceManager.updateDeviceActivity(userId: userId) { success, error in
            if !success {
                print("Device activity update failed ❌")
            }
        }
    }
    
    /**
     * Get user devices
     */
    func getUserDevices(completion: @escaping ([DeviceManager.UserDevice]) -> Void) {
        guard let userId = currentUser?.uid else {
            completion([])
            return
        }
        
        deviceManager.getUserDevices(userId: userId, completion: completion)
    }
    
    /**
     * Get active device IDs
     */
    func getActiveDeviceIds(completion: @escaping ([String]) -> Void) {
        guard let userId = currentUser?.uid else {
            completion([])
            return
        }
        
        deviceManager.getActiveDeviceIds(userId: userId, completion: completion)
    }
    
    /**
     * Remove inactive devices
     */
    func removeInactiveDevices(daysCutoff: Int = 90, completion: @escaping (Int, String?) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(0, "No user signed in")
            return
        }
        
        deviceManager.removeInactiveDevices(userId: userId, daysCutoff: daysCutoff, completion: completion)
    }
    
    /**
     * Unregister specific device
     */
    func unregisterSpecificDevice(deviceId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false, "No user signed in")
            return
        }
        
        let userDocRef = Firestore.firestore().collection("users").document(userId)
        userDocRef.updateData([
            "devices.\(deviceId)": FieldValue.delete()
        ]) { error in
            if let error = error {
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
}

// MARK: - Design System

extension AuthenticationManager {
    
    /**
     * Design system constants for AuthenticationManager
     */
    enum Design {
        // Service names
        static let userDataServiceName = "UserDataService"
        static let favoritesServiceName = "FavoritesService"
        static let stampsServiceName = "StampsService"
        static let deviceManagerName = "DeviceManager"
        
        // Error messages
        static let noUserSignedIn = "No user is currently signed in"
        static let failedToCreateUser = "Failed to create user account"
        static let failedToSaveUserData = "Failed to save user data"
        static let userDataNotFound = "User data not found"
        
        // Logging
        static let authManagerInitialized = "🔐 AuthenticationManager initialized"
        static let authManagerDeinitialized = "🔐 AuthenticationManager deinitialized"
        static let deviceRegistered = "Device registered ✅"
        static let deviceRegistrationFailed = "Device registration failed ❌"
        static let deviceActivityUpdateFailed = "Device activity update failed ❌"
    }
} 
