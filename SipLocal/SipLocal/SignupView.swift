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
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    @State private var usernameStatus: UsernameStatus = .none
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var signupSuccess = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
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
                                .fontDesign(.rounded)
                                .foregroundColor(.primary)
                            Text("Create your account to discover local flavors")
                                .font(.subheadline)
                                .fontDesign(.rounded)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.top, 18)
                        
                        // Form
                        VStack(spacing: 20) {
                            CustomTextField(iconName: "person.fill", placeholder: "Full Name", text: $fullName, autocapitalization: .words)
                            CustomTextField(iconName: "at", placeholder: "Username", text: $username, status: usernameStatus)
                            CustomTextField(iconName: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                            CustomSecureField(iconName: "lock.fill", placeholder: "Password", text: $password, isVisible: $isPasswordVisible)
                            CustomSecureField(iconName: "lock.fill", placeholder: "Confirm Password", text: $confirmPassword, isVisible: $isConfirmPasswordVisible)
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
                                        .fontDesign(.rounded)
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
                        NavigationLink(destination: LoginView()) {
                            Text("Already have an account? Login")
                                .font(.subheadline)
                                .fontDesign(.rounded)
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
        .navigationTitle("Sign Up")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: username, perform: { value in
            usernameStatus = .checking
            
            // Debounce logic
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard value == username else { return } // Check if text has changed
                
                authManager.checkUsernameAvailability(username: value) { isAvailable in
                    if isAvailable {
                        usernameStatus = .available
                    } else {
                        usernameStatus = .unavailable
                    }
                }
            }
        })
        .alert(isPresented: $showAlert) {
            Alert(title: Text(signupSuccess ? "Success" : "Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")) {
                if signupSuccess {
                    dismiss()
                }
            })
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
        guard usernameStatus == .available else {
            alertMessage = "Username is already taken. Please choose another one."
            showAlert = true
            return
        }
        
        guard !fullName.isEmpty, !username.isEmpty, !email.isEmpty, !password.isEmpty else {
            alertMessage = "Please fill in all fields"
            showAlert = true
            return
        }
        
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

// MARK: - Reusable Components

enum UsernameStatus {
    case none, checking, available, unavailable
}

struct CustomTextField: View {
    var iconName: String
    var placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: UITextAutocapitalizationType = .none
    var status: UsernameStatus = .none
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.secondary)
            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(autocapitalization)
                .disableAutocorrection(true)
                .fontDesign(.rounded)
                .foregroundColor(.primary)
                .textFieldStyle(PlainTextFieldStyle())
            
            switch status {
            case .checking:
                ProgressView()
            case .available:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .unavailable:
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
            case .none:
                EmptyView()
            }
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

struct CustomSecureField: View {
    let iconName: String
    let placeholder: String
    @Binding var text: String
    @Binding var isVisible: Bool
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.secondary)

            if isVisible {
                TextField(placeholder, text: $text)
                    .disableAutocorrection(true)
                    .fontDesign(.rounded)
                    .foregroundColor(.primary)
                    .textFieldStyle(PlainTextFieldStyle())
            } else {
                SecureField(placeholder, text: $text)
                    .disableAutocorrection(true)
                    .fontDesign(.rounded)
                    .foregroundColor(.primary)
                    .textFieldStyle(PlainTextFieldStyle())
            }

            Button(action: {
                isVisible.toggle()
            }) {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
            }
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

#Preview {
    SignupView()
} 
