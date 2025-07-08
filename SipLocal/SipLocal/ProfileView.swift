import SwiftUI
import PhotosUI

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var isDeletingAccount = false
    @State private var deleteResult: (success: Bool, message: String)? = nil
    @State private var showDeleteResult = false
    @State private var userData: UserData?
    @State private var isLoadingUserData = true
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var isUploadingImage = false
    @State private var uploadResult: (success: Bool, message: String)? = nil
    @State private var showUploadResult = false
    @State private var imageRefreshId = UUID()
    @State private var isRemovingImage = false
    @State private var showPhotoActionSheet = false
    @State private var selectedImage: UIImage?
    @State private var showImageCrop = false
    @State private var showFullSizeImage = false
    
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
                                    if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                                        // Add cache busting parameter to force refresh
                                        let cacheBustingUrl = "\(profileImageUrl)?t=\(Date().timeIntervalSince1970)"
                                        AsyncImage(url: URL(string: cacheBustingUrl)) { phase in
                                            switch phase {
                                            case .empty:
                                                Circle()
                                                    .fill(Color.black.opacity(0.1))
                                                    .frame(width: 90, height: 90)
                                                    .overlay(
                                                        ProgressView()
                                                            .tint(.black.opacity(0.6))
                                                    )
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 90, height: 90)
                                                    .clipShape(Circle())
                                                    .onTapGesture {
                                                        showFullSizeImage = true
                                                    }
                                            case .failure(_):
                                                Circle()
                                                    .fill(Color.black)
                                                    .frame(width: 90, height: 90)
                                                    .overlay(
                                                        Text(user.fullName.prefix(1))
                                                            .font(.system(size: 32, weight: .medium, design: .rounded))
                                                            .foregroundColor(.white)
                                                    )
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                        .id(imageRefreshId)
                                    } else {
                                        Circle()
                                            .fill(Color.black)
                                            .frame(width: 90, height: 90)
                                            .overlay(
                                                Text(user.fullName.prefix(1))
                                                    .font(.system(size: 32, weight: .medium, design: .rounded))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                    
                                    // Edit button
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 28, height: 28)
                                        .overlay(
                                            Button(action: {
                                                showPhotoActionSheet = true
                                            }) {
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.black.opacity(0.7))
                                            }
                                        )
                                        .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
                                        .offset(x: 30, y: 30)
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
                        
                        // Upload result message
                        if showUploadResult, let result = uploadResult {
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
        .confirmationDialog(
            "Profile Picture",
            isPresented: $showPhotoActionSheet,
            titleVisibility: .visible
        ) {
            if let user = userData, let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                // User has a profile picture - show change and remove options
                Button("Change Photo") {
                    showPhotoPicker = true
                }
                
                Button("Remove Photo", role: .destructive) {
                    Task {
                        await removeProfileImage()
                    }
                }
                
                Button("Cancel", role: .cancel) { }
            } else {
                // User has no profile picture - show add option
                Button("Add Photo") {
                    showPhotoPicker = true
                }
                
                Button("Cancel", role: .cancel) { }
            }
        } message: {
            if let user = userData, let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                Text("Choose an option for your profile picture")
            } else {
                Text("Add a profile picture to personalize your account")
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .sheet(isPresented: $showImageCrop) {
            if let image = selectedImage {
                ImageCropView(
                    image: image,
                    onCrop: { croppedImage in
                        Task {
                            await uploadProfileImage(croppedImage)
                        }
                        showImageCrop = false
                        selectedImage = nil
                    },
                    onCancel: {
                        showImageCrop = false
                        selectedImage = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showFullSizeImage) {
            if let profileImageUrl = userData?.profileImageUrl, !profileImageUrl.isEmpty {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
                    AsyncImage(url: URL(string: profileImageUrl)) { phase in
                        switch phase {
                        case .empty:
                            ProgressView().tint(.gray)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                        case .failure(_):
                            Image(systemName: "person.crop.circle.badge.exclam")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .foregroundColor(.gray.opacity(0.7))
                        @unknown default:
                            EmptyView()
                        }
                    }
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: { showFullSizeImage = false }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding()
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .onChange(of: userData?.profileImageUrl) { oldValue, newValue in
            // Force image refresh when profile URL changes
            if oldValue != newValue && newValue != nil {
                imageRefreshId = UUID()
            }
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let photoItem = newValue {
                    // Convert PhotosPickerItem to UIImage for cropping
                    do {
                        guard let imageData = try await photoItem.loadTransferable(type: Data.self),
                              let uiImage = UIImage(data: imageData) else {
                            uploadResult = (false, "Failed to process image")
                            showUploadResult = true
                            selectedPhotoItem = nil
                            return
                        }
                        
                        DispatchQueue.main.async {
                            self.selectedImage = uiImage
                            self.showImageCrop = true
                            self.selectedPhotoItem = nil // Clear the picker selection
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self.uploadResult = (false, "Failed to load image")
                            self.showUploadResult = true
                            self.selectedPhotoItem = nil
                        }
                    }
                }
            }
        }
    }
    
    private func fetchUserData() {
        print("ProfileView: Fetching user data...")
        guard let userId = authManager.currentUser?.uid else { 
            print("ProfileView: No user ID available")
            return 
        }
        
        print("ProfileView: Fetching data for user ID: \(userId)")
        
        authManager.getUserData(userId: userId) { userData, error in
            DispatchQueue.main.async {
                self.isLoadingUserData = false
                if let userData = userData {
                    print("ProfileView: User data received - Name: \(userData.fullName)")
                    print("ProfileView: Profile image URL: \(userData.profileImageUrl ?? "nil")")
                    self.userData = userData
                } else {
                    print("ProfileView: Failed to fetch user data - Error: \(error ?? "unknown")")
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
    
    private func uploadProfileImage(_ uiImage: UIImage) async {
        print("Starting profile image upload...")
        isUploadingImage = true
        showUploadResult = false
        
        // Upload the image
        let result = await authManager.uploadProfileImage(uiImage)
        print("Upload result: success=\(result.success), error=\(result.errorMessage ?? "none")")
        
        DispatchQueue.main.async {
            self.isUploadingImage = false
            self.uploadResult = (result.success, result.success ? "Profile picture updated!" : result.errorMessage ?? "Upload failed")
            self.showUploadResult = true
            
            // Force image refresh on successful upload
            if result.success {
                print("Upload successful, refreshing UI...")
                self.imageRefreshId = UUID()
                
                // Add a small delay to ensure Firestore has updated
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.fetchUserData()
                }
                
                // Also trigger a UI refresh by updating the userData directly if possible
                if let currentUserData = self.userData {
                    // We don't have the new URL yet, but we can trigger a refresh
                    // The fetchUserData call above will get the actual URL
                    print("Triggering UI refresh...")
                }
            }
            
            // Auto-hide the message after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showUploadResult = false
            }
        }
    }
    
    private func removeProfileImage() async {
        isRemovingImage = true
        showUploadResult = false
        
        let result = await authManager.removeProfileImage()
        
        DispatchQueue.main.async {
            self.isRemovingImage = false
            self.uploadResult = (result.success, result.success ? "Profile picture removed!" : result.errorMessage ?? "Failed to remove profile picture")
            self.showUploadResult = true
            
            // Force image refresh on successful removal
            if result.success {
                self.imageRefreshId = UUID()
                // Refresh user data to update the UI
                self.fetchUserData()
                // Clear the selected photo item to ensure PhotosPicker works for next selection
                self.selectedPhotoItem = nil
            }
            
            // Auto-hide the message after a few seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                self.showUploadResult = false
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