package com.example.siplocalandroid.auth

import com.example.siplocalandroid.data.UserData
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.FieldValue
import kotlinx.coroutines.tasks.await
import java.util.Date

class AuthenticationManager {
    private val auth = FirebaseAuth.getInstance()
    private val firestore = FirebaseFirestore.getInstance()
    
    // Expose authentication state as computed properties so they always reflect the latest FirebaseAuth status
    val currentUser get() = auth.currentUser
    val isAuthenticated get() = auth.currentUser != null
    
    suspend fun signUp(email: String, password: String, userData: UserData): Result<Unit> {
        return try {
            // Check if Firebase is properly configured
            if (!isFirebaseConfigured()) {
                return Result.failure(Exception("Firebase is not configured. Please add google-services.json file."))
            }
            
            // Create user account
            val result = auth.createUserWithEmailAndPassword(email, password).await()
            val user = result.user ?: return Result.failure(Exception("Failed to create user account"))
            
            // Save user data to Firestore
            saveUserData(user.uid, userData)
            
            // Send verification email
            user.sendEmailVerification().await()
            
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    suspend fun signIn(email: String, password: String): Result<String> {
        return try {
            if (!isFirebaseConfigured()) {
                return Result.failure(Exception("Firebase is not configured. Please add google-services.json file."))
            }
            
            auth.signInWithEmailAndPassword(email, password).await()
            Result.success("Signed in successfully")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    fun signOut() {
        try {
            auth.signOut()
        } catch (e: Exception) {
            // Handle gracefully
        }
    }
    
    suspend fun checkUsernameAvailability(username: String): Boolean {
        return try {
            if (!isFirebaseConfigured()) {
                // Return true for testing purposes when Firebase is not configured
                return true
            }
            
            val result = firestore.collection("users")
                .whereEqualTo("username", username)
                .get()
                .await()
            result.documents.isEmpty()
        } catch (e: Exception) {
            // Return true for testing purposes on error
            true
        }
    }
    
    private suspend fun saveUserData(userId: String, userData: UserData) {
        val userDocument = firestore.collection("users").document(userId)
        
        val userDataMap = hashMapOf(
            "fullName" to userData.fullName,
            "username" to userData.username,
            "email" to userData.email,
            "createdAt" to Date(),
            "isActive" to true,
            "favorites" to emptyList<String>() // Initialize favorites field
        )
        
        userDocument.set(userDataMap).await()
    }

    suspend fun addFavorite(shopId: String): Result<Unit> {
        val userId = currentUser?.uid ?: return Result.failure(Exception("User not authenticated"))
        return try {
            val userDocRef = firestore.collection("users").document(userId)
            userDocRef.update("favorites", FieldValue.arrayUnion(shopId)).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun removeFavorite(shopId: String): Result<Unit> {
        val userId = currentUser?.uid ?: return Result.failure(Exception("User not authenticated"))
        return try {
            val userDocRef = firestore.collection("users").document(userId)
            userDocRef.update("favorites", FieldValue.arrayRemove(shopId)).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun isFavorite(shopId: String): Boolean {
        val userId = currentUser?.uid ?: return false
        return try {
            val document = firestore.collection("users").document(userId).get().await()
            val favorites = document.get("favorites") as? List<*>
            favorites?.contains(shopId) ?: false
        } catch (e: Exception) {
            false
        }
    }

    suspend fun getFavoriteShopIds(): List<String> {
        val userId = currentUser?.uid ?: return emptyList()
        return try {
            val document = firestore.collection("users").document(userId).get().await()
            document.get("favorites") as? List<String> ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun addStamp(shopId: String): Result<Unit> {
        val userId = currentUser?.uid ?: return Result.failure(Exception("User not authenticated"))
        return try {
            val userDocRef = firestore.collection("users").document(userId)
            userDocRef.update("stampedShops", FieldValue.arrayUnion(shopId)).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun removeStamp(shopId: String): Result<Unit> {
        val userId = currentUser?.uid ?: return Result.failure(Exception("User not authenticated"))
        return try {
            val userDocRef = firestore.collection("users").document(userId)
            userDocRef.update("stampedShops", FieldValue.arrayRemove(shopId)).await()
            Result.success(Unit)
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun getStampedShopIds(): List<String> {
        val userId = currentUser?.uid ?: return emptyList()
        return try {
            val document = firestore.collection("users").document(userId).get().await()
            document.get("stampedShops") as? List<String> ?: emptyList()
        } catch (e: Exception) {
            emptyList()
        }
    }

    suspend fun sendVerificationEmail(): Result<String> {
        return try {
            auth.currentUser?.sendEmailVerification()?.await()
            Result.success("A new verification email has been sent to your address.")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    suspend fun reloadUser(): Boolean {
        return try {
            auth.currentUser?.reload()?.await()
            auth.currentUser?.isEmailVerified ?: false
        } catch (e: Exception) {
            false
        }
    }
    
    suspend fun sendPasswordReset(email: String): Result<String> {
        return try {
            if (!isFirebaseConfigured()) {
                return Result.failure(Exception("Firebase is not configured. Please add google-services.json file."))
            }
            
            auth.sendPasswordResetEmail(email).await()
            Result.success("Password reset email sent")
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
    
    private fun isFirebaseConfigured(): Boolean {
        return try {
            // Try to get the Firebase app instance
            com.google.firebase.FirebaseApp.getInstance()
            true
        } catch (e: Exception) {
            false
        }
    }
} 