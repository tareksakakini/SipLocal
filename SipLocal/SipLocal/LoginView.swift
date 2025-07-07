//
//  LoginView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

struct LoginView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isPasswordVisible = false
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                // Form Container
                VStack(spacing: 30) {
                    // Header
                    VStack(spacing: 8) {
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
                    
                    // Form Fields
                    VStack(spacing: 20) {
                        CustomTextField(iconName: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                        CustomSecureField(iconName: "lock.fill", placeholder: "Password", text: $password, isVisible: $isPasswordVisible)
                    }
                    
                    // Login Button
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
                        .frame(height: 55)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.6)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
                    }
                    .disabled(isLoading)
                }
                .padding(30)
                .background(Color(.systemBackground))
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                .padding(.horizontal)
                
                Spacer()
                
                // Forgot Password
                Button(action: {
                    // TODO: Handle forgot password
                }) {
                    Text("Forgot Password?")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .fontDesign(.rounded)
                        .foregroundColor(.accentColor)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Login")
        .navigationBarHidden(true)
        .alert("Login Failed", isPresented: $showAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private func login() {
        isLoading = true
        authManager.signIn(email: email, password: password) { success, error in
            isLoading = false
            if success {
                // Handled by the listener in the main app view
            } else {
                alertMessage = error ?? "An unknown error occurred."
                showAlert = true
            }
        }
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationManager())
    }
} 