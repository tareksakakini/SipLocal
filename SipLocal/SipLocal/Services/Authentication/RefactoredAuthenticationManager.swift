/**
 * RefactoredAuthenticationManager.swift
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
import Combine

// MARK: - RefactoredAuthenticationManager

/**
 * Refactored Authentication Manager
 * 
 * Coordinates authentication operations and specialized services.
 * Provides clean separation of concerns while maintaining existing API compatibility.
 */
class RefactoredAuthenticationManager: ObservableObject {
    
    // MARK: - Published State Properties
    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var currentUser: User?
    
    // Service state forwarding for backward compatibility
    @Published var favoriteShops: Set<String> = []
    @Published var stampedShops: Set<String> = []
    
    // MARK: - Service Dependencies
    private let auth: Auth
    private let firestore: Firestore
    private let storage: Storage
    private let deviceManager: DeviceManager
    
    // Specialized Services
    private let userDataService: UserDataService
    private let favoritesService: FavoritesService
    private let stampsService: StampsService
    
    // MARK: - Configuration
    private enum Configuration {
        static let authStateTimeout: TimeInterval = 30.0
        static let emailVerificationTimeout: TimeInterval = 60.0
        static let passwordResetTimeout: TimeInterval = 30.0
    }
    
    // MARK: - Private State
    private var lastKnownUserId: String?
    private var authStateListener: AuthStateDidChangeListenerHandle?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize Firebase services
        self.auth = Auth.auth()
        self.firestore = Firestore.firestore()
        self.storage = Storage.storage()
        self.deviceManager = DeviceManager()
        
        // Initialize specialized services
        self.userDataService = UserDataService(firestore: firestore)
        self.favoritesService = FavoritesService(firestore: firestore, userId: auth.currentUser?.uid)
        self.stampsService = StampsService(firestore: firestore, userId: auth.currentUser?.uid)
        
        // Set initial authentication state
        self.currentUser = auth.currentUser
        self.isAuthenticated = currentUser != nil
        self.isEmailVerified = currentUser?.isEmailVerified ?? false
        self.lastKnownUserId = currentUser?.uid
        
        // Setup service state forwarding
        setupServiceStateForwarding()
        
        // Setup authentication state listener
        setupAuthenticationStateListener()
        
        // Initialize services if user is already authenticated
        if let user = currentUser {
            initializeServicesForUser(user)
        }
        
