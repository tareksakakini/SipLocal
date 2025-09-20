/**
 * SignupViewModel.swift
 * SipLocal
 *
 * ViewModel for SignupView following MVVM architecture.
 * Handles registration logic, form validation, and username availability checking.
 *
 * ## Responsibilities
 * - **Registration Logic**: User signup operations with comprehensive validation
 * - **Username Validation**: Real-time username availability checking with debouncing
 * - **Form Validation**: Multi-field validation with password matching
 * - **State Management**: Loading states, error handling, and success feedback
 * - **User Feedback**: Real-time validation feedback and error messages
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Debouncing**: Optimized API calls for username checking
 * - **Validation**: Client-side form validation with immediate feedback
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - Username Status

/// Represents the current status of username availability checking
enum UsernameStatus {
    case none, checking, available, unavailable
    
    var message: String {
        switch self {
        case .none:
            return ""
        case .checking:
            return "Checking availability..."
        case .available:
            return "Username is available ✓"
        case .unavailable:
            return "Username is already taken"
        }
    }
    
    var color: Color {
        switch self {
        case .none:
            return .secondary
        case .checking:
            return .orange
        case .available:
            return .green
        case .unavailable:
            return .red
        }
    }
}

// MARK: - SignupViewModel

/**
 * ViewModel for SignupView
 * 
 * Manages registration logic, form validation, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class SignupViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var fullName: String = ""
    @Published var username: String = ""
    @Published var email: String = ""
    @Published var password: String = ""
    @Published var confirmPassword: String = ""
    @Published var usernameStatus: UsernameStatus = .none
    @Published var isLoading: Bool = false
    @Published var errorMessage: String = ""
    @Published var showError: Bool = false
    @Published var signupSuccess: Bool = false
    
    // MARK: - Private State
    private var usernameCheckTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Design Constants
    private enum Design {
        static let usernameCheckDebounceDelay: Double = 0.5
        static let minPasswordLength: Int = 6
        static let errorDisplayDuration: Double = 5.0
        static let successDisplayDuration: Double = 3.0
    }
    
    // MARK: - Computed Properties
    
    /// Validates the entire form and returns true if all fields are valid
    var isFormValid: Bool {
        !fullName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= Design.minPasswordLength &&
        isEmailValid &&
        usernameStatus == .available
    }
    
    /// Validates email format
    var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    /// Validates password strength
    var isPasswordValid: Bool {
        password.count >= Design.minPasswordLength
    }
    
    /// Validates password confirmation
    var isPasswordConfirmationValid: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
    
    /// Returns the opacity for the signup button based on form validity
    var signupButtonOpacity: Double {
        isFormValid ? 1.0 : 0.6
    }
    
    /// Returns whether the signup button should be disabled
    var isSignupButtonDisabled: Bool {
        !isFormValid || isLoading || usernameStatus != .available
    }
    
    /// Returns validation message for full name field
    var fullNameValidationMessage: String {
        if fullName.isEmpty {
            return ""
        } else if fullName.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
            return "Full name must be at least 2 characters"
        } else {
            return ""
        }
    }
    
    /// Returns validation message for username field
    var usernameValidationMessage: String {
        if username.isEmpty {
            return ""
        } else if username.count < 3 {
            return "Username must be at least 3 characters"
        } else if username.contains(" ") {
            return "Username cannot contain spaces"
        } else {
            return usernameStatus.message
        }
    }
    
    /// Returns validation message for email field
    var emailValidationMessage: String {
        if email.isEmpty {
            return ""
        } else if !isEmailValid {
            return "Please enter a valid email address"
        } else {
            return ""
        }
    }
    
    /// Returns validation message for password field
    var passwordValidationMessage: String {
        if password.isEmpty {
            return ""
        } else if !isPasswordValid {
            return "Password must be at least \(Design.minPasswordLength) characters"
        } else {
            return ""
        }
    }
    
    /// Returns validation message for password confirmation field
    var passwordConfirmationValidationMessage: String {
        if confirmPassword.isEmpty {
            return ""
        } else if !isPasswordConfirmationValid {
            return "Passwords do not match"
        } else {
            return ""
        }
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        setupUsernameDebouncing()
    }
    
    deinit {
        usernameCheckTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Handle signup action
    func signUp() {
        // Final validation checks
        guard usernameStatus == .available else {
            showErrorMessage("Username is already taken. Please choose another one.")
            return
        }
        
        guard isFormValid else {
            showErrorMessage("Please ensure all fields are filled correctly and passwords match.")
            return
        }
        
        // Set loading state
        isLoading = true
        errorMessage = ""
        showError = false
        
        // Create user data
        let userData = UserData(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        
        // Perform signup
        authManager.signUp(email: email, password: password, userData: userData) { [weak self] success, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if success {
                    self?.handleSignupSuccess()
                } else {
                    let errorText = error ?? "An error occurred during sign up. Please try again."
                    self?.showErrorMessage(errorText)
                }
            }
        }
    }
    
    /// Handle username text changes with debouncing
    func handleUsernameChange(_ newValue: String) {
        username = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Reset status if empty
        if username.isEmpty {
            usernameStatus = .none
            return
        }
        
        // Basic validation first
        if username.count < 3 {
            usernameStatus = .none
            return
        }
        
        if username.contains(" ") {
            usernameStatus = .none
            return
        }
        
        // Set checking status immediately for better UX
        usernameStatus = .checking
    }
    
    /// Clear all form fields and reset state
    func clearForm() {
        fullName = ""
        username = ""
        email = ""
        password = ""
        confirmPassword = ""
        usernameStatus = .none
        errorMessage = ""
        showError = false
        isLoading = false
        signupSuccess = false
        usernameCheckTask?.cancel()
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
    }
    
    // MARK: - Private Methods
    
    private func setupUsernameDebouncing() {
        $username
            .debounce(for: .seconds(Design.usernameCheckDebounceDelay), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                Task { @MainActor in
                    await self?.checkUsernameAvailability(newValue)
                }
            }
            .store(in: &cancellables)
    }
    
    private func checkUsernameAvailability(_ username: String) async {
        // Cancel any existing check
        usernameCheckTask?.cancel()
        
        // Don't check if username is empty or too short
        guard !username.isEmpty, username.count >= 3, !username.contains(" ") else {
            usernameStatus = .none
            return
        }
        
        // Only check if currently in checking state (prevents duplicate calls)
        guard usernameStatus == .checking else { return }
        
        usernameCheckTask = Task {
            // Perform the availability check
            let isAvailable = await withCheckedContinuation { continuation in
                authManager.checkUsernameAvailability(username: username) { isAvailable in
                    continuation.resume(returning: isAvailable)
                }
            }
            
            // Update status if task wasn't cancelled and username hasn't changed
            if !Task.isCancelled && self.username == username {
                await MainActor.run {
                    self.usernameStatus = isAvailable ? .available : .unavailable
                }
            }
        }
        
        await usernameCheckTask?.value
    }
    
    private func handleSignupSuccess() {
        signupSuccess = true
        errorMessage = "Account created successfully! Welcome to SipLocal!"
        showError = true  // Use the same alert system but with success message
        
        // Auto-hide success message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.successDisplayDuration) {
            if self.errorMessage.contains("Welcome to SipLocal!") {
                self.showError = false
            }
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
        
        // Auto-hide error after specified duration
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.errorDisplayDuration) {
            if self.errorMessage == message {  // Only hide if it's the same message
                self.showError = false
            }
        }
    }
}

// MARK: - Validation Extensions

extension SignupViewModel {
    
    /// Returns the color for username status indicator
    var usernameStatusColor: Color {
        usernameStatus.color
    }
    
    /// Returns whether username field should show validation UI
    var shouldShowUsernameValidation: Bool {
        !username.isEmpty && username.count >= 3
    }
    
    /// Returns whether email field should show validation UI
    var shouldShowEmailValidation: Bool {
        !email.isEmpty
    }
    
    /// Returns whether password field should show validation UI
    var shouldShowPasswordValidation: Bool {
        !password.isEmpty
    }
    
    /// Returns whether password confirmation field should show validation UI
    var shouldShowPasswordConfirmationValidation: Bool {
        !confirmPassword.isEmpty
    }
}
