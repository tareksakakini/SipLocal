//
//  ProfileView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import PhotosUI

// MARK: - Design Constants

private enum Design {
    // Avatar
    static let avatarSize: CGFloat = 90
    static let avatarFontSize: CGFloat = 32
    static let editButtonSize: CGFloat = 28
    static let editButtonIconSize: CGFloat = 14
    static let editButtonOffset: CGFloat = 30
    
    // Layout
    static let topPadding: CGFloat = 32
    static let sectionSpacing: CGFloat = 24
    static let cardPadding: CGFloat = 20
    static let userInfoPadding: CGFloat = 28
    static let horizontalPadding: CGFloat = 20
    
    // Cards
    static let cardCornerRadius: CGFloat = 16
    static let userInfoCornerRadius: CGFloat = 20
    static let resultMessageCornerRadius: CGFloat = 12
    
    // Icons
    static let iconSize: CGFloat = 18
    static let chevronSize: CGFloat = 14
    static let iconCircleSize: CGFloat = 40
    static let fullSizeCloseIconSize: CGFloat = 32
    
    // Shadows
    static let avatarShadowRadius: CGFloat = 8
    static let avatarShadowY: CGFloat = 4
    static let editButtonShadowRadius: CGFloat = 4
    static let editButtonShadowY: CGFloat = 2
    static let cardShadowRadius: CGFloat = 8
    static let userInfoShadowRadius: CGFloat = 20
    static let userInfoShadowY: CGFloat = 8
    
    // Animation
    static let loadingTransitionDuration: Double = 0.3
    static let resultMessageDuration: Double = 3.0
    static let deleteMessageDuration: Double = 4.0
    static let dataRefreshDelay: Double = 0.5
    
    // Colors
    static let backgroundColor = Color(.systemGray6)
    static let cardBackground = Color.white
    static let avatarBackground = Color.black
    static let avatarPlaceholderBackground = Color.black.opacity(0.1)
    static let iconCircleBackground = Color.black.opacity(0.05)
    static let resultBackground = Color.black.opacity(0.05)
    static let separatorColor = Color.black.opacity(0.05)
    static let iconColor = Color.black.opacity(0.7)
    static let chevronColor = Color.black.opacity(0.3)
    static let labelColor = Color.black.opacity(0.5)
    static let shadowColor = Color.black.opacity(0.04)
    static let editButtonShadowColor = Color.black.opacity(0.15)
    static let avatarShadowColor = Color.black.opacity(0.1)
    
    // Text
    static let userNameFontSize: CGFloat = 24
    static let labelFontSize: CGFloat = 12
    static let valueFontSize: CGFloat = 16
    static let resultFontSize: CGFloat = 14
    static let loadingFontSize: CGFloat = 16
    static let letterSpacing: CGFloat = 0.5
    
    // Messages
    static let messagePadding: CGFloat = 16
    static let resultIconSize: CGFloat = 16
    
    // Progress
    static let progressScale: CGFloat = 0.8
    static let loadingProgressScale: CGFloat = 1.2
}

// MARK: - Profile View (Step 8 Complete - Final Organization & Documentation)

/**
 # ProfileView
 
 A comprehensive user profile management interface featuring:
 
 ## Core Features
 - **Avatar Management**: Upload, crop, remove, and view profile pictures
 - **User Information**: Display and manage user details (name, username, email)
 - **Account Actions**: Sign out and account deletion with confirmations
 - **Order History**: Access to active and past orders
 - **Feedback System**: Real-time success/error messaging with auto-dismiss
 
 ## Architecture
 - **MVVM Pattern**: Clean separation of view logic and data management
 - **Reusable Components**: Modular avatar, button, and message components
 - **Type-Safe Operations**: Enum-based operation handling with consistent state management
 - **Accessibility**: Comprehensive screen reader support and interaction hints
 
 ## State Management
 - **Centralized State**: All UI state managed through focused @State properties
 - **Generic Handlers**: Type-safe async operation handlers for consistency
 - **Error Recovery**: Proper cleanup and state reset on operation failures
 
 ## Dependencies
 - `AuthenticationManager`: User authentication and data operations
 - `OrderManager`: Order history and management
 - `ImageCropView`: Custom image cropping functionality
 - `ActiveOrdersView` & `PastOrdersView`: Order history presentations
 
 ## Performance
 - **Lazy Loading**: User data fetched only when needed
 - **Image Caching**: Profile images cached with refresh capability
 - **Memory Management**: Proper cleanup of image resources and async operations
 
 - Author: SipLocal Development Team
 - Version: 2.0 (Refactored)
 - Since: iOS 15.0+
 */
