//
//  SignupView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

struct SignupView: View {
    @State private var fullName = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var signupSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        ZStack {
            // Background - neutral with subtle gradient
            LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 10) {
                        Text("Join SipLocal")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("Create your account to discover local flavors")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 50)
                    
                    // Form
                    VStack(spacing: 20) {
                        // Full Name Field
                        CustomTextField(
                            placeholder: "Full Name",
                            text: $fullName,
                            icon: "person.fill"
                        )
                        
                        // Username Field
                        CustomTextField(
                            placeholder: "Username",
                            text: $username,
                            icon: "at"
                        )
                        
                        // Email Field
                        CustomTextField(
                            placeholder: "Email",
                            text: $email,
                            icon: "envelope.fill",
                            keyboardType: .emailAddress
                        )
                        
                        // Password Field
                        CustomSecureField(
                            placeholder: "Password",
                            text: $password,
                            icon: "lock.fill"
                        )
                        
                        // Confirm Password Field
                        CustomSecureField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            icon: "lock.fill"
                        )
                    }
                    .padding(.horizontal, 30)
                    
                    // Sign Up Button
                    Button(action: {
                        signUp()
                    }) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            } else {
                                Text("Sign Up")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(25)
                        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading || !isFormValid)
                    .opacity(isFormValid ? 1.0 : 0.6)
                    .padding(.horizontal, 30)
                    
                    // Back to Login
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Already have an account? Login")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                            .underline()
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert("Sign Up", isPresented: $showAlert) {
            Button("OK") { 
                if signupSuccess {
                    dismiss()
                }
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private var isFormValid: Bool {
        !fullName.isEmpty &&
        !username.isEmpty &&
        !email.isEmpty &&
        !password.isEmpty &&
        !confirmPassword.isEmpty &&
        password == confirmPassword &&
        password.count >= 6 &&
        email.contains("@")
    }
    
    private func signUp() {
        guard isFormValid else { return }
        
        isLoading = true
        
        let userData = UserData(
            fullName: fullName,
            username: username,
            email: email
        )
        
        authManager.signUp(email: email, password: password, userData: userData) { success, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if success {
                    signupSuccess = true
                    alertMessage = "Account created successfully! Welcome to SipLocal!"
                } else {
                    alertMessage = error ?? "An error occurred during sign up. Please try again."
                }
                
                showAlert = true
            }
        }
    }
}

// Custom TextField Component
struct CustomTextField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    var keyboardType: UIKeyboardType = .default
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

// Custom SecureField Component
struct CustomSecureField: View {
    let placeholder: String
    @Binding var text: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            SecureField(placeholder, text: $text)
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }
}

struct UserData {
    let fullName: String
    let username: String
    let email: String
}

#Preview {
    SignupView()
} 