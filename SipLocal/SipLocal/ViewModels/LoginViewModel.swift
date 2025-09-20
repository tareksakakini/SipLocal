/**
 * LoginViewModel.swift
 * SipLocal
 *
 * ViewModel for LoginView following MVVM architecture.
 * Handles authentication logic, form validation, and user feedback.
 *
 * ## Responsibilities
 * - **Authentication Logic**: Sign-in operations with error handling
 * - **Form Validation**: Real-time form validation with visual feedback
 * - **State Management**: Loading states and error handling
 * - **User Feedback**: Success and error message management
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Error Handling**: Structured error management with user-friendly messages
 * - **Validation**: Client-side form validation with immediate feedback
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - LoginViewModel

/**
 * ViewModel for LoginView
 * 
 * Manages authentication logic, form validation, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class LoginViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    
    // MARK: - Computed Properties
    
    /// Validates the form and returns true if all fields are valid
    var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        email.contains("@") && 
        password.count >= 6
    }
    
    /// Returns the opacity for the login button based on form validity
    var loginButtonOpacity: Double {
        isFormValid ? 1.0 : 0.6
    }
    
    /// Returns whether the login button should be disabled
    var isLoginButtonDisabled: Bool {
        !isFormValid || isLoading
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Public Interface
    
    /// Handle sign-in action
    func signIn() {
        // Validate form before proceeding
        guard isFormValid else {
            showErrorMessage("Please fill in all fields correctly")
            return
        }
        
        // Set loading state
        isLoading = true
        errorMessage = ""
        showError = false
        
        // Perform sign-in
        authManager.signIn(email: email, password: password) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
                    // Success - navigation will be handled by the app's auth state
                    print("✅ Login successful")
                } else {
                    // Handle error
                    let errorText = error ?? "Login failed. Please try again."
                    self?.showErrorMessage(errorText)
                }
            }
        }
    }
    
    /// Clear all form fields and reset state
    func clearForm() {
        email = ""
        password = ""
        errorMessage = ""
        showError = false
        isLoading = false
    }
    
    /// Handle forgot password action
    func handleForgotPassword() {
        // This would typically navigate to forgot password view
        // Navigation is handled by the parent view
        print("Navigate to forgot password")
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Private Methods
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // Auto-hide error after 5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if self.errorMessage == message {  // Only hide if it's the same message
                self.showError = false
            }
        }
    }
}

// MARK: - Form Validation Extensions

extension LoginViewModel {
    
    /// Validates email format
    var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    /// Validates password strength
    var isPasswordValid: Bool {
        password.count >= 6
    }
    
    /// Returns email validation message
    var emailValidationMessage: String {
        if email.isEmpty {
            return ""
        } else if !isEmailValid {
            return "Please enter a valid email address"
        } else {
            return ""
        }
    }
    
    /// Returns password validation message
    var passwordValidationMessage: String {
        if password.isEmpty {
            return ""
        } else if !isPasswordValid {
            return "Password must be at least 6 characters"
        } else {
            return ""
        }
    }
}
