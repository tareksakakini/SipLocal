//
//  EmailVerificationView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

// MARK: - Email Verification View

/// Email verification screen for authenticated but unverified users
/// Provides verification status checking and email resending functionality
struct EmailVerificationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var isCheckingStatus = false
    @State private var isResendingEmail = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    // MARK: - Design Constants
    
    private enum Design {
        static let iconSize: CGFloat = 80
        static let buttonHeight: CGFloat = 55
        static let buttonCornerRadius: CGFloat = 28
        static let emailBoxCornerRadius: CGFloat = 12
        static let sectionSpacing: CGFloat = 30
        static let buttonSpacing: CGFloat = 15
        static let headerSpacing: CGFloat = 20
        static let emailBoxPaddingVertical: CGFloat = 8
        static let emailBoxPaddingHorizontal: CGFloat = 16
        static let strokeWidth: CGFloat = 2
        
        static let coffeeBrown = Color(red: 0.45, green: 0.25, blue: 0.1)
        static let coffeeBrownLight = Color(red: 0.65, green: 0.4, blue: 0.2)
        
        static let coffeeGradient = LinearGradient(
            gradient: Gradient(colors: [coffeeBrownLight, coffeeBrown]),
            startPoint: .top,
            endPoint: .bottom
        )
        
        static let buttonGradient = LinearGradient(
            gradient: Gradient(colors: [coffeeBrownLight, coffeeBrown]),
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    var body: some View {
        ZStack {
            // Background
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: Design.sectionSpacing) {
                Spacer()
                
                headerSection
                actionButtons
                
                Spacer()
                
                signOutButton
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text(alertTitle), 
                message: Text(alertMessage), 
                dismissButton: .default(Text("OK"))
            )
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: Design.headerSpacing) {
            verificationIcon
            titleSection
            emailSection
            instructionText
        }
    }
    
    private var verificationIcon: some View {
        Image(systemName: "envelope.circle.fill")
            .font(.system(size: Design.iconSize))
            .foregroundStyle(Design.coffeeGradient)
    }
    
    private var titleSection: some View {
        Text("Verify Your Email")
            .font(.largeTitle)
            .fontWeight(.bold)
            .fontDesign(.rounded)
    }
    
    private var emailSection: some View {
        VStack {
            Text("We sent a verification link to:")
                .foregroundColor(.secondary)
            
            Text(authManager.currentUser?.email ?? "your email")
                .fontWeight(.bold)
                .padding(.vertical, Design.emailBoxPaddingVertical)
                .padding(.horizontal, Design.emailBoxPaddingHorizontal)
                .background(Color.white)
                .cornerRadius(Design.emailBoxCornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.emailBoxCornerRadius)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    private var instructionText: some View {
        Text("Please check your inbox and click the verification link to continue using the app.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    private var actionButtons: some View {
        VStack(spacing: Design.buttonSpacing) {
            verifyButton
            resendButton
        }
        .padding(.horizontal)
    }
    
    private var verifyButton: some View {
        Button(action: checkVerificationStatus) {
            HStack {
                if isCheckingStatus {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "checkmark.circle")
                    Text("I've Verified My Email")
                }
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: Design.buttonHeight)
            .foregroundColor(.white)
            .background(Design.buttonGradient)
            .cornerRadius(Design.buttonCornerRadius)
        }
        .disabled(isCheckingStatus || isResendingEmail)
    }
    
    private var resendButton: some View {
        Button(action: resendVerificationEmail) {
            HStack {
                if isResendingEmail {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Design.coffeeBrown))
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                    Text("Resend Verification Email")
                }
            }
            .font(.headline.weight(.semibold))
            .frame(maxWidth: .infinity)
            .frame(height: Design.buttonHeight)
            .foregroundColor(Design.coffeeBrown)
            .background(.white)
            .cornerRadius(Design.buttonCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Design.buttonCornerRadius)
                    .stroke(Design.buttonGradient, lineWidth: Design.strokeWidth)
            )
        }
        .disabled(isCheckingStatus || isResendingEmail)
    }
    
    private var signOutButton: some View {
        Button("Sign Out") {
            authManager.signOut()
        }
        .foregroundColor(.secondary)
        .padding(.bottom)
    }
    
    // MARK: - Actions
    
    private func checkVerificationStatus() {
        isCheckingStatus = true
        authManager.reloadUser { success in
            DispatchQueue.main.async {
                isCheckingStatus = false
                if success && !authManager.isEmailVerified {
                    alertTitle = "Not Verified Yet"
                    alertMessage = "Your email has not been verified yet. Please check your inbox or resend the email."
                    showAlert = true
                }
                // If successful and verified, the MainView will automatically navigate to HomeView
            }
        }
    }
    
    private func resendVerificationEmail() {
        isResendingEmail = true
        authManager.sendVerificationEmail { success, error in
            DispatchQueue.main.async {
                isResendingEmail = false
                alertTitle = success ? "Email Sent" : "Error"
                alertMessage = success 
                    ? "A new verification email has been sent to your address. Please check your inbox and spam folder."
                    : (error ?? "An unknown error occurred. Please try again.")
                showAlert = true
            }
        }
    }
}

// MARK: - Previews

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView()
            .environmentObject(AuthenticationManager())
    }
} 