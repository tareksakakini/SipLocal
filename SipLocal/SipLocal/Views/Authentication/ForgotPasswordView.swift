//
//  ForgotPasswordView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Forgot Password View

/// Password recovery screen that sends reset email to users
/// Provides simple email input with validation and feedback
struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Design Constants
    
    private enum Design {
        static let formPadding: CGFloat = 30
        static let formCornerRadius: CGFloat = 30
        static let buttonHeight: CGFloat = 55
        static let buttonCornerRadius: CGFloat = 28
        static let headerSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 30
        
        static let coffeeBrown = Color(red: 0.396, green: 0.263, blue: 0.129)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                resetForm
                
                Spacer()
            }
        }
        .navigationTitle("Forgot Password")
        .navigationBarTitleDisplayMode(.inline)
        .alert(alertTitle, isPresented: $showAlert) {
            Button("OK") {
                if alertTitle == "Success" {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - View Components
    
    private var resetForm: some View {
        VStack(spacing: Design.sectionSpacing) {
            headerSection
            emailField
            resetButton
        }
        .padding(Design.formPadding)
        .background(Color(.systemBackground))
        .cornerRadius(Design.formCornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .padding(.horizontal)
    }
    
    private var headerSection: some View {
        VStack(spacing: Design.headerSpacing) {
            Text("Reset Password")
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
            
            Text("Enter your email to receive a reset link.")
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
    
    private var emailField: some View {
        CustomTextField(
            iconName: "envelope.fill",
            placeholder: "Email",
            text: $email,
            keyboardType: .emailAddress
        )
    }
    
    private var resetButton: some View {
        Button(action: sendResetLink) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Send Reset Link")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .fontDesign(.rounded)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: Design.buttonHeight)
            .background(Design.coffeeBrown)
            .cornerRadius(Design.buttonCornerRadius)
            .shadow(color: Design.coffeeBrown.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .disabled(isLoading || !isEmailValid)
        .opacity(isEmailValid ? 1.0 : 0.6)
    }
    
    // MARK: - Computed Properties
    
    private var isEmailValid: Bool {
        !email.isEmpty && email.contains("@") && email.contains(".")
    }
    
    // MARK: - Actions
    
    private func sendResetLink() {
        guard isEmailValid else { return }
        
        isLoading = true
        authManager.sendPasswordReset(for: email) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    alertTitle = "Success"
                    alertMessage = "A password reset link has been sent to your email. Please check your inbox and follow the instructions."
                } else {
                    alertTitle = "Error"
                    alertMessage = error ?? "An unknown error occurred. Please try again."
                }
                showAlert = true
            }
        }
    }
}

// MARK: - Previews

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ForgotPasswordView()
                .environmentObject(AuthenticationManager())
        }
    }
} 