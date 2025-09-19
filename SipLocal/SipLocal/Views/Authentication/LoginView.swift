//
//  LoginView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Login View

/// User login screen with form validation and error handling
struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Design Constants
    
    private enum Design {
        static let formPadding: CGFloat = 30
        static let formCornerRadius: CGFloat = 30
        static let fieldSpacing: CGFloat = 20
        static let buttonHeight: CGFloat = 55
        static let buttonCornerRadius: CGFloat = 28
        static let headerSpacing: CGFloat = 8
        static let sectionSpacing: CGFloat = 30
        static let bottomPadding: CGFloat = 20
        
        static let coffeeBrown = Color(red: 0.396, green: 0.263, blue: 0.129)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                loginForm
                
                Spacer()
                
                forgotPasswordLink
            }
        }
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Login Failed", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    // MARK: - View Components
    
    private var loginForm: some View {
        VStack(spacing: Design.sectionSpacing) {
            headerSection
            formFields
            loginButton
        }
        .padding(Design.formPadding)
        .background(Color(.systemBackground))
        .cornerRadius(Design.formCornerRadius)
        .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
        .padding(.horizontal)
    }
    
    private var headerSection: some View {
        VStack(spacing: Design.headerSpacing) {
            Text("Welcome Back")
                .font(.title)
                .fontWeight(.bold)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
            
            Text("Sign in to your account")
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundColor(.secondary)
        }
    }
    
    private var formFields: some View {
        VStack(spacing: Design.fieldSpacing) {
            CustomTextField(
                iconName: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )
            
            CustomSecureField(
                iconName: "lock.fill",
                placeholder: "Password",
                text: $password,
                isVisible: $isPasswordVisible
            )
        }
    }
    
    private var loginButton: some View {
        Button(action: login) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text("Login")
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
        .disabled(isLoading || !isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
    }
    
    private var forgotPasswordLink: some View {
        NavigationLink(destination: ForgotPasswordView()) {
            Text("Forgot Password?")
                .font(.subheadline)
                .fontWeight(.medium)
                .fontDesign(.rounded)
                .foregroundColor(.accentColor)
        }
        .padding(.bottom, Design.bottomPadding)
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        !email.isEmpty && 
        !password.isEmpty && 
        email.contains("@") && 
        password.count >= 6
    }
    
    // MARK: - Actions
    
    private func login() {
        guard isFormValid else { return }
        
        isLoading = true
        authManager.signIn(email: email, password: password) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    // Navigation handled by MainView listening to auth state changes
                    dismiss()
                } else {
                    alertMessage = error ?? "An unknown error occurred. Please try again."
                    showAlert = true
                }
            }
        }
    }
}

// MARK: - Previews

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            LoginView()
                .environmentObject(AuthenticationManager())
        }
    }
} 