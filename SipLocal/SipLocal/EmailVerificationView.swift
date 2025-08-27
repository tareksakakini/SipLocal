//
//  EmailVerificationView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI

struct EmailVerificationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    
    @State private var isCheckingStatus = false
    @State private var isResendingEmail = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // MARK: - Header
                VStack(spacing: 20) {
                    Image(systemName: "envelope.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(LinearGradient(gradient: Gradient(colors: [Color(red: 0.65, green: 0.4, blue: 0.2), Color(red: 0.45, green: 0.25, blue: 0.1)]), startPoint: .top, endPoint: .bottom))
                    
                    Text("Verify Your Email")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                    
                    VStack {
                        Text("We sent a verification link to:")
                            .foregroundColor(.secondary)
                        
                        Text(authManager.currentUser?.email ?? "your email")
                            .fontWeight(.bold)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    Text("Please check your inbox and click the verification link to continue using the app.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // MARK: - Action Buttons
                VStack(spacing: 15) {
                    // "I've Verified" Button
                    Button(action: checkVerificationStatus) {
                        HStack {
                            if isCheckingStatus {
                                ProgressView()
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("I've Verified My Email")
                            }
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .foregroundColor(.white)
                        .background(LinearGradient(gradient: Gradient(colors: [Color(red: 0.65, green: 0.4, blue: 0.2), Color(red: 0.45, green: 0.25, blue: 0.1)]), startPoint: .leading, endPoint: .trailing))
                        .cornerRadius(28)
                    }
                    .disabled(isCheckingStatus || isResendingEmail)
                    
                    // "Resend Email" Button
                    Button(action: resendVerificationEmail) {
                        HStack {
                            if isResendingEmail {
                                ProgressView()
                                    .tint(Color(red: 0.45, green: 0.25, blue: 0.1))
                            } else {
                                Image(systemName: "arrow.clockwise.circle")
                                Text("Resend Verification Email")
                            }
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 55)
                        .foregroundColor(Color(red: 0.45, green: 0.25, blue: 0.1))
                        .background(.white)
                        .cornerRadius(28)
                        .overlay(
                            RoundedRectangle(cornerRadius: 28)
                                .stroke(LinearGradient(gradient: Gradient(colors: [Color(red: 0.65, green: 0.4, blue: 0.2), Color(red: 0.45, green: 0.25, blue: 0.1)]), startPoint: .leading, endPoint: .trailing), lineWidth: 2)
                        )
                    }
                    .disabled(isCheckingStatus || isResendingEmail)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // MARK: - Sign Out
                Button("Sign Out") {
                    authManager.signOut()
                }
                .foregroundColor(.secondary)
                .padding(.bottom)
            }
            .padding()
        }
        .alert(isPresented: $showAlert) {
            Alert(title: Text(alertTitle), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
    }
    
    // MARK: - Functions
    private func checkVerificationStatus() {
        isCheckingStatus = true
        authManager.reloadUser { success in
            isCheckingStatus = false
            if success && !authManager.isEmailVerified {
                alertTitle = "Not Verified Yet"
                alertMessage = "Your email has not been verified yet. Please check your inbox or resend the email."
                showAlert = true
            }
            // If successful and verified, the MainView will automatically navigate to HomeView.
        }
    }
    
    private func resendVerificationEmail() {
        isResendingEmail = true
        authManager.sendVerificationEmail { success, error in
            isResendingEmail = false
            alertTitle = success ? "Email Sent" : "Error"
            alertMessage = success ? "A new verification email has been sent to your address." : (error ?? "An unknown error occurred.")
            showAlert = true
        }
    }
}

struct EmailVerificationView_Previews: PreviewProvider {
    static var previews: some View {
        EmailVerificationView()
            .environmentObject(AuthenticationManager())
    }
} 