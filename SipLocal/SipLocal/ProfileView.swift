import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteResult: (success: Bool, message: String)? = nil
    @State private var showDeleteResult = false
    @State private var userData: UserData?
    @State private var isLoadingUserData = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Info Section
                    if let user = userData {
                        VStack(spacing: 20) {
                            // Profile Avatar
                            VStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 90, height: 90)
                                        .overlay(
                                            Text(user.fullName.prefix(1))
                                                .font(.system(size: 32, weight: .medium, design: .rounded))
                                                .foregroundColor(.white)
                                        )
                                }
                                .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                            }
                            .padding(.top, 32)
                            
                            // User Info Card
                            VStack(spacing: 24) {
                                Text(user.fullName)
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .foregroundColor(.primary)
                                
                                VStack(spacing: 20) {
                                    // Username row
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.black.opacity(0.05))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "person")
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.black.opacity(0.7))
                                            )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Username")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.black.opacity(0.5))
                                                .textCase(.uppercase)
                                                .tracking(0.5)
                                            Text(user.username)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                        }
                                        Spacer()
                                    }
                                    
                                    Rectangle()
                                        .fill(Color.black.opacity(0.05))
                                        .frame(height: 1)
                                    
                                    // Email row
                                    HStack(spacing: 16) {
                                        Circle()
                                            .fill(Color.black.opacity(0.05))
                                            .frame(width: 40, height: 40)
                                            .overlay(
                                                Image(systemName: "envelope")
                                                    .font(.system(size: 18, weight: .medium))
                                                    .foregroundColor(.black.opacity(0.7))
                                            )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Email")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.black.opacity(0.5))
                                                .textCase(.uppercase)
                                                .tracking(0.5)
                                            Text(user.email)
                                                .font(.system(size: 16, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                    }
                                }
                                .padding(28)
                                .background(Color.white)
                                .cornerRadius(20)
                                .shadow(color: Color.black.opacity(0.04), radius: 20, x: 0, y: 8)
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                        }
                        
                        // Account deletion result message
                        if showDeleteResult, let result = deleteResult {
                            HStack {
                                Image(systemName: result.success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(result.success ? .black.opacity(0.7) : .black.opacity(0.7))
                                Text(result.message)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color.black.opacity(0.05))
                            .cornerRadius(12)
                            .padding(.horizontal, 20)
                            .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Action Buttons Section
                        VStack(spacing: 16) {
                            // Sign Out Button
                            Button(action: {
                                showSignOutConfirmation = true
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "arrow.right.square")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.black.opacity(0.7))
                                    Text("Sign Out")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.black.opacity(0.3))
                                }
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            }
                            
                            // Delete Account Button
                            Button(action: {
                                showDeleteConfirmation = true
                            }) {
                                HStack(spacing: 12) {
                                    if isDeletingAccount {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.black.opacity(0.7))
                                    } else {
                                        Image(systemName: "trash")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(.black.opacity(0.7))
                                    }
                                    Text(isDeletingAccount ? "Deleting Account..." : "Delete Account")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    Spacer()
                                    if !isDeletingAccount {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.black.opacity(0.3))
                                    }
                                }
                                .padding(20)
                                .background(Color.white)
                                .cornerRadius(16)
                                .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
                            }
                            .disabled(isDeletingAccount)
                        }
                        .padding(.horizontal, 20)
                    } else if isLoadingUserData {
                        VStack(spacing: 20) {
                            ProgressView()
                                .scaleEffect(1.2)
                            Text("Loading Profile...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 100)
                    }
                }
            }
            .background(Color(.systemGray6))
            .navigationTitle("Profile")
            .onAppear {
                fetchUserData()
            }
        }
        .confirmationDialog(
            "Sign Out",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog(
            "Delete Account",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                deleteAccount()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. Your account and all associated data will be permanently deleted.")
        }
    }
    
    private func fetchUserData() {
        guard let userId = authManager.currentUser?.uid else { return }
        
        authManager.getUserData(userId: userId) { userData, error in
            DispatchQueue.main.async {
                self.isLoadingUserData = false
                if let userData = userData {
                    self.userData = userData
                }
            }
        }
    }
    
    private func deleteAccount() {
        isDeletingAccount = true
        
        authManager.deleteUserAccount { success, error in
            DispatchQueue.main.async {
                self.isDeletingAccount = false
                self.deleteResult = (success: success, message: error ?? (success ? "Account deleted successfully" : "Failed to delete account"))
                self.showDeleteResult = true
                
                // Auto-hide the message after a few seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    self.showDeleteResult = false
                }
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthenticationManager())
    }
} 