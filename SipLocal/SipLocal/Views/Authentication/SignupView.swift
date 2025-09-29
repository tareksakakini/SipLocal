
//
//  SignupView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Signup View

/// User registration screen with comprehensive form validation
/// Features username availability checking and real-time validation feedback
struct SignupView: View {
    @State private var isPasswordVisible = false
    @State private var isConfirmPasswordVisible = false
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthenticationManager
    
    // MARK: - ViewModel
    @StateObject private var viewModel = SignupViewModel(authManager: AuthenticationManager())
    
    // MARK: - Design Constants
    
    private enum Design {
        static let cardCornerRadius: CGFloat = 20
        static let fieldCornerRadius: CGFloat = 12
        static let buttonHeight: CGFloat = 50
        static let buttonCornerRadius: CGFloat = 25
        static let formSpacing: CGFloat = 20
        static let sectionSpacing: CGFloat = 28
        static let headerSpacing: CGFloat = 8
        static let accentHeight: CGFloat = 6
        static let shadowRadius: CGFloat = 24
        static let shadowY: CGFloat = 8
        
        static let coffeeBrown = Color(red: 0.396, green: 0.263, blue: 0.129)
        static let accentGradient = LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.9, green: 0.85, blue: 0.8), 
                Color(red: 0.7, green: 0.6, blue: 0.5)
            ]), 
            startPoint: .leading, 
            endPoint: .trailing
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6).ignoresSafeArea()
            
            VStack {
                Spacer(minLength: 40)
                
                signupCard
                
                Spacer()
            }
        }
        .onChange(of: viewModel.username) { _, newValue in
            viewModel.handleUsernameChange(newValue)
        }
        .alert(isPresented: $viewModel.showError) {
            Alert(
                title: Text(viewModel.signupSuccess ? "Success" : "Error"), 
                message: Text(viewModel.errorMessage), 
                dismissButton: .default(Text("OK")) {
                    if viewModel.signupSuccess {
                        dismiss()
                    }
                }
            )
        }
        .onAppear {
            viewModel.updateAuthManager(authManager)
        }
    }
    
    // MARK: - View Components
    
    private var signupCard: some View {
        VStack(spacing: 0) {
            accentHeader
            
            VStack(spacing: Design.sectionSpacing) {
                headerSection
                formFields
                signupButton
                loginLink
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(Design.cardCornerRadius)
        .shadow(color: Color(.black).opacity(0.08), radius: Design.shadowRadius, x: 0, y: Design.shadowY)
        .padding(.horizontal, 16)
    }
    
    private var accentHeader: some View {
        Rectangle()
            .fill(Design.accentGradient)
            .frame(height: Design.accentHeight)
            .clipShape(RoundedRectangle(cornerRadius: Design.fieldCornerRadius, style: .continuous))
            .padding(.horizontal, 24)
            .padding(.top, 2)
    }
    
    private var headerSection: some View {
        VStack(spacing: Design.headerSpacing) {
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
    }
    
    private var formFields: some View {
        VStack(spacing: Design.formSpacing) {
            CustomTextField(
                iconName: "person.fill", 
                placeholder: "Full Name", 
                text: $viewModel.fullName, 
                autocapitalization: .words
            )
            
            CustomTextField(
                iconName: "at", 
                placeholder: "Username", 
                text: $viewModel.username, 
                status: viewModel.usernameStatus
            )
            
            CustomTextField(
                iconName: "envelope.fill", 
                placeholder: "Email", 
                text: $viewModel.email, 
                keyboardType: .emailAddress
            )
            
            CustomSecureField(
                iconName: "lock.fill", 
                placeholder: "Password", 
                text: $viewModel.password, 
                isVisible: $isPasswordVisible
            )
            
            CustomSecureField(
                iconName: "lock.fill", 
                placeholder: "Confirm Password", 
                text: $viewModel.confirmPassword, 
                isVisible: $isConfirmPasswordVisible
            )
        }
    }
    
    private var signupButton: some View {
        Button(action: { viewModel.signUp() }) {
            HStack {
                if viewModel.isLoading {
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
            .frame(height: Design.buttonHeight)
            .background(Design.coffeeBrown)
            .cornerRadius(Design.buttonCornerRadius)
            .shadow(color: Design.coffeeBrown.opacity(0.4), radius: 10, x: 0, y: 5)
        }
        .disabled(viewModel.isSignupButtonDisabled)
        .opacity(viewModel.signupButtonOpacity)
    }
    
    private var loginLink: some View {
        NavigationLink(destination: LoginView()) {
            Text("Already have an account? Login")
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundColor(.blue)
                .underline()
        }
        .padding(.bottom, 8)
    }
    
}

// MARK: - Reusable Components

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

// MARK: - Previews

#Preview {
    NavigationStack {
        SignupView()
            .environmentObject(AuthenticationManager())
    }
} 