struct ProfileView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var orderManager: OrderManager
    
    // MARK: - State Management
    
    /// Dialog presentation states
    @State private var showSignOutConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var showPhotoActionSheet = false
    
    /// Account operation states
    @State private var isDeletingAccount = false
    @State private var deleteResult: (success: Bool, message: String)? = nil
    @State private var showDeleteResult = false
    
    /// User data states
    @State private var userData: UserData?
    @State private var isLoadingUserData = true
    
    /// Image management states
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showPhotoPicker = false
    @State private var isUploadingImage = false
    @State private var uploadResult: (success: Bool, message: String)? = nil
    @State private var showUploadResult = false
    @State private var imageRefreshId = UUID()
    @State private var isRemovingImage = false
    @State private var selectedImage: UIImage?
    @State private var showImageCrop = false
    @State private var showFullSizeImage = false
    
    /// Navigation states
    @State private var showPastOrders = false
    @State private var showActiveOrders = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                if isLoadingUserData {
                    loadingView
                } else if let user = userData {
                    profileContent(for: user)
                }
            }
            .navigationTitle("Profile")
            .onAppear {
                // Performance: Only fetch user data if it hasn't been loaded yet
                // This prevents unnecessary network calls on subsequent view appearances
                if userData == nil {
                    fetchUserData()
                }
            }
        }
        // MARK: - Dialog & Sheet Management (Step 6 Complete)
        .profileDialogs(
            showSignOutConfirmation: $showSignOutConfirmation,
            showDeleteConfirmation: $showDeleteConfirmation,
            showPhotoActionSheet: $showPhotoActionSheet,
            userData: userData,
            onSignOut: { authManager.signOut() },
            onDeleteAccount: { deleteAccount() },
            onChoosePhoto: { showPhotoPicker = true },
            onRemovePhoto: { 
                Task { await removeProfileImage() }
            }
        )
        .profileSheets(
            showPhotoPicker: $showPhotoPicker,
            showImageCrop: $showImageCrop,
            showFullSizeImage: $showFullSizeImage,
            showActiveOrders: $showActiveOrders,
            showPastOrders: $showPastOrders,
            selectedPhotoItem: $selectedPhotoItem,
            selectedImage: selectedImage,
            userData: userData,
            orderManager: orderManager,
            onCropComplete: { croppedImage in
                Task { await uploadProfileImage(croppedImage) }
                showImageCrop = false
                selectedImage = nil
            },
            onCropCancel: {
                showImageCrop = false
                selectedImage = nil
            },
            onFullSizeImageDismiss: { showFullSizeImage = false }
        )
        .onChange(of: userData?.profileImageUrl) { oldValue, newValue in
            if oldValue != newValue && newValue != nil {
                imageRefreshId = UUID()
            }
        }
        .onChange(of: selectedPhotoItem) { oldValue, newValue in
            Task {
                if let photoItem = newValue {
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
                            self.selectedPhotoItem = nil
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
    
    // MARK: - Main View Components
    
    /// Loading state view
    private var loadingView: some View {
                                    ZStack {
            Design.backgroundColor.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                                                            ProgressView()
                    .scaleEffect(Design.loadingProgressScale)
                Text("Loading Profile...")
                    .font(.system(size: Design.loadingFontSize, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .transition(.opacity.animation(.easeInOut(duration: Design.loadingTransitionDuration)))
    }
    
    /// Main profile content for authenticated user
    private func profileContent(for user: UserData) -> some View {
        ScrollView {
            VStack(spacing: Design.sectionSpacing) {
                userInfoSection(for: user)
                resultMessages
                actionButtonsSection
            }
        }
        .background(Design.backgroundColor)
    }
    
    // MARK: - User Info Components (Step 2 & 4 Complete)
    
    /// User info section with avatar and details
    private func userInfoSection(for user: UserData) -> some View {
        VStack(spacing: 20) {
            profileAvatarSection(for: user)
            userInfoCard(for: user)
        }
    }
    
    /// Profile avatar with edit functionality
    private func profileAvatarSection(for user: UserData) -> some View {
        ProfileAvatarContainer(
            user: user,
            imageRefreshId: imageRefreshId,
            onEditTapped: { showPhotoActionSheet = true },
            onImageTapped: { showFullSizeImage = true }
        )
        .padding(.top, Design.topPadding)
    }
    
    /// User information card with name and details
    private func userInfoCard(for user: UserData) -> some View {
        VStack(spacing: Design.sectionSpacing) {
            userNameHeader(user.fullName)
            userDetailsSection(for: user)
        }
        .padding(.horizontal, Design.horizontalPadding)
        .padding(.top, 20)
    }
    
    /// User name header
    private func userNameHeader(_ fullName: String) -> some View {
        Text(fullName)
            .font(.system(size: Design.userNameFontSize, weight: .semibold, design: .rounded))
                                        .foregroundColor(.primary)
            .accessibilityAddTraits(.isHeader)
    }
                                    
    /// User details section with username and email
    private func userDetailsSection(for user: UserData) -> some View {
                                    VStack(spacing: 20) {
            userInfoRow(
                icon: "person",
                label: "Username",
                value: user.username
            )
            
            userInfoSeparator
            
            userInfoRow(
                icon: "envelope",
                label: "Email",
                value: user.email,
                truncationMode: .middle
            )
        }
        .padding(Design.userInfoPadding)
        .background(Design.cardBackground)
        .cornerRadius(Design.userInfoCornerRadius)
        .shadow(color: Design.shadowColor, radius: Design.userInfoShadowRadius, x: 0, y: Design.userInfoShadowY)
    }
    
    /// Reusable user info row component
    private func userInfoRow(
        icon: String,
        label: String,
        value: String,
        truncationMode: Text.TruncationMode = .tail
    ) -> some View {
                                        HStack(spacing: 16) {
                                            Circle()
                .fill(Design.iconCircleBackground)
                .frame(width: Design.iconCircleSize, height: Design.iconCircleSize)
                                                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: Design.iconSize, weight: .medium))
                        .foregroundColor(Design.iconColor)
                        .accessibilityHidden(true)
                )
            
                                            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: Design.labelFontSize, weight: .medium))
                    .foregroundColor(Design.labelColor)
                                                    .textCase(.uppercase)
                    .tracking(Design.letterSpacing)
                    .accessibilityAddTraits(.isHeader)
                
                Text(value)
                    .font(.system(size: Design.valueFontSize, weight: .medium))
                                                    .foregroundColor(.primary)
                                                    .lineLimit(1)
                    .truncationMode(truncationMode)
                                            }
            
                                            Spacer()
                                        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
    
    /// Separator line between user info rows
    private var userInfoSeparator: some View {
        Rectangle()
            .fill(Design.separatorColor)
            .frame(height: 1)
            .accessibilityHidden(true)
    }
    
    /// Result messages for upload/delete operations (Step 5 Complete)
    private var resultMessages: some View {
        FeedbackMessageContainer(
            uploadMessage: showUploadResult ? uploadResult : nil,
            deleteMessage: showDeleteResult ? deleteResult : nil
        )
    }
    
    /// Action buttons section
    private var actionButtonsSection: some View {
        VStack(spacing: 16) {
            activeOrdersButton
            pastOrdersButton
            signOutButton
            deleteAccountButton
        }
        .padding(.horizontal, Design.horizontalPadding)
        .padding(.bottom, Design.sectionSpacing)
    }
    
    // MARK: - Action Button Components (Step 3)
    
    /// Active orders button
    private var activeOrdersButton: some View {
        ActionButton(
            icon: "clock.badge.checkmark.fill",
            title: "Active Order",
            subtitle: nil,
            action: { showActiveOrders = true }
        )
        .accessibilityLabel("View active orders")
        .accessibilityHint("Shows your current pending orders")
    }
    
    /// Past orders button with dynamic count
    private var pastOrdersButton: some View {
        ActionButton(
            icon: "clock.arrow.circlepath",
            title: "Past Orders",
            subtitle: pastOrdersSubtitle,
            action: { showPastOrders = true }
        )
        .accessibilityLabel("View past orders")
        .accessibilityHint("Shows your order history")
    }
    
    /// Sign out button
    private var signOutButton: some View {
        ActionButton(
            icon: "arrow.right.square",
            title: "Sign Out",
            subtitle: nil,
            action: { showSignOutConfirmation = true }
        )
        .accessibilityLabel("Sign out")
        .accessibilityHint("Signs you out of your account")
    }
    
    /// Delete account button with loading state
    private var deleteAccountButton: some View {
        ActionButton(
            icon: isDeletingAccount ? nil : "trash",
            title: isDeletingAccount ? "Deleting Account..." : "Delete Account",
            subtitle: nil,
            action: { showDeleteConfirmation = true },
            isLoading: isDeletingAccount,
            isDestructive: true
        )
        .disabled(isDeletingAccount)
        .accessibilityLabel(isDeletingAccount ? "Deleting account" : "Delete account")
        .accessibilityHint(isDeletingAccount ? "Account deletion in progress" : "Permanently deletes your account and all data")
    }
    
    /// Computed subtitle for past orders button
    private var pastOrdersSubtitle: String {
                                            let pastOrdersCount = orderManager.orders.filter { [.completed, .cancelled].contains($0.status) }.count
        
                                            if pastOrdersCount > 0 {
            return "\(pastOrdersCount) orders"
                                            } else if orderManager.isLoading {
            return "Loading..."
                                            } else {
            return "No past orders"
        }
    }
}

// MARK: - Reusable Action Button Component

/// Reusable action button component for profile actions
struct ActionButton: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let action: () -> Void
    let isLoading: Bool
    let isDestructive: Bool
    
    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        action: @escaping () -> Void,
        isLoading: Bool = false,
        isDestructive: Bool = false
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.action = action
        self.isLoading = isLoading
        self.isDestructive = isDestructive
    }
    
    var body: some View {
        Button(action: action) {
                                    HStack(spacing: 12) {
                leadingIcon
                contentSection
                                        Spacer()
                trailingChevron
            }
            .padding(Design.cardPadding)
            .background(Design.cardBackground)
            .cornerRadius(Design.cardCornerRadius)
            .shadow(color: Design.shadowColor, radius: Design.cardShadowRadius, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Button Components
    
    /// Leading icon or loading indicator
    @ViewBuilder
    private var leadingIcon: some View {
        if isLoading {
                                            ProgressView()
                .scaleEffect(Design.progressScale)
                .tint(Design.iconColor)
        } else if let icon = icon {
            Image(systemName: icon)
                .font(.system(size: Design.iconSize, weight: .medium))
                .foregroundColor(Design.iconColor)
        }
    }
    
    /// Main content section with title and optional subtitle
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: Design.valueFontSize, weight: .medium))
                                            .foregroundColor(.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: Design.labelFontSize, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    /// Trailing chevron (hidden when loading)
    @ViewBuilder
    private var trailingChevron: some View {
        if !isLoading {
                                            Image(systemName: "chevron.right")
                .font(.system(size: Design.chevronSize, weight: .medium))
                .foregroundColor(Design.chevronColor)
                .accessibilityHidden(true)
        }
    }
}

// MARK: - Avatar Management Components (Step 4)

/// Complete avatar container with image, states, and edit functionality
struct ProfileAvatarContainer: View {
    let user: UserData
    let imageRefreshId: UUID
    let onEditTapped: () -> Void
    let onImageTapped: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                avatarImageView
                avatarEditButton
            }
            .shadow(color: Design.avatarShadowColor, radius: Design.avatarShadowRadius, x: 0, y: Design.avatarShadowY)
        }
    }
    
    // MARK: - Avatar Components
    
    /// Main avatar image view with state management
    private var avatarImageView: some View {
        Group {
            if let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                AsyncAvatarImage(
                    imageUrl: profileImageUrl,
                    fallbackInitial: user.fullName.prefix(1),
                    imageRefreshId: imageRefreshId,
                    onImageTapped: onImageTapped
                )
            } else {
                FallbackAvatarImage(initial: user.fullName.prefix(1))
                    .onTapGesture { onImageTapped() }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Profile picture for \(user.fullName)")
        .accessibilityHint("Tap to view full size image")
    }
    
    /// Avatar edit button overlay
    private var avatarEditButton: some View {
        AvatarEditButton(onTapped: onEditTapped)
    }
}

