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
            // Background - subtle neutral
            Color(.systemGray6)
                .ignoresSafeArea()
            
            VStack {
                Spacer(minLength: 40)
                
                // Card container
                VStack(spacing: 0) {
                    // Accent header
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [Color.blue, Color.purple]), startPoint: .leading, endPoint: .trailing))
                        .frame(height: 6)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .padding(.horizontal, 24)
                        .padding(.top, 2)
                    
                    VStack(spacing: 28) {
                        // Header
                        VStack(spacing: 8) {
                            Text("Join SipLocal")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("Create your account to discover local flavors")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)
                        
                        // Form
                        VStack(spacing: 16) {
                            CustomTextField(
                                placeholder: "Full Name",
                                text: $fullName,
                                icon: "person.fill"
                            )
                            CustomTextField(
                                placeholder: "Username",
                                text: $username,
                                icon: "at"
                            )
                            CustomTextField(
                                placeholder: "Email",
                                text: $email,
                                icon: "envelope.fill",
                                keyboardType: .emailAddress
                            )
                            CustomSecureField(
                                placeholder: "Password",
                                text: $password,
                                icon: "lock.fill"
                            )
                            CustomSecureField(
                                placeholder: "Confirm Password",
                                text: $confirmPassword,
                                icon: "lock.fill"
                            )
                        }
                        
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
                            .shadow(color: .purple.opacity(0.15), radius: 10, x: 0, y: 5)
                        }
                        .disabled(isLoading || !isFormValid)
                        .opacity(isFormValid ? 1.0 : 0.6)
                        
                        // Back to Login
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Already have an account? Login")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                                .underline()
                        }
                        .padding(.bottom, 8)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
                .background(Color.white)
                .cornerRadius(20)
                .shadow(color: Color(.black).opacity(0.08), radius: 24, x: 0, y: 8)
                .padding(.horizontal, 16)
                
                Spacer()
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
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray3), lineWidth: 1.2)
        )
        .shadow(color: Color(.black).opacity(0.03), radius: 2, x: 0, y: 1)
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
        .padding(14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray3), lineWidth: 1.2)
        )
        .shadow(color: Color(.black).opacity(0.03), radius: 2, x: 0, y: 1)
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