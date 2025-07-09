//
//  AuthenticationManager.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isEmailVerified = false
    @Published var currentUser: User?
    @Published var favoriteShops: Set<String> = []
    @Published var stampedShops: Set<String> = []
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    
    init() {
        // Check if user is already authenticated
        self.currentUser = auth.currentUser
        self.isAuthenticated = currentUser != nil
        self.isEmailVerified = currentUser?.isEmailVerified ?? false
        
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
                self?.isEmailVerified = user?.isEmailVerified ?? false
                
                if user != nil {
                    self?.fetchFavorites()
                    self?.fetchStampedShops()
                } else {
                    self?.favoriteShops = []
                    self?.stampedShops = []
                }
            }
        }
    }
    
    // MARK: - Sign Up Function
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
            
            // Save user data to Firestore
            self.saveUserData(userId: user.uid, userData: userData) { success, error in
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
    
    // MARK: - Save User Data to Firestore
    private func saveUserData(userId: String, userData: UserData, completion: @escaping (Bool, String?) -> Void) {
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
    
    // MARK: - Sign In Function
    func signIn(email: String, password: String, completion: @escaping (Bool, String?) -> Void) {
        auth.signIn(withEmail: email, password: password) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            
            completion(true, nil)
        }
    }
    
    // MARK: - Sign Out Function
    func signOut() {
        do {
            try auth.signOut()
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Check Username Availability
    func checkUsernameAvailability(username: String, completion: @escaping (Bool) -> Void) {
        firestore.collection("users")
            .whereField("username", isEqualTo: username)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error checking username availability: \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                // If no documents found, username is available
                completion(snapshot?.documents.isEmpty ?? false)
            }
    }
    
    // MARK: - Get User Data
    func getUserData(userId: String, completion: @escaping (UserData?, String?) -> Void) {
        print("AuthManager: Getting user data for ID: \(userId)")
        firestore.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                print("AuthManager: Error getting user document: \(error.localizedDescription)")
                completion(nil, error.localizedDescription)
                return
            }
            
            guard let document = document,
                  document.exists,
                  let data = document.data(),
                  let fullName = data["fullName"] as? String,
                  let username = data["username"] as? String,
                  let email = data["email"] as? String else {
                print("AuthManager: User document not found or missing required fields")
                completion(nil, "User data not found")
                return
            }
            
            let profileImageUrl = data["profileImageUrl"] as? String
            print("AuthManager: Retrieved profile image URL: \(profileImageUrl ?? "nil")")
            
            let userData = UserData(
                fullName: fullName,
                username: username,
                email: email,
                profileImageUrl: profileImageUrl
            )
            
            print("AuthManager: User data successfully created")
            completion(userData, nil)
        }
    }
    
    // MARK: - Update User Data
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
    
    // MARK: - Delete User Account
    func deleteUserAccount(completion: @escaping (Bool, String?) -> Void) {
        guard let user = currentUser else {
            completion(false, "No user is currently signed in")
            return
        }
        
        let userId = user.uid
        
        // First, delete user data from Firestore
        firestore.collection("users").document(userId).delete { [weak self] error in
            if let error = error {
                completion(false, error.localizedDescription)
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
    
    func sendPasswordReset(for email: String, completion: @escaping (Bool, String?) -> Void) {
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                completion(false, error.localizedDescription)
                return
            }
            completion(true, nil)
        }
    }
    
    // MARK: - Favorites
    
    func addFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "favorites": FieldValue.arrayUnion([shopId])
        ]) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.favoriteShops.insert(shopId)
                }
            }
            completion(error == nil)
        }
    }
    
    func removeFavorite(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "favorites": FieldValue.arrayRemove([shopId])
        ]) { error in
            if error == nil {
                DispatchQueue.main.async {
                    self.favoriteShops.remove(shopId)
                }
            }
            completion(error == nil)
        }
    }
    
    func isFavorite(shopId: String) -> Bool {
        return favoriteShops.contains(shopId)
    }
    
    // MARK: - Stamped Shops
    
    func addStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        DispatchQueue.main.async {
            self.stampedShops.insert(shopId)
        }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "stampedShops": FieldValue.arrayUnion([shopId])
        ]) { error in
            if let error = error {
                // Revert on failure
                DispatchQueue.main.async {
                    self.stampedShops.remove(shopId)
                }
                print("Error adding stamp: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func removeStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = currentUser?.uid else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        DispatchQueue.main.async {
            self.stampedShops.remove(shopId)
        }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.updateData([
            "stampedShops": FieldValue.arrayRemove([shopId])
        ]) { error in
            if let error = error {
                // Revert on failure
                DispatchQueue.main.async {
                    self.stampedShops.insert(shopId)
                }
                print("Error removing stamp: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }
    
    func fetchStampedShops() {
        guard let userId = currentUser?.uid else { return }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let stamps = data["stampedShops"] as? [String] {
                DispatchQueue.main.async {
                    self.stampedShops = Set(stamps)
                }
            }
        }
    }

    // MARK: - Profile Image Management
    
    func uploadProfileImage(_ image: UIImage) async -> (success: Bool, errorMessage: String?) {
        print("AuthManager: Starting profile image upload...")
        guard let userId = currentUser?.uid else {
            print("AuthManager: No user signed in")
            return (false, "No user is currently signed in")
        }
        
        print("AuthManager: User ID: \(userId)")
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("AuthManager: Failed to convert image to JPEG data")
            return (false, "Failed to process image")
        }
        
        print("AuthManager: Image data size: \(imageData.count) bytes")
        
        let storageRef = storage.reference().child("profile_pictures/\(userId).jpg")
        print("AuthManager: Storage path: profile_pictures/\(userId).jpg")
        
        do {
            print("AuthManager: Uploading to Firebase Storage...")
            let _ = try await storageRef.putDataAsync(imageData)
            print("AuthManager: Upload to storage successful")
            
            let downloadURL = try await storageRef.downloadURL()
            print("AuthManager: Download URL: \(downloadURL.absoluteString)")
            
            // Update user document with profile image URL
            let userDocument = firestore.collection("users").document(userId)
            print("AuthManager: Updating Firestore document...")
            try await userDocument.updateData(["profileImageUrl": downloadURL.absoluteString])
            print("AuthManager: Firestore update successful")
            
            return (true, nil)
        } catch {
            print("AuthManager: Upload failed with error: \(error.localizedDescription)")
            return (false, error.localizedDescription)
        }
    }
    
    func removeProfileImage() async -> (success: Bool, errorMessage: String?) {
        guard let userId = currentUser?.uid else {
            return (false, "No user is currently signed in")
        }
        
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
    
    func fetchFavorites() {
        guard let userId = currentUser?.uid else { return }
        
        let userDocument = firestore.collection("users").document(userId)
        userDocument.getDocument { document, error in
            if let document = document,
               let data = document.data(),
               let favorites = data["favorites"] as? [String] {
                DispatchQueue.main.async {
                    self.favoriteShops = Set(favorites)
                }
            }
        }
    }
} 