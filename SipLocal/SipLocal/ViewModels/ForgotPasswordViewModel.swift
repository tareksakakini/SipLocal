/**
 * ForgotPasswordViewModel.swift
 * SipLocal
 *
 * ViewModel for ForgotPasswordView following MVVM architecture.
 * Handles password reset logic, email validation, and user feedback.
 *
 * ## Responsibilities
 * - **Password Reset Logic**: Send password reset emails with error handling
 * - **Email Validation**: Real-time email format validation
 * - **State Management**: Loading states and user feedback
 * - **User Feedback**: Success and error message management
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Error Handling**: Structured error management with user-friendly messages
 * - **Validation**: Client-side email validation with immediate feedback
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - ForgotPasswordViewModel

/**
 * ViewModel for ForgotPasswordView
 * 
 * Manages password reset logic, email validation, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class ForgotPasswordViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var email: String = ""
    @Published var isLoading: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    // MARK: - Design Constants
    private enum Design {
        static let emailValidationDelay: Double = 0.3
        static let feedbackDisplayDuration: Double = 5.0
        static let successDisplayDuration: Double = 3.0
    }
    
    // MARK: - Computed Properties
    
    /// Validates email format with comprehensive checks
    var isEmailValid: Bool {
        !email.isEmpty && 
        email.contains("@") && 
        email.contains(".") &&
        email.trimmingCharacters(in: .whitespacesAndNewlines).count > 5
    }
    
    /// Returns the opacity for the reset button based on email validity
    var resetButtonOpacity: Double {
        isEmailValid ? 1.0 : 0.6
    }
    
    /// Returns whether the reset button should be disabled
    var isResetButtonDisabled: Bool {
        !isEmailValid || isLoading
    }
    
    /// Returns validation message for email field
    var emailValidationMessage: String {
        if email.isEmpty {
            return ""
        } else if !email.contains("@") {
            return "Email must contain @"
        } else if !email.contains(".") {
            return "Email must contain a domain"
        } else if email.trimmingCharacters(in: .whitespacesAndNewlines).count <= 5 {
            return "Email is too short"
        } else {
            return ""
        }
    }
    
    /// Returns whether to show email validation UI
    var shouldShowEmailValidation: Bool {
        !email.isEmpty && !isEmailValid
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Public Interface
    
    /// Handle password reset request
    func sendResetLink() {
        // Validate email before proceeding
        guard isEmailValid else {
            showErrorAlert("Invalid Email", "Please enter a valid email address")
            return
        }
        
        // Set loading state
        isLoading = true
        alertTitle = ""
        alertMessage = ""
        showAlert = false
        
        // Clean email input
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Perform password reset
        authManager.sendPasswordReset(for: cleanEmail) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
                    self?.handleResetSuccess()
                } else {
                    let errorMessage = error ?? "An unknown error occurred. Please try again."
                    self?.showErrorAlert("Reset Failed", errorMessage)
                }
            }
        }
    }
    
    /// Clear all form fields and reset state
    func clearForm() {
        email = ""
        isLoading = false
        alertTitle = ""
        alertMessage = ""
        showAlert = false
    }
    
    /// Handle email text changes with validation
    func handleEmailChange(_ newValue: String) {
        email = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Private Methods
    
    private func handleResetSuccess() {
        alertTitle = "Success"
        alertMessage = "A password reset link has been sent to your email. Please check your inbox and follow the instructions."
        showAlert = true
        
        // Auto-hide success message after longer duration
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.successDisplayDuration) {
            if self.alertTitle == "Success" {
                self.showAlert = false
            }
        }
        
        print("✅ Password reset email sent successfully to: \(email)")
    }
    
    private func showErrorAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
        
        // Auto-hide error message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            if self.alertTitle == title && self.alertMessage == message {
                self.showAlert = false
            }
        }
        
        print("❌ Password reset error: \(message)")
    }
}

// MARK: - Validation Extensions

extension ForgotPasswordViewModel {
    
    /// Advanced email validation with detailed feedback
    func validateEmailFormat(_ email: String) -> (isValid: Bool, message: String) {
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedEmail.isEmpty {
            return (false, "Email is required")
        }
        
        if trimmedEmail.count < 6 {
            return (false, "Email is too short")
        }
        
        if !trimmedEmail.contains("@") {
            return (false, "Email must contain @")
        }
        
        let components = trimmedEmail.components(separatedBy: "@")
        if components.count != 2 {
            return (false, "Email format is invalid")
        }
        
        let localPart = components[0]
        let domainPart = components[1]
        
        if localPart.isEmpty {
            return (false, "Email must have a username")
        }
        
        if domainPart.isEmpty || !domainPart.contains(".") {
            return (false, "Email must have a valid domain")
        }
        
        let domainComponents = domainPart.components(separatedBy: ".")
        if domainComponents.count < 2 || domainComponents.contains(where: { $0.isEmpty }) {
            return (false, "Email domain format is invalid")
        }
        
        return (true, "Email format is valid")
    }
    
    /// Returns email validation status for UI feedback
    var emailValidationStatus: (isValid: Bool, message: String) {
        validateEmailFormat(email)
    }
}
