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

class AuthenticationManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    
    init() {
        // Check if user is already authenticated
        self.currentUser = auth.currentUser
        self.isAuthenticated = currentUser != nil
        
        // Listen for authentication state changes
        auth.addStateDidChangeListener { [weak self] _, user in
            DispatchQueue.main.async {
                self?.currentUser = user
                self?.isAuthenticated = user != nil
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
        firestore.collection("users").document(userId).getDocument { document, error in
            if let error = error {
                completion(nil, error.localizedDescription)
                return
            }
            
            guard let document = document,
                  document.exists,
                  let data = document.data(),
                  let fullName = data["fullName"] as? String,
                  let username = data["username"] as? String,
                  let email = data["email"] as? String else {
                completion(nil, "User data not found")
                return
            }
            
            let userData = UserData(
                fullName: fullName,
                username: username,
                email: email
            )
            
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
} 