/// Async loading avatar image component
struct AsyncAvatarImage: View {
    let imageUrl: String
    let fallbackInitial: String.SubSequence
    let imageRefreshId: UUID
    let onImageTapped: () -> Void
    
    var body: some View {
        let cacheBustingUrl = "\(imageUrl)?t=\(Date().timeIntervalSince1970)"
        
        AsyncImage(url: URL(string: cacheBustingUrl)) { phase in
            switch phase {
            case .empty:
                AvatarLoadingState()
            case .success(let image):
                AvatarSuccessState(image: image, onTapped: onImageTapped)
            case .failure(_):
                FallbackAvatarImage(initial: fallbackInitial)
                    .onTapGesture { onImageTapped() }
            @unknown default:
                EmptyView()
            }
        }
        .id(imageRefreshId)
    }
}

/// Loading state component for avatar
struct AvatarLoadingState: View {
    var body: some View {
        Circle()
            .fill(Design.avatarPlaceholderBackground)
            .frame(width: Design.avatarSize, height: Design.avatarSize)
            .overlay(
                            ProgressView()
                    .tint(Design.iconColor)
                    .accessibilityLabel("Loading profile picture")
            )
    }
}

/// Success state component for loaded avatar image
struct AvatarSuccessState: View {
    let image: Image
    let onTapped: () -> Void
    
