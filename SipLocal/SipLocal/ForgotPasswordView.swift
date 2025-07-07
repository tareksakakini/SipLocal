import SwiftUI

struct ForgotPasswordView: View {
    @State private var email = ""
    @State private var isLoading = false
    @State private var showAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            VStack {
                Spacer()
                
                VStack(spacing: 30) {
                    VStack(spacing: 8) {
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
                    
                    CustomTextField(iconName: "envelope.fill", placeholder: "Email", text: $email, keyboardType: .emailAddress)
                    
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
                        .frame(height: 55)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.purple]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(28)
                        .shadow(color: .purple.opacity(0.15), radius: 10, x: 0, y: 5)
                    }
                    .disabled(isLoading || email.isEmpty)
                    .opacity(email.isEmpty ? 0.6 : 1.0)
                }
                .padding(30)
                .background(Color(.systemBackground))
                .cornerRadius(30)
                .shadow(color: .black.opacity(0.1), radius: 20, y: 10)
                .padding(.horizontal)
                
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
    
    private func sendResetLink() {
        isLoading = true
        authManager.sendPasswordReset(for: email) { success, error in
            isLoading = false
            if success {
                alertTitle = "Success"
                alertMessage = "A password reset link has been sent to your email."
            } else {
                alertTitle = "Error"
                alertMessage = error ?? "An unknown error occurred."
            }
            showAlert = true
        }
    }
}

struct ForgotPasswordView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ForgotPasswordView()
                .environmentObject(AuthenticationManager())
        }
    }
} 