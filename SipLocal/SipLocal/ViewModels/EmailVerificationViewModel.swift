/**
 * EmailVerificationViewModel.swift
 * SipLocal
 *
 * ViewModel for EmailVerificationView following MVVM architecture.
 * Handles email verification logic, status checking, and user feedback.
 *
 * ## Responsibilities
 * - **Verification Status**: Check email verification status with user reload
 * - **Email Resending**: Resend verification emails with error handling
 * - **State Management**: Loading states for different operations
 * - **User Feedback**: Success and error message management
 * - **Navigation Logic**: Handle sign out and verification completion
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Error Handling**: Structured error management with user-friendly messages
 * - **Operation Separation**: Distinct loading states for different operations
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - EmailVerificationViewModel

/**
 * ViewModel for EmailVerificationView
 * 
 * Manages email verification logic, status checking, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class EmailVerificationViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var isCheckingStatus: Bool = false
    @Published var isResendingEmail: Bool = false
    @Published var showAlert: Bool = false
    @Published var alertTitle: String = ""
    @Published var alertMessage: String = ""
    
    // MARK: - Design Constants
    private enum Design {
        static let statusCheckCooldown: Double = 2.0
        static let resendCooldown: Double = 30.0
        static let feedbackDisplayDuration: Double = 5.0
        static let successDisplayDuration: Double = 3.0
        static let maxResendAttempts: Int = 3
    }
    
    // MARK: - Private State
    private var lastStatusCheck: Date = Date.distantPast
    private var lastResendTime: Date = Date.distantPast
    private var resendAttempts: Int = 0
    
    // MARK: - Computed Properties
    
    /// Returns whether any operation is currently in progress
    var isOperationInProgress: Bool {
        isCheckingStatus || isResendingEmail
    }
    
    /// Returns whether the check status button should be disabled
    var isCheckStatusDisabled: Bool {
        isOperationInProgress || 
        Date().timeIntervalSince(lastStatusCheck) < Design.statusCheckCooldown
    }
    
    /// Returns whether the resend button should be disabled
    var isResendDisabled: Bool {
        isOperationInProgress || 
        Date().timeIntervalSince(lastResendTime) < Design.resendCooldown ||
        resendAttempts >= Design.maxResendAttempts
    }
    
    /// Returns the current user's email for display
    var userEmail: String {
        authManager.currentUser?.email ?? "your email"
    }
    
    /// Returns time remaining until next resend is allowed
    var resendCooldownRemaining: TimeInterval {
        max(0, Design.resendCooldown - Date().timeIntervalSince(lastResendTime))
    }
    
    /// Returns remaining resend attempts
    var resendAttemptsRemaining: Int {
        max(0, Design.maxResendAttempts - resendAttempts)
    }
    
    /// Returns whether resend limit has been reached
    var hasReachedResendLimit: Bool {
        resendAttempts >= Design.maxResendAttempts
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Public Interface
    
    /// Check email verification status
    func checkVerificationStatus() {
        // Prevent spam checking
        guard !isCheckStatusDisabled else {
            showInfoAlert("Please Wait", "Please wait a moment before checking again.")
            return
        }
        
        isCheckingStatus = true
        lastStatusCheck = Date()
        
        authManager.reloadUser { [weak self] success in
            DispatchQueue.main.async {
                self?.isCheckingStatus = false
                
                if success {
                    if self?.authManager.isEmailVerified == true {
                        // Verification successful - navigation will be handled by MainView
                        self?.handleVerificationSuccess()
                    } else {
                        self?.handleVerificationPending()
                    }
                } else {
                    self?.showErrorAlert("Check Failed", "Failed to check verification status. Please try again.")
                }
            }
        }
    }
    
    /// Resend verification email
    func resendVerificationEmail() {
        // Check if resend is allowed
        guard !isResendDisabled else {
            if hasReachedResendLimit {
                showErrorAlert("Limit Reached", "You've reached the maximum number of verification emails. Please contact support if you need assistance.")
            } else {
                let remaining = Int(resendCooldownRemaining)
                showInfoAlert("Please Wait", "You can resend another email in \(remaining) seconds.")
            }
            return
        }
        
        isResendingEmail = true
        lastResendTime = Date()
        resendAttempts += 1
        
        authManager.sendVerificationEmail { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isResendingEmail = false
                
                if success {
                    self?.handleResendSuccess()
                } else {
                    // Rollback attempt count on failure
                    self?.resendAttempts -= 1
                    let errorMessage = error ?? "An unknown error occurred. Please try again."
                    self?.showErrorAlert("Resend Failed", errorMessage)
                }
            }
        }
    }
    
    /// Handle sign out action
    func signOut() {
        authManager.signOut()
        resetState()
    }
    
    /// Reset all states
    func resetState() {
        isCheckingStatus = false
        isResendingEmail = false
        showAlert = false
        alertTitle = ""
        alertMessage = ""
        lastStatusCheck = Date.distantPast
        lastResendTime = Date.distantPast
        resendAttempts = 0
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Private Methods
    
    private func handleVerificationSuccess() {
        showSuccessAlert("Verified!", "Your email has been successfully verified. Welcome to SipLocal!")
        print("✅ Email verification successful for: \(userEmail)")
    }
    
    private func handleVerificationPending() {
        showInfoAlert("Not Verified Yet", "Your email has not been verified yet. Please check your inbox and spam folder, or resend the verification email.")
        print("⏳ Email verification still pending for: \(userEmail)")
    }
    
    private func handleResendSuccess() {
        let remainingAttempts = resendAttemptsRemaining
        let message = remainingAttempts > 0 
            ? "A new verification email has been sent to \(userEmail). Please check your inbox and spam folder. You have \(remainingAttempts) resend attempts remaining."
            : "A new verification email has been sent to \(userEmail). This was your final resend attempt."
        
        showSuccessAlert("Email Sent", message)
        print("✅ Verification email resent to: \(userEmail) (Attempt \(resendAttempts)/\(Design.maxResendAttempts))")
    }
    
    private func showSuccessAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
        
        // Auto-hide success message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.successDisplayDuration) {
            if self.alertTitle == title {
                self.showAlert = false
            }
        }
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
        
        print("❌ Email verification error: \(message)")
    }
    
    private func showInfoAlert(_ title: String, _ message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
        
        // Auto-hide info message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            if self.alertTitle == title && self.alertMessage == message {
                self.showAlert = false
            }
        }
    }
}

// MARK: - Helper Extensions

extension EmailVerificationViewModel {
    
    /// Returns formatted cooldown time for UI display
    var formattedCooldownTime: String {
        let remaining = Int(resendCooldownRemaining)
        if remaining <= 0 {
            return ""
        } else if remaining < 60 {
            return "\(remaining)s"
        } else {
            let minutes = remaining / 60
            let seconds = remaining % 60
            return "\(minutes)m \(seconds)s"
        }
    }
    
    /// Returns status message for resend button
    var resendButtonStatusMessage: String {
        if hasReachedResendLimit {
            return "Resend limit reached"
        } else if resendCooldownRemaining > 0 {
            return "Wait \(formattedCooldownTime)"
        } else {
            return "Resend Email (\(resendAttemptsRemaining) left)"
        }
    }
    
    /// Returns whether to show resend status message
    var shouldShowResendStatus: Bool {
        hasReachedResendLimit || resendCooldownRemaining > 0
    }
}