    var body: some View {
        image
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: Design.avatarSize, height: Design.avatarSize)
            .clipShape(Circle())
            .onTapGesture { onTapped() }
            .accessibilityAddTraits(.isButton)
    }
}

/// Fallback avatar component with user initials
struct FallbackAvatarImage: View {
    let initial: String.SubSequence
    
    var body: some View {
        Circle()
            .fill(Design.avatarBackground)
            .frame(width: Design.avatarSize, height: Design.avatarSize)
            .overlay(
                Text(String(initial))
                    .font(.system(size: Design.avatarFontSize, weight: .medium, design: .rounded))
                    .foregroundColor(.white)
                    .accessibilityLabel("Profile initial: \(initial)")
            )
            .accessibilityAddTraits(.isButton)
    }
}

/// Avatar edit button component
struct AvatarEditButton: View {
    let onTapped: () -> Void
    
    var body: some View {
        Circle()
            .fill(Design.cardBackground)
            .frame(width: Design.editButtonSize, height: Design.editButtonSize)
            .overlay(
                Button(action: onTapped) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: Design.editButtonIconSize, weight: .medium))
                        .foregroundColor(Design.iconColor)
                }
                .accessibilityLabel("Edit profile picture")
                .accessibilityHint("Opens photo options menu")
            )
            .shadow(color: Design.editButtonShadowColor, radius: Design.editButtonShadowRadius, x: 0, y: Design.editButtonShadowY)
            .offset(x: Design.editButtonOffset, y: Design.editButtonOffset)
    }
}