        print("🔐 RefactoredAuthenticationManager initialized")
    }
    
    deinit {
        if let handle = authStateListener {
            auth.removeStateDidChangeListener(handle)
        }
        cancellables.removeAll()
        print("🔐 RefactoredAuthenticationManager deinitialized")
    }
    
    // MARK: - Authentication Operations
    
    /**
     * Sign up new user with email and password
     */
    func signUp(email: String, password: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
        auth.createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                print("🔐 Sign up failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
                return
            }
            
            guard let user = result?.user else {
                completion(false, "Failed to create user account")
                return
            }
            
            // Save user data using UserDataService
            self.userDataService.saveUserData(userId: user.uid, userData: userData) { success, error in
                if success {
                    // Send verification email
                    self.sendVerificationEmail { _, _ in
                        // Verification email result can be ignored here
                    }
                    print("🔐 Sign up successful ✅")
                    completion(true, nil)
                } else {
                    // If saving user data fails, delete the created account
                    user.delete { _ in
                        completion(false, error ?? "Failed to save user data")
                    }
                }
            }
        }
    }
    
    /**
     * Sign in user with email and password
     */
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        auth.signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("🔐 Sign in failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("🔐 Sign in successful ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Sign out current user
     */
    func signOut() {
        do {
            // Unregister device before signing out
            if let userId = currentUser?.uid {
                deviceManager.unregisterDeviceForUser(userId: userId) { success, error in
                    if !success {
                        print("🔐 Device unregistration failed ⚠️")
                    }
                }
            }
            
            try auth.signOut()
            print("🔐 Sign out successful ✅")
        } catch {
            print("🔐 Sign out failed ❌ - \(error.localizedDescription)")
        }
    }
    
    /**
     * Send password reset email
     */
    func sendPasswordReset(for email: String, completion: @escaping (Bool, String?) -> Void) {
        auth.sendPasswordReset(withEmail: email) { error in
            if let error = error {
                print("🔐 Password reset failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("🔐 Password reset email sent ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Send email verification
     */
    func sendVerificationEmail(completion: @escaping (Bool, String?) -> Void) {
        guard let user = currentUser else {
            completion(false, "No user is currently signed in")
            return
        }
        
        user.sendEmailVerification { error in
            if let error = error {
                print("🔐 Email verification failed ❌ - \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("🔐 Email verification sent ✅")
                completion(true, nil)
            }
        }
    }
    
    /**
     * Reload user to check verification status
     */
    func reloadUser(completion: @escaping (Bool) -> Void) {
        guard let user = currentUser else {
            completion(false)
            return
        }
        
        user.reload { [weak self] error in
            DispatchQueue.main.async {
                if let error = error {
                    print("🔐 User reload failed ❌ - \(error.localizedDescription)")
                    completion(false)
                } else {
                    self?.isEmailVerified = user.isEmailVerified
                    print("🔐 User reload successful ✅")
                    completion(true)
                }
            }
        }
    }
    
    // MARK: - User Data Operations (Delegated to UserDataService)
    
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
        
        // Delete user data using UserDataService
        userDataService.deleteUserData(userId: userId) { success, error in
            if !success {
                completion(false, error)
                return
            }
            
            // Delete authentication account
            user.delete { error in
                if let error = error {
                    completion(false, error.localizedDescription)
                } else {
                    print("🔐 Account deleted successfully ✅")
                    completion(true, nil)
                }
            }
        }
    }
    
    /**
     * Check username availability
     */
    func checkUsernameAvailability(username: String) async -> Bool {
        return await userDataService.checkUsernameAvailability(username: username)
    }
    
    // MARK: - Favorites Operations (Delegated to FavoritesService)
    
    /**
     * Add favorite shop
     */
    func addFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        favoritesService.addFavorite(shopId: shopId, completion: completion)
    }
    
    /**
     * Remove favorite shop
     */
    func removeFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        favoritesService.removeFavorite(shopId: shopId, completion: completion)
    }
    
    /**
     * Fetch favorites
     */
    func fetchFavorites() {
        favoritesService.fetchFavorites()
    }
    
    // MARK: - Stamps Operations (Delegated to StampsService)
    
    /**
     * Add loyalty stamp
     */
    func addStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        stampsService.addStamp(shopId: shopId, completion: completion)
    }
    
    /**
     * Remove loyalty stamp
     */
    func removeStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        stampsService.removeStamp(shopId: shopId, completion: completion)
    }
    
    /**
     * Fetch stamps
     */
    func fetchStampedShops() {
        stampsService.fetchStamps()
    }
    
    // MARK: - Device Management Operations
    
    /**
     * Register current device
     */
    func registerCurrentDevice() {
        guard let userId = currentUser?.uid else { return }
        
        deviceManager.registerDeviceForUser(userId: userId) { success, error in
            if success {
                print("🔐 Device registered successfully ✅")
            } else {
                print("🔐 Device registration failed ❌")
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
                print("🔐 Device activity update failed ❌")
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
        
        let userDocRef = firestore.collection("users").document(userId)
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
    
    // MARK: - Private Methods
    
    private func setupServiceStateForwarding() {
        // Forward favorites state
        favoritesService.$favoriteShops
            .assign(to: &$favoriteShops)
        
        // Forward stamps state
        stampsService.$stampedShops
            .assign(to: &$stampedShops)
    }
    
    private func setupAuthenticationStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // Store the previous user ID before updating
                let previousUserId = self.lastKnownUserId
                
                // Update authentication state
                self.currentUser = user
                self.isAuthenticated = user != nil
                self.isEmailVerified = user?.isEmailVerified ?? false
                self.lastKnownUserId = user?.uid
                
                if let user = user {
                    // User signed in
                    self.initializeServicesForUser(user)
                } else {
                    // User signed out
                    self.cleanupServicesForSignOut()
                }
                
                print("🔐 Auth state changed: \(user?.uid ?? "signed out")")
            }
        }
    }
    
    private func initializeServicesForUser(_ user: User) {
        // Update services with new user ID
        favoritesService.updateUserId(user.uid)
        stampsService.updateUserId(user.uid)
        
        // Fetch initial data
        favoritesService.fetchFavorites()
        stampsService.fetchStamps()
        
        // Register device
        registerCurrentDevice()
        
        print("🔐 Services initialized for user: \(user.uid)")
    }
    
    private func cleanupServicesForSignOut() {
        // Update services to remove user ID
        favoritesService.updateUserId(nil)
        stampsService.updateUserId(nil)
        
        print("🔐 Services cleaned up after sign out")
    }
}

// MARK: - AuthenticationError

/**
 * Structured error types for authentication operations
 */
enum AuthenticationError: LocalizedError {
    case signInFailed(String)
    case signUpFailed(String)
    case signOutFailed(String)
    case passwordResetFailed(String)
    case emailVerificationFailed(String)
    case userDataError(String)
    case networkUnavailable
    case userNotFound
    case invalidCredentials
    case weakPassword
    case emailAlreadyInUse
    
    var errorDescription: String? {
        switch self {
        case .signInFailed(let message):
            return "Sign in failed: \(message)"
        case .signUpFailed(let message):
            return "Sign up failed: \(message)"
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .emailVerificationFailed(let message):
            return "Email verification failed: \(message)"
        case .userDataError(let message):
            return "User data error: \(message)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .userNotFound:
            return "User not found"
        case .invalidCredentials:
            return "Invalid email or password"
        case .weakPassword:
            return "Password is too weak"
        case .emailAlreadyInUse:
            return "Email is already in use"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .signInFailed, .signUpFailed:
            return "Please check your credentials and try again."
        case .passwordResetFailed:
            return "Please check your email address and try again."
        case .emailVerificationFailed:
            return "Please check your email and try again."
        case .networkUnavailable:
            return "Please check your internet connection."
        case .invalidCredentials:
            return "Please verify your email and password."
        case .weakPassword:
            return "Please choose a stronger password."
        case .emailAlreadyInUse:
            return "Please use a different email address or sign in instead."
        default:
            return "Please try again later."
        }
    }
}

// MARK: - Analytics Extensions

extension RefactoredAuthenticationManager {
    
    /**
     * Get authentication analytics data
     */
    var analyticsData: [String: Any] {
        return [
            "is_authenticated": isAuthenticated,
            "is_email_verified": isEmailVerified,
            "favorites_count": favoriteShops.count,
            "stamps_count": stampedShops.count,
            "user_id": currentUser?.uid ?? "none",
            "last_updated": Date().timeIntervalSince1970
        ]
    }
    
    /**
     * Track authentication events for analytics
     */
    func trackAuthEvent(_ event: String, success: Bool, details: [String: Any] = [:]) {
        // In a real app, this would send analytics data
        let status = success ? "✅" : "❌"
        print("📊 Auth Event: \(event) \(status) - \(details)")
    }
}
