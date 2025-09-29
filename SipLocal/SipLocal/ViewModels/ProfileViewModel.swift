/**
 * ProfileViewModel.swift
 * SipLocal
 *
 * ViewModel for ProfileView following MVVM architecture.
 * Handles profile management, image upload operations, and user data management.
 *
 * ## Responsibilities
 * - **Profile Management**: User profile data loading and updates
 * - **Image Operations**: Avatar upload, cropping, and removal with optimistic updates
 * - **Account Operations**: Account deletion and sign-out functionality
 * - **State Management**: Complex UI state handling for dialogs, sheets, and loading states
 * - **Error Handling**: Comprehensive error management with user feedback
 * - **Navigation Management**: Sheet and dialog presentation state
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected managers
 * - **Async Operations**: Proper async/await handling with error boundaries
 * - **Memory Management**: Proper cleanup and lifecycle management
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import PhotosUI
import Combine

// MARK: - ProfileViewModel

/**
 * ViewModel for ProfileView
 * 
 * Manages profile operations, image handling, and complex UI state.
 * Provides reactive state management and clean separation of concerns.
 */
class ProfileViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    private var orderManager: OrderManager
    
    // MARK: - Published State Properties
    
    // Dialog presentation states
    @Published var showSignOutConfirmation = false
    @Published var showDeleteConfirmation = false
    @Published var showPhotoActionSheet = false
    
    // Account operation states
    @Published var isDeletingAccount = false
    @Published var deleteResult: (success: Bool, message: String)? = nil
    @Published var showDeleteResult = false
    
    // User data states
    @Published var userData: UserData?
    @Published var isLoadingUserData = true
    
    // Image management states
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var showPhotoPicker = false
    @Published var isUploadingImage = false
    @Published var uploadResult: (success: Bool, message: String)? = nil
    @Published var showUploadResult = false
    @Published var imageRefreshId = UUID()
    @Published var isRemovingImage = false
    @Published var selectedImage: UIImage?
    @Published var showImageCrop = false
    @Published var showFullSizeImage = false
    
    // Navigation states
    @Published var showPastOrders = false
    @Published var showActiveOrders = false
    
    // MARK: - Private State
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Design Constants
    private enum Design {
        static let imageUploadTimeout: Double = 30.0
        static let feedbackDisplayDuration: Double = 3.0
        static let imageRefreshDelay: Double = 0.5
        static let maxImageSize: CGFloat = 1024.0
        static let imageCompressionQuality: CGFloat = 0.8
    }
    
    // MARK: - Computed Properties
    
    /// Returns whether any operation is currently in progress
    var isOperationInProgress: Bool {
        isLoadingUserData || isUploadingImage || isRemovingImage || isDeletingAccount
    }
    
    /// Returns the current user's display name
    var displayName: String {
        userData?.fullName ?? "User"
    }
    
    /// Returns the current user's email
    var displayEmail: String {
        userData?.email ?? ""
    }
    
    /// Returns the current user's username
    var displayUsername: String {
        userData?.username ?? ""
    }
    
    /// Returns whether the user has a profile image
    var hasProfileImage: Bool {
        userData?.profileImageUrl != nil && !userData!.profileImageUrl!.isEmpty
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager, orderManager: OrderManager) {
        self.authManager = authManager
        self.orderManager = orderManager
        setupImageHandling()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Fetch user data from the server
    func fetchUserData() {
        isLoadingUserData = true
        
        guard let userId = authManager.currentUser?.uid else { 
            isLoadingUserData = false
            return 
        }
        
        authManager.getUserData(userId: userId) { [weak self] userData, error in
            DispatchQueue.main.async {
                self?.isLoadingUserData = false
                
                if let userData = userData {
                    self?.userData = userData
                } else {
                    print("❌ Failed to fetch user data: \(error ?? "Unknown error")")
                    // Keep existing userData if fetch fails
                }
            }
        }
    }
    
    /// Handle sign out action
    func signOut() {
        authManager.signOut()
        resetAllStates()
    }
    
    /// Handle account deletion
    func deleteAccount() {
        isDeletingAccount = true
        
        // TODO: Implement account deletion in AuthenticationManager
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.isDeletingAccount = false
            
            let message = "Account deletion not implemented yet"
            self.deleteResult = (success: false, message: message)
            self.showDeleteResult = true
            
            // Auto-hide error message
            DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
                self.showDeleteResult = false
            }
        }
    }
    
    /// Handle profile image upload
    func uploadProfileImage(_ image: UIImage) async {
        isUploadingImage = true

        // Compress and resize image
        let processedImage = await processImageForUpload(image)

        // Upload with timeout
        let success = await withTimeout(Design.imageUploadTimeout) {
            await self.performImageUpload(processedImage)
        }

        await MainActor.run {
            self.isUploadingImage = false

            if success == true {
                self.handleImageUploadSuccess()
            } else {
                self.handleImageUploadFailure("Upload timed out or failed")
            }
        }
    }

    /// Handle profile image removal
    func removeProfileImage() async {
        isRemovingImage = true

        let success = await withTimeout(Design.imageUploadTimeout) {
            await self.performImageRemoval()
        }

        await MainActor.run {
            self.isRemovingImage = false

            if success == true {
                self.handleImageRemovalSuccess()
            } else {
                self.handleImageRemovalFailure("Removal timed out or failed")
            }
        }
    }
    
    /// Handle photo picker item selection
    func handlePhotoSelection(_ item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        do {
            if let imageData = try await item.loadTransferable(type: Data.self),
               let image = UIImage(data: imageData) {
                await MainActor.run {
                    self.selectedImage = image
                    self.showImageCrop = true
                    self.selectedPhotoItem = nil
                }
            }
        } catch {
            await MainActor.run {
                self.handleImageUploadFailure("Failed to load selected image")
            }
        }
    }
    
    /// Update dependencies (for environment object injection)
    func updateDependencies(authManager: AuthenticationManager, orderManager: OrderManager) {
        self.authManager = authManager
        self.orderManager = orderManager
    }
    
    /// Reset all states
    func resetAllStates() {
        showSignOutConfirmation = false
        showDeleteConfirmation = false
        showPhotoActionSheet = false
        isDeletingAccount = false
        deleteResult = nil
        showDeleteResult = false
        isUploadingImage = false
        uploadResult = nil
        showUploadResult = false
        isRemovingImage = false
        selectedImage = nil
        showImageCrop = false
        showFullSizeImage = false
        showPastOrders = false
        showActiveOrders = false
        selectedPhotoItem = nil
        showPhotoPicker = false
    }
    
    // MARK: - Private Implementation
    
    private func setupImageHandling() {
        // Watch for profile image URL changes
        $userData
            .compactMap { $0?.profileImageUrl }
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.imageRefreshId = UUID()
            }
            .store(in: &cancellables)
        
        // Handle photo picker selection
        $selectedPhotoItem
            .compactMap { $0 }
            .sink { [weak self] item in
                Task {
                    await self?.handlePhotoSelection(item)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processImageForUpload(_ image: UIImage) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                // Resize if needed
                let resizedImage = ProfileViewModel.resizeImage(image, to: Design.maxImageSize)
                continuation.resume(returning: resizedImage)
            }
        }
    }
    
    private static func resizeImage(_ image: UIImage, to maxSize: CGFloat) -> UIImage {
        let size = image.size
        let aspectRatio = size.width / size.height
        
        var newSize: CGSize
        if size.width > size.height {
            newSize = CGSize(width: maxSize, height: maxSize / aspectRatio)
        } else {
            newSize = CGSize(width: maxSize * aspectRatio, height: maxSize)
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    
    private func performImageUpload(_ image: UIImage) async -> Bool {
        // TODO: Implement uploadProfileImage in AuthenticationManager
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate upload delay
        return false // Placeholder - not implemented yet
    }
    
    private func performImageRemoval() async -> Bool {
        // TODO: Implement removeProfileImage in AuthenticationManager
        try? await Task.sleep(nanoseconds: 1_000_000_000) // Simulate removal delay
        return false // Placeholder - not implemented yet
    }
    
    private func handleImageUploadSuccess() {
        uploadResult = (success: true, message: "Profile image updated successfully!")
        showUploadResult = true
        
        // Refresh user data to get updated image URL
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.imageRefreshDelay) {
            self.fetchUserData()
        }
        
        // Auto-hide success message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            self.showUploadResult = false
        }
    }
    
    private func handleImageUploadFailure(_ message: String) {
        uploadResult = (success: false, message: message)
        showUploadResult = true
        
        // Auto-hide error message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            self.showUploadResult = false
        }
    }
    
    private func handleImageRemovalSuccess() {
        uploadResult = (success: true, message: "Profile image removed successfully!")
        showUploadResult = true
        
        // Update user data to remove image URL
        // TODO: Update UserData to have mutable profileImageUrl
        // userData?.profileImageUrl = nil
        imageRefreshId = UUID()
        
        // Auto-hide success message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            self.showUploadResult = false
        }
    }
    
    private func handleImageRemovalFailure(_ message: String) {
        uploadResult = (success: false, message: message)
        showUploadResult = true
        
        // Auto-hide error message
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            self.showUploadResult = false
        }
    }
    
    private func withTimeout<T>(_ timeout: TimeInterval, operation: @escaping () async -> T) async -> T? {
        return await withTaskGroup(of: T?.self) { group in
            group.addTask {
                await operation()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                return nil
            }
            
            let result = await group.next()
            group.cancelAll()
            return result ?? nil
        }
    }
}

// MARK: - Action Helpers

extension ProfileViewModel {
    
    /// Show sign out confirmation dialog
    func showSignOutDialog() {
        showSignOutConfirmation = true
    }
    
    /// Show delete account confirmation dialog
    func showDeleteDialog() {
        showDeleteConfirmation = true
    }
    
    /// Show photo action sheet
    func showPhotoActions() {
        showPhotoActionSheet = true
    }
    
    /// Show photo picker
    func showPhotoPickerView() {
        showPhotoPicker = true
    }
    
    /// Show image crop view
    func showCropView(with image: UIImage) {
        selectedImage = image
        showImageCrop = true
    }
    
    /// Show full size image view
    func showFullImage() {
        showFullSizeImage = true
    }
    
    /// Show past orders
    func showPastOrdersView() {
        showPastOrders = true
    }
    
    /// Show active orders
    func showActiveOrdersView() {
        showActiveOrders = true
    }
}