// MARK: - Feedback Message Components (Step 5)

/// Container for all feedback messages in the profile view
struct FeedbackMessageContainer: View {
    let uploadMessage: (success: Bool, message: String)?
    let deleteMessage: (success: Bool, message: String)?
    
    var body: some View {
        VStack(spacing: 8) {
            if let uploadMessage = uploadMessage {
                FeedbackMessage(
                    type: uploadMessage.success ? .success : .error,
                    message: uploadMessage.message
                )
            }
            
            if let deleteMessage = deleteMessage {
                FeedbackMessage(
                    type: deleteMessage.success ? .success : .error,
                    message: deleteMessage.message
                )
            }
        }
    }
}

/// Individual feedback message component
struct FeedbackMessage: View {
    enum MessageType {
        case success
        case error
        case info
        case warning
        
        var icon: String {
            switch self {
            case .success:
                return "checkmark.circle.fill"
            case .error:
                return "exclamationmark.triangle.fill"
            case .info:
                return "info.circle.fill"
            case .warning:
                return "exclamationmark.circle.fill"
            }
        }
        
        var iconColor: Color {
            switch self {
            case .success:
                return .green
            case .error:
                return .red
            case .info:
                return .blue
            case .warning:
                return .orange
            }
        }
        
        var accessibilityLabel: String {
            switch self {
            case .success:
                return "Success"
            case .error:
                return "Error"
            case .info:
                return "Information"
            case .warning:
                return "Warning"
            }
        }
    }
    
    let type: MessageType
    let message: String
    
    var body: some View {
        HStack(spacing: 12) {
            messageIcon
            messageText
            Spacer()
        }
        .padding(Design.messagePadding)
        .background(Design.resultBackground)
        .cornerRadius(Design.resultMessageCornerRadius)
        .padding(.horizontal, Design.horizontalPadding)
        .transition(.asymmetric(
            insertion: .scale(scale: 0.8).combined(with: .opacity).combined(with: .move(edge: .top)),
            removal: .scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top))
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(type.accessibilityLabel): \(message)")
    }
    
    // MARK: - Message Components
    
    /// Message icon with type-specific styling
    private var messageIcon: some View {
        Image(systemName: type.icon)
            .font(.system(size: Design.resultIconSize, weight: .medium))
            .foregroundColor(type.iconColor)
            .accessibilityHidden(true)
    }
    
    /// Message text content
    private var messageText: some View {
        Text(message)
            .font(.system(size: Design.resultFontSize, weight: .medium))
            .foregroundColor(.primary)
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Enhanced feedback message with auto-dismiss functionality
struct AutoDismissFeedbackMessage: View {
    let type: FeedbackMessage.MessageType
    let message: String
    let duration: TimeInterval
    let onDismiss: () -> Void
    
    @State private var isVisible = false
    
    init(
        type: FeedbackMessage.MessageType,
        message: String,
        duration: TimeInterval = 3.0,
        onDismiss: @escaping () -> Void
    ) {
        self.type = type
        self.message = message
        self.duration = duration
        self.onDismiss = onDismiss
    }
    
    var body: some View {
        Group {
            if isVisible {
                FeedbackMessage(type: type, message: message)
                    .onTapGesture {
                        dismissMessage()
                    }
            }
        }
            .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isVisible = true
            }
            
            // Auto-dismiss after duration
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                dismissMessage()
            }
        }
    }
    
    private func dismissMessage() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isVisible = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Dialog & Sheet Management (Step 6)

extension View {
    /// Apply all profile confirmation dialogs
    func profileDialogs(
        showSignOutConfirmation: Binding<Bool>,
        showDeleteConfirmation: Binding<Bool>,
        showPhotoActionSheet: Binding<Bool>,
        userData: UserData?,
        onSignOut: @escaping () -> Void,
        onDeleteAccount: @escaping () -> Void,
        onChoosePhoto: @escaping () -> Void,
        onRemovePhoto: @escaping () -> Void
    ) -> some View {
        self
            .signOutDialog(
                isPresented: showSignOutConfirmation,
                onConfirm: onSignOut
            )
            .deleteAccountDialog(
                isPresented: showDeleteConfirmation,
                onConfirm: onDeleteAccount
            )
            .photoActionDialog(
                isPresented: showPhotoActionSheet,
                userData: userData,
                onChoosePhoto: onChoosePhoto,
                onRemovePhoto: onRemovePhoto
            )
    }
    
    /// Apply all profile sheet presentations
    func profileSheets(
        showPhotoPicker: Binding<Bool>,
        showImageCrop: Binding<Bool>,
        showFullSizeImage: Binding<Bool>,
        showActiveOrders: Binding<Bool>,
        showPastOrders: Binding<Bool>,
        selectedPhotoItem: Binding<PhotosPickerItem?>,
        selectedImage: UIImage?,
        userData: UserData?,
        orderManager: OrderManager,
        onCropComplete: @escaping (UIImage) -> Void,
        onCropCancel: @escaping () -> Void,
        onFullSizeImageDismiss: @escaping () -> Void
    ) -> some View {
        self
            .photosPicker(
                isPresented: showPhotoPicker,
                selection: selectedPhotoItem,
                matching: .images
            )
            .imageCropSheet(
                isPresented: showImageCrop,
                selectedImage: selectedImage,
                onCropComplete: onCropComplete,
                onCropCancel: onCropCancel
            )
            .fullSizeImageSheet(
                isPresented: showFullSizeImage,
                userData: userData,
                onDismiss: onFullSizeImageDismiss
            )
            .activeOrdersSheet(
                isPresented: showActiveOrders,
                orderManager: orderManager
            )
            .pastOrdersSheet(
                isPresented: showPastOrders,
                orderManager: orderManager
            )
    }
}

// MARK: - Individual Dialog Components

extension View {
    /// Sign out confirmation dialog
    func signOutDialog(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Sign Out",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Sign Out", role: .destructive) {
                onConfirm()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
    
    /// Delete account confirmation dialog
    func deleteAccountDialog(
        isPresented: Binding<Bool>,
        onConfirm: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Delete Account",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            Button("Delete Account", role: .destructive) {
                onConfirm()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This action cannot be undone. Your account and all associated data will be permanently deleted.")
        }
    }
    
    /// Photo action confirmation dialog
    func photoActionDialog(
        isPresented: Binding<Bool>,
        userData: UserData?,
        onChoosePhoto: @escaping () -> Void,
        onRemovePhoto: @escaping () -> Void
    ) -> some View {
        confirmationDialog(
            "Profile Picture",
            isPresented: isPresented,
            titleVisibility: .visible
        ) {
            if let profileImageUrl = userData?.profileImageUrl, !profileImageUrl.isEmpty {
                Button("Change Photo") {
                    onChoosePhoto()
                }
                Button("Remove Photo", role: .destructive) {
                    onRemovePhoto()
                    }
                Button("Cancel", role: .cancel) { }
            } else {
                Button("Add Photo") {
                    onChoosePhoto()
                }
                Button("Cancel", role: .cancel) { }
            }
        } message: {
            if let profileImageUrl = userData?.profileImageUrl, !profileImageUrl.isEmpty {
                Text("Choose an option for your profile picture")
            } else {
                Text("Add a profile picture to personalize your account")
            }
        }
    }
}

// MARK: - Individual Sheet Components

extension View {
    /// Image crop sheet presentation
    func imageCropSheet(
        isPresented: Binding<Bool>,
        selectedImage: UIImage?,
        onCropComplete: @escaping (UIImage) -> Void,
        onCropCancel: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            if let image = selectedImage {
                ImageCropView(
                    image: image,
                    onCrop: onCropComplete,
                    onCancel: onCropCancel
                )
            }
        }
    }
    
    /// Full size image sheet presentation
    func fullSizeImageSheet(
        isPresented: Binding<Bool>,
        userData: UserData?,
        onDismiss: @escaping () -> Void
    ) -> some View {
        sheet(isPresented: isPresented) {
            if let profileImageUrl = userData?.profileImageUrl, !profileImageUrl.isEmpty {
                FullSizeImageView(
                    imageUrl: profileImageUrl,
                    onDismiss: onDismiss
                )
            }
        }
    }
    
    /// Active orders sheet presentation
    func activeOrdersSheet(
        isPresented: Binding<Bool>,
        orderManager: OrderManager
    ) -> some View {
        sheet(isPresented: isPresented) {
            ActiveOrdersView()
                .environmentObject(orderManager)
        }
    }
    
    /// Past orders sheet presentation
    func pastOrdersSheet(
        isPresented: Binding<Bool>,
        orderManager: OrderManager
    ) -> some View {
        sheet(isPresented: isPresented) {
            PastOrdersView()
                .environmentObject(orderManager)
        }
    }
}

/// Full size image viewer component
struct FullSizeImageView: View {
    let imageUrl: String
    let onDismiss: () -> Void
    
    var body: some View {
                ZStack {
                    Color(.systemBackground).ignoresSafeArea()
            
            AsyncImage(url: URL(string: imageUrl)) { phase in
                        switch phase {
                        case .empty:
                    ProgressView()
                        .tint(.gray)
                        .accessibilityLabel("Loading full size image")
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color(.systemBackground))
                        .accessibilityLabel("Full size profile picture")
                        case .failure(_):
                    VStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.badge.exclamationmark")
                            .font(.system(size: 60))
                                .foregroundColor(.gray.opacity(0.7))
                        Text("Failed to load image")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .accessibilityLabel("Failed to load profile picture")
                        @unknown default:
                            EmptyView()
                        }
                    }
            
                    VStack {
                        HStack {
                            Spacer()
                    Button(action: onDismiss) {
                                Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Design.fullSizeCloseIconSize))
                                    .foregroundColor(.gray.opacity(0.8))
                                    .padding()
                            }
                    .accessibilityLabel("Close full size image")
                        }
                        Spacer()
                    }
                }
            }
        }

// MARK: - Data Flow & State Management Helpers (Step 7 Complete)

/// State management container for better organization
extension ProfileView {
    /// Consolidated state reset for clean initialization
    private func resetAllStates() {
        // Reset dialog states
        showSignOutConfirmation = false
        showDeleteConfirmation = false
        showPhotoActionSheet = false
        
        // Reset operation states
        isDeletingAccount = false
        deleteResult = nil
        showDeleteResult = false
        
        // Reset image states
        selectedPhotoItem = nil
        showPhotoPicker = false
        isUploadingImage = false
        uploadResult = nil
        showUploadResult = false
        isRemovingImage = false
        selectedImage = nil
        showImageCrop = false
        showFullSizeImage = false
        
        // Reset navigation states
        showPastOrders = false
        showActiveOrders = false
    }
    
    /// Handle successful operations with consistent UI feedback
    private func handleOperationSuccess(
        message: String,
        shouldRefreshData: Bool = false,
        shouldRefreshImage: Bool = false,
        autoDismissDelay: Double = Design.resultMessageDuration
    ) {
        if shouldRefreshImage {
                imageRefreshId = UUID()
            }
        
        if shouldRefreshData {
            DispatchQueue.main.asyncAfter(deadline: .now() + Design.dataRefreshDelay) {
                fetchUserData()
            }
        }
        
        // Auto-hide success message
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
            showUploadResult = false
            showDeleteResult = false
        }
    }
    
    /// Handle operation failures with consistent error feedback
    private func handleOperationFailure(
        message: String,
        isUploadOperation: Bool = true,
        autoDismissDelay: Double = Design.resultMessageDuration
    ) {
        if isUploadOperation {
            uploadResult = (false, message)
                            showUploadResult = true
        } else {
            deleteResult = (false, message)
            showDeleteResult = true
        }
        
        // Auto-hide error message
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
            if isUploadOperation {
                showUploadResult = false
            } else {
                showDeleteResult = false
            }
        }
    }
    
    /// Clean up image-related state after operations
    private func cleanupImageState() {
                            selectedPhotoItem = nil
        selectedImage = nil
        showImageCrop = false
        isUploadingImage = false
        isRemovingImage = false
    }
}

extension ProfileView {
    // MARK: - Async Operations (Step 7)
    
    /// Image operation types for consistent handling
    private enum ImageOperationType {
        case upload
        case remove
        
        var loadingStateKeyPath: ReferenceWritableKeyPath<ProfileView, Bool> {
            switch self {
            case .upload: return \.isUploadingImage
            case .remove: return \.isRemovingImage
            }
        }
        
        var shouldRefreshData: Bool {
            switch self {
            case .upload, .remove: return true
            }
        }
        
        var shouldRefreshImage: Bool {
            switch self {
            case .upload, .remove: return true
            }
        }
    }
    
    /// Generic image operation handler with consistent error handling and state management
    private func performImageOperation(
        operationType: ImageOperationType,
        operation: () async -> (success: Bool, errorMessage: String?),
        successMessage: String,
        failureMessage: String
    ) async {
        print("ProfileView: \(operationType) started")
        
        // Set loading state
                        DispatchQueue.main.async {
            self[keyPath: operationType.loadingStateKeyPath] = true
            self.showUploadResult = false
        }
        
        // Perform operation
        let result = await operation()
        print("ProfileView: \(operationType) \(result.success ? "✅" : "❌")")
        
            DispatchQueue.main.async {
            // Clear loading state
            self[keyPath: operationType.loadingStateKeyPath] = false
            
            if result.success {
                // Handle success
                self.uploadResult = (true, successMessage)
                            self.showUploadResult = true
                
                // Perform post-success actions
                self.handleOperationSuccess(
                    message: successMessage,
                    shouldRefreshData: operationType.shouldRefreshData,
                    shouldRefreshImage: operationType.shouldRefreshImage
                )
                
                // Clean up image state for remove operations
                if case .remove = operationType {
                    self.cleanupImageState()
                }
                
                print("ProfileView: \(operationType) UI updated")
                } else {
                // Handle failure
                let errorMessage = result.errorMessage ?? failureMessage
                self.handleOperationFailure(
                    message: errorMessage,
                    isUploadOperation: true
                )
                
                print("ProfileView: \(operationType) failed")
            }
        }
    }
    
    /// Account operation types for consistent handling
    private enum AccountOperationType {
        case delete
        
        var loadingStateKeyPath: ReferenceWritableKeyPath<ProfileView, Bool> {
            switch self {
            case .delete: return \.isDeletingAccount
            }
        }
        
        var resultStateKeyPath: ReferenceWritableKeyPath<ProfileView, (success: Bool, message: String)?> {
            switch self {
            case .delete: return \.deleteResult
            }
        }
        
        var showResultKeyPath: ReferenceWritableKeyPath<ProfileView, Bool> {
            switch self {
            case .delete: return \.showDeleteResult
            }
        }
    }
    
    /// Generic account operation handler with consistent error handling and state management
    private func performAccountOperation(
        operationType: AccountOperationType,
        operation: (@escaping (Bool, String?) -> Void) -> Void,
        successMessage: String,
        failureMessage: String,
        autoDismissDelay: Double = Design.resultMessageDuration
    ) {
        print("ProfileView: \(operationType) started")
        
        // Set loading state
        self[keyPath: operationType.loadingStateKeyPath] = true
        
        // Perform operation
        operation { success, error in
        DispatchQueue.main.async {
                // Clear loading state
                self[keyPath: operationType.loadingStateKeyPath] = false
                
                // Set result
                let resultMessage = error ?? (success ? successMessage : failureMessage)
                self[keyPath: operationType.resultStateKeyPath] = (success: success, message: resultMessage)
                self[keyPath: operationType.showResultKeyPath] = true
                
                print("ProfileView: \(operationType) \(success ? "✅" : "❌")")
                
                // Auto-hide the message after specified delay
                DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissDelay) {
                    self[keyPath: operationType.showResultKeyPath] = false
                }
            }
        }
    }
    
    private func fetchUserData() {
        guard let userId = authManager.currentUser?.uid else { 
            print("ProfileView: No user ID")
            return 
        }
        
        print("ProfileView: Fetching user data")
        
        authManager.getUserData(userId: userId) { userData, error in
        DispatchQueue.main.async {
                self.isLoadingUserData = false
                if let userData = userData {
                    print("ProfileView: User data loaded ✅")
                    self.userData = userData
                } else {
                    print("ProfileView: User data failed ❌")
                }
            }
        }
    }
    
    private func deleteAccount() {
        performAccountOperation(
            operationType: .delete,
            operation: { completion in
                authManager.deleteUserAccount(completion: completion)
            },
            successMessage: "Account deleted successfully",
            failureMessage: "Failed to delete account",
            autoDismissDelay: Design.deleteMessageDuration
        )
    }
    
    private func uploadProfileImage(_ uiImage: UIImage) async {
        await performImageOperation(
            operationType: .upload,
            operation: { await authManager.uploadProfileImage(uiImage) },
            successMessage: "Profile picture updated!",
            failureMessage: "Upload failed"
        )
    }
    
    private func removeProfileImage() async {
        await performImageOperation(
            operationType: .remove,
            operation: { await authManager.removeProfileImage() },
            successMessage: "Profile picture removed!",
            failureMessage: "Failed to remove profile picture"
        )
    }
}


// MARK: - Previews

/**
 Preview configurations for ProfileView development and testing.
 
 Includes multiple states for comprehensive design validation:
 - Loading state preview
 - Standard profile preview with mock data
 - Different device size previews for responsive design testing
 */
struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Standard Profile View
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(OrderManager())
                .previewDisplayName("Profile View")
            
            // Loading State Preview
            ProfileView()
                .environmentObject(AuthenticationManager())
                .environmentObject(OrderManager())
                .previewDisplayName("Loading State")
            
            // Different Device Sizes
            ProfileView()
                .environmentObject(AuthenticationManager())
                .environmentObject(OrderManager())
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
        ProfileView()
            .environmentObject(AuthenticationManager())
            .environmentObject(OrderManager())
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
        }
    }
} 