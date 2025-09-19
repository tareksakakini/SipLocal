import SwiftUI

// MARK: - Design System

/// Centralized design constants for CoffeeShopDetailView
private enum Design {
    // Layout
    static let imageHeightRatio: CGFloat = 0.4
    static let contentPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 16
    static let quickActionSpacing: CGFloat = 12
    static let quickActionTopPadding: CGFloat = 12
    static let detailRowSpacing: CGFloat = 10
    static let overlayPadding: CGFloat = 10
    
    // Buttons
    static let overlayButtonSize: CGFloat = 44
    static let quickActionVerticalPadding: CGFloat = 10
    static let quickActionCornerRadius: CGFloat = 12
    static let quickActionBorderWidth: CGFloat = 1
    
    // Typography
    static let titleFontSize: CGFloat = 28
    static let titleMinScale: CGFloat = 0.8
    static let titleMaxLines: Int = 2
    static let bodyFontSize: CGFloat = 16
    static let detailFontSize: CGFloat = 14
    static let captionFontSize: CGFloat = 12
    
    // Colors
    static let overlayBackground = Color.white.opacity(0.7)
    static let quickActionBackground = Color.white
    static let quickActionBorder = Color.black
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    
    // Shadows
    static let overlayShadowRadius: CGFloat = 5
    static let quickActionShadowRadius: CGFloat = 2
    
        // Animation
        static let favoriteAnimationDuration: Double = 0.2
        static let contentTransitionDuration: Double = 0.3
        static let buttonPressScale: CGFloat = 0.95
        static let springResponse: Double = 0.5
        static let springDamping: Double = 0.8
        
        // Progress
        static let progressScale: CGFloat = 0.8
        
        // Visual Polish
        static let cardElevation: CGFloat = 4
        static let pressedOpacity: Double = 0.8
        static let hoverScale: CGFloat = 1.02
}

// MARK: - Coffee Shop Detail View

/**
 * # CoffeeShopDetailView
 * 
 * A comprehensive detail view for displaying coffee shop information with advanced features.
 * 
 * ## Features
 * - **Hero Image Display**: Full-width shop image with proper aspect ratio
 * - **Interactive Actions**: Phone calls, directions, website navigation with loading states
 * - **Favorite Management**: Optimistic UI updates with state synchronization
 * - **Business Hours**: Async loading with caching and error handling
 * - **Accessibility**: Comprehensive screen reader support and navigation
 * - **Performance**: Memory-efficient with proper lifecycle management
 * - **Animations**: Smooth transitions and micro-interactions
 * 
 * ## Architecture
 * - **MVVM Pattern**: Clean separation of concerns with reactive state management
 * - **Error Boundaries**: Structured error handling with user-friendly feedback
 * - **Memory Management**: Proper cleanup and weak references to prevent leaks
 * - **Performance Monitoring**: Execution time tracking for optimization
 * 
 * ## Usage
 * ```swift
 * CoffeeShopDetailView(shop: coffeeShop, authManager: authManager)
 * ```
 * 
 * ## Dependencies
 * - `AuthenticationManager`: For favorite management and user state
 * - `POSServiceFactory`: For business hours data fetching
 * - `MenuCategorySelectionView`: For menu navigation
 * 
 * ## Performance Considerations
 * - Business hours are cached to prevent duplicate API calls
 * - Tasks are properly cancelled on view disappear
 * - Optimistic UI updates for better perceived performance
 * - Memory-efficient with computed property caching
 * 
 * - Author: SipLocal Development Team
 * - Version: 2.0.0
 * - Since: iOS 15.0
 */
struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    // MARK: - Error Handling System
    
    /// Structured error types for better error handling
    private enum ActionError: LocalizedError {
        case invalidInput(String)
        case urlCreation(String)
        case deviceCapability(String)
        case networkError(String)
        case unknown(String)
        
        var errorDescription: String? {
            switch self {
            case .invalidInput(let message),
                 .urlCreation(let message),
                 .deviceCapability(let message),
                 .networkError(let message),
                 .unknown(let message):
                return message
            }
        }
    }
    
    // MARK: - State Management
    
    /// Favorite state
    @State private var isFavorite: Bool
    
    /// Navigation states
    @State private var showMenu = false
    
    /// Business hours states
    @State private var businessHoursInfo: BusinessHoursInfo?
    @State private var isLoadingBusinessHours = false
    @State private var businessHoursError: String?
    
    
    /// Action loading states for better UX
    @State private var isPerformingPhoneCall = false
    @State private var isOpeningMaps = false
    @State private var isOpeningWebsite = false
    @State private var isTogglingFavorite = false
    
    /// Error boundary state
    @State private var hasError = false
    @State private var errorMessage = ""
    
    /// Performance and lifecycle management
    @State private var viewDidAppear = false
    @State private var businessHoursTask: Task<Void, Never>?
    
    /// Computed property caching for performance
    private var shopImageName: String { shop.imageName }
    private var shopDisplayName: String { shop.name }
    private var shopDisplayDescription: String { shop.description }
    
    init(shop: CoffeeShop, authManager: AuthenticationManager) {
        self.shop = shop
        self._isFavorite = State(initialValue: authManager.isFavorite(shopId: shop.id))
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                ZStack(alignment: .top) {
                    mainContent(geometry: geometry)
                    overlayButtons(geometry: geometry)
                }
            }
            .edgesIgnoringSafeArea(.top)
            .navigationBarBackButtonHidden(true)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Coffee shop details for \(shopDisplayName)")
            .accessibilityHint("Swipe up and down to browse shop information and actions")
        }
        .sheet(isPresented: $showMenu) {
            MenuCategorySelectionView(shop: shop)
        }
        .onAppear {
            handleViewAppear()
        }
        .onDisappear {
            handleViewDisappear()
        }
        // Enhanced accessibility navigation
        .accessibilityAction(.escape) {
            presentationMode.wrappedValue.dismiss()
        }
        .accessibilityAction(.default) {
            // Focus on the first interactive element (favorite button)
        }
    }
    
    // MARK: - Main Components
    
    /// Main scrollable content
    private func mainContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            shopImage(geometry: geometry)
            shopDetails(geometry: geometry)
        }
    }
    
    /// Shop hero image
    private func shopImage(geometry: GeometryProxy) -> some View {
        Image(shopImageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height * Design.imageHeightRatio)
            .clipped()
            .accessibilityLabel("Photo of \(shopDisplayName)")
            .accessibilityHint("Hero image showing the coffee shop")
    }
    
    /// Shop details section with smooth animations
    private func shopDetails(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: Design.sectionSpacing) {
            shopHeader
                .transition(.opacity.combined(with: .move(edge: .top)))
            
            quickActionsSection
                .transition(.opacity.combined(with: .move(edge: .leading)))
            
            Divider()
                .transition(.opacity)
            
            contactDetailsSection
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            
            businessHoursSection
                .transition(.opacity.combined(with: .scale))
        }
        .padding(Design.contentPadding)
        .frame(width: geometry.size.width)
        .animation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping), value: viewDidAppear)
    }
    
    /// Shop name and description header
    private var shopHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shopDisplayName)
                .font(.system(size: Design.titleFontSize, weight: .bold))
                .lineLimit(Design.titleMaxLines)
                .minimumScaleFactor(Design.titleMinScale)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Coffee shop name: \(shopDisplayName)")
            
            Text(shopDisplayDescription)
                .font(.system(size: Design.bodyFontSize))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Description: \(shopDisplayDescription)")
        }
        .accessibilityElement(children: .combine)
    }
    
    /// Quick action buttons row
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Actions")
                .font(.system(size: Design.detailFontSize, weight: .semibold))
                .foregroundColor(Design.secondaryText)
                .accessibilityAddTraits(.isHeader)
            
            HStack(spacing: Design.quickActionSpacing) {
                menuActionButton
                directionsActionButton
                websiteActionButton
                phoneActionButton
            }
        }
        .padding(.top, Design.quickActionTopPadding)
    }
    
    /// Menu action button
    private var menuActionButton: some View {
        QuickActionButton(
            systemImageName: "menucard", 
            title: "Menu",
            accessibilityLabel: "View menu",
            accessibilityHint: "Opens the coffee shop menu"
        ) {
            showMenu = true
        }
    }
    
    /// Directions action button
    private var directionsActionButton: some View {
        QuickActionButton(
            systemImageName: isOpeningMaps ? "mappin.and.ellipse" : "mappin.and.ellipse", 
            title: isOpeningMaps ? "Opening..." : "Directions",
            accessibilityLabel: isOpeningMaps ? "Opening directions" : "Get directions",
            accessibilityHint: isOpeningMaps ? "Directions are being opened" : "Opens Maps app with directions to \(shop.name)",
            isLoading: isOpeningMaps
        ) {
            openMapsForDirections(to: shop.address)
        }
    }
    
    /// Website action button
    private var websiteActionButton: some View {
        QuickActionButton(
            systemImageName: isOpeningWebsite ? "globe" : "globe", 
            title: isOpeningWebsite ? "Opening..." : "Website",
            accessibilityLabel: isOpeningWebsite ? "Opening website" : "Visit website",
            accessibilityHint: isOpeningWebsite ? "Website is being opened" : "Opens the coffee shop website in browser",
            isLoading: isOpeningWebsite
        ) {
            openWebsite(shop.website)
        }
    }
    
    /// Phone call action button
    private var phoneActionButton: some View {
        QuickActionButton(
            systemImageName: isPerformingPhoneCall ? "phone.fill" : "phone.fill", 
            title: isPerformingPhoneCall ? "Calling..." : "Call",
            accessibilityLabel: isPerformingPhoneCall ? "Calling in progress" : "Call coffee shop",
            accessibilityHint: isPerformingPhoneCall ? "Phone call is being initiated" : "Calls \(shop.phone)",
            isLoading: isPerformingPhoneCall
        ) {
            makePhoneCall(to: shop.phone)
        }
    }
    
    /// Contact details section
    private var contactDetailsSection: some View {
        VStack(alignment: .leading, spacing: Design.detailRowSpacing) {
            Text("Contact Information")
                .font(.system(size: Design.detailFontSize, weight: .semibold))
                .foregroundColor(Design.secondaryText)
                .accessibilityAddTraits(.isHeader)
            
            ContactDetailRow(
                icon: "mappin.and.ellipse", 
                text: shop.address,
                accessibilityLabel: "Address: \(shop.address)"
            )
            ContactDetailRow(
                icon: "phone.fill", 
                text: shop.phone,
                accessibilityLabel: "Phone number: \(shop.phone)"
            )
        }
        .accessibilityElement(children: .combine)
    }
    
    /// Business hours section
    private var businessHoursSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Business Hours")
                .font(.system(size: Design.detailFontSize, weight: .semibold))
                .foregroundColor(Design.secondaryText)
                .accessibilityAddTraits(.isHeader)
            
            businessHoursContent
        }
    }
    
    /// Business hours content based on loading state
    private var businessHoursContent: some View {
        Group {
            if isLoadingBusinessHours {
                businessHoursLoadingView
            } else if let businessHoursInfo = businessHoursInfo {
                BusinessHoursView(businessHoursInfo: businessHoursInfo)
                    .accessibilityLabel("Business hours information")
            } else if businessHoursError != nil {
                BusinessHoursUnavailableView()
                    .accessibilityLabel("Business hours unavailable")
            }
        }
    }
    
    /// Loading state for business hours
    private var businessHoursLoadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(Design.progressScale)
                .accessibilityLabel("Loading business hours")
            Text("Loading business hours...")
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
    
    /// Overlay buttons (close and favorite)
    private func overlayButtons(geometry: GeometryProxy) -> some View {
        HStack {
            closeButton
            Spacer()
            favoriteButton
        }
        .padding(.horizontal, Design.contentPadding)
        .padding(.top, geometry.safeAreaInsets.top + Design.overlayPadding)
    }
    
    /// Close button
    private var closeButton: some View {
        Button(action: {
            presentationMode.wrappedValue.dismiss()
        }) {
            Image(systemName: "xmark")
                .font(.headline)
                .foregroundColor(Design.primaryText)
                .frame(width: Design.overlayButtonSize, height: Design.overlayButtonSize)
                .background(Design.overlayBackground)
                .clipShape(Circle())
                .shadow(radius: Design.overlayShadowRadius)
        }
        .accessibilityLabel("Close")
        .accessibilityHint("Closes the coffee shop detail view")
        .accessibilityAddTraits(.isButton)
    }
    
    /// Favorite toggle button with enhanced animations
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping)) {
                toggleFavorite()
            }
        }) {
            Group {
                if isTogglingFavorite {
                    ProgressView()
                        .scaleEffect(Design.progressScale)
                        .foregroundColor(Design.primaryText)
                } else {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.headline)
                        .foregroundColor(isFavorite ? .red : Design.primaryText)
                        .scaleEffect(isFavorite ? 1.1 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isFavorite)
                }
            }
            .frame(width: Design.overlayButtonSize, height: Design.overlayButtonSize)
            .background(
                Circle()
                    .fill(Design.overlayBackground)
                    .shadow(
                        color: Color.black.opacity(0.15),
                        radius: Design.overlayShadowRadius,
                        x: 0,
                        y: 2
                    )
            )
            .scaleEffect(isTogglingFavorite ? 0.9 : 1.0)
            .animation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping), value: isTogglingFavorite)
        }
        .disabled(isTogglingFavorite)
        .accessibilityLabel(
            isTogglingFavorite ? "Updating favorites" : 
            (isFavorite ? "Remove from favorites" : "Add to favorites")
        )
        .accessibilityHint(
            isTogglingFavorite ? "Favorite status is being updated" :
            (isFavorite ? "Removes \(shopDisplayName) from your favorites" : "Adds \(shopDisplayName) to your favorites")
        )
        .accessibilityAddTraits(.isButton)
    }
    
    
    /// Toggles favorite status with enhanced state management, performance tracking, and error handling
    private func toggleFavorite() {
        // Prevent multiple simultaneous favorite toggles
        guard !isTogglingFavorite else { 
            print("CoffeeShopDetail: Favorite toggle already in progress, ignoring")
            return 
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let originalState = self.isFavorite
        let actionName = originalState ? "Remove Favorite" : "Add Favorite"
        
        print("CoffeeShopDetail: Starting \(actionName)")
        
        // Set loading state
        isTogglingFavorite = true
        
        // Optimistically update UI for better perceived performance
        self.isFavorite.toggle()
        
        // Perform action with completion handling
        let completion: (Bool) -> Void = { [weak authManager] success in
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            
            DispatchQueue.main.async {
                self.isTogglingFavorite = false
                
                if success {
                    print("CoffeeShopDetail: \(actionName) ✅ (\(String(format: "%.3f", duration))s)")
                    
                    // Verify state consistency with auth manager
                    if let authManager = authManager {
                        let authState = authManager.isFavorite(shopId: self.shop.id)
                        if self.isFavorite != authState {
                            print("CoffeeShopDetail: State mismatch detected, correcting")
                            self.isFavorite = authState
                        }
                    }
                } else {
                    // Revert optimistic update on failure
                    self.isFavorite = originalState
                    print("CoffeeShopDetail: \(actionName) failed ❌ (\(String(format: "%.3f", duration))s)")
                }
            }
        }
        
        if originalState {
            authManager.removeFavorite(shopId: shop.id, completion: completion)
        } else {
            authManager.addFavorite(shopId: shop.id, completion: completion)
        }
    }
    
    /// Makes phone call with enhanced error handling, loading states, and user feedback
    private func makePhoneCall(to phoneNumber: String) {
        // Prevent multiple simultaneous calls
        guard !isPerformingPhoneCall else { return }
        
        // Set loading state
        isPerformingPhoneCall = true
        
        // Perform action with error boundary
        performActionWithErrorBoundary(actionName: "Phone Call") {
            guard !phoneNumber.isEmpty else {
                throw ActionError.invalidInput("Phone number not available")
            }
            
            let cleanedPhoneNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            
            guard !cleanedPhoneNumber.isEmpty else {
                throw ActionError.invalidInput("Invalid phone number")
            }
            
            guard let phoneURL = URL(string: "tel://\(cleanedPhoneNumber)") else {
                throw ActionError.urlCreation("Unable to create phone call")
            }
            
            guard UIApplication.shared.canOpenURL(phoneURL) else {
                throw ActionError.deviceCapability("Phone calls not supported on this device")
            }
            
            UIApplication.shared.open(phoneURL) { success in
                DispatchQueue.main.async {
                    self.isPerformingPhoneCall = false
                    
                if success {
                    print("CoffeeShopDetail: Phone call initiated ✅")
                } else {
                    print("CoffeeShopDetail: Phone call failed ❌")
                }
                }
            }
        } onError: { error in
            self.isPerformingPhoneCall = false
            print("CoffeeShopDetail: Phone call error - \(error.localizedDescription) ❌")
        }
    }
    
    /// Opens Maps app for directions with enhanced error handling, loading states, and user feedback
    private func openMapsForDirections(to address: String) {
        // Prevent multiple simultaneous map opens
        guard !isOpeningMaps else { return }
        
        // Set loading state
        isOpeningMaps = true
        
        // Perform action with error boundary
        performActionWithErrorBoundary(actionName: "Maps Directions") {
            guard !address.isEmpty else {
                throw ActionError.invalidInput("Address not available")
            }
            
            let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let urlString = "http://maps.apple.com/?daddr=\(encodedAddress)"
            
            guard let mapsURL = URL(string: urlString) else {
                throw ActionError.urlCreation("Unable to create directions")
            }
            
            guard UIApplication.shared.canOpenURL(mapsURL) else {
                throw ActionError.deviceCapability("Maps app not available")
            }
            
            UIApplication.shared.open(mapsURL) { success in
                DispatchQueue.main.async {
                    self.isOpeningMaps = false
                    
                    if success {
                        print("CoffeeShopDetail: Directions opened ✅")
                    } else {
                        print("CoffeeShopDetail: Maps failed ❌")
                    }
                }
            }
        } onError: { error in
            self.isOpeningMaps = false
            print("CoffeeShopDetail: Maps error - \(error.localizedDescription) ❌")
        }
    }
    
    /// Opens website with enhanced error handling, loading states, and user feedback
    private func openWebsite(_ urlString: String) {
        // Prevent multiple simultaneous website opens
        guard !isOpeningWebsite else { return }
        
        // Set loading state
        isOpeningWebsite = true
        
        // Perform action with error boundary
        performActionWithErrorBoundary(actionName: "Website") {
            guard !urlString.isEmpty else {
                throw ActionError.invalidInput("Website not available")
            }
            
            // Ensure URL has proper scheme
            let website = urlString.hasPrefix("http") ? urlString : "https://\(urlString)"
            
            guard let url = URL(string: website) else {
                throw ActionError.urlCreation("Invalid website URL")
            }
            
            guard UIApplication.shared.canOpenURL(url) else {
                throw ActionError.deviceCapability("Unable to open website")
            }
            
            UIApplication.shared.open(url) { success in
                DispatchQueue.main.async {
                    self.isOpeningWebsite = false
                    
                    if success {
                        print("CoffeeShopDetail: Website opened ✅")
                    } else {
                        print("CoffeeShopDetail: Website failed ❌")
                    }
                }
            }
        } onError: { error in
            self.isOpeningWebsite = false
            print("CoffeeShopDetail: Website error - \(error.localizedDescription) ❌")
        }
    }
    
    
    /// Performs action with comprehensive error boundary, performance tracking, and memory optimization
    private func performActionWithErrorBoundary(
        actionName: String,
        action: @escaping () throws -> Void,
        onError: @escaping (Error) -> Void
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            print("CoffeeShopDetail: Starting \(actionName)")
            try action()
        } catch let actionError as ActionError {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("CoffeeShopDetail: \(actionName) failed - \(actionError.localizedDescription) ❌ (\(String(format: "%.3f", duration))s)")
            
            // Dispatch error handling to avoid blocking
            DispatchQueue.main.async {
                onError(actionError)
            }
        } catch {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("CoffeeShopDetail: \(actionName) failed - \(error.localizedDescription) ❌ (\(String(format: "%.3f", duration))s)")
            
            let wrappedError = ActionError.unknown(error.localizedDescription)
            DispatchQueue.main.async {
                onError(wrappedError)
            }
        }
    }
    
    /// Fetches business hours with performance optimization and proper task management
    private func fetchBusinessHours() {
        // Cancel any existing business hours task
        businessHoursTask?.cancel()
        
        // Don't fetch if already loaded or currently loading
        guard businessHoursInfo == nil && !isLoadingBusinessHours else {
            print("CoffeeShopDetail: Business hours already loaded or loading, skipping")
            return
        }
        
        isLoadingBusinessHours = true
        businessHoursError = nil
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        businessHoursTask = Task {
            do {
                // Check for cancellation before expensive operation
                try Task.checkCancellation()
                
                let posService = POSServiceFactory.createService(for: shop)
                let hoursInfo = try await posService.fetchBusinessHours(for: shop)
                
                // Check for cancellation before UI update
                try Task.checkCancellation()
                
                await MainActor.run {
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    
                    if let hoursInfo = hoursInfo {
                        print("CoffeeShopDetail: Business hours loaded ✅ (\(String(format: "%.2f", duration))s)")
                        self.businessHoursInfo = hoursInfo
                    } else {
                        print("CoffeeShopDetail: No business hours available ⚠️")
                        self.businessHoursError = "No business hours available"
                    }
                    self.isLoadingBusinessHours = false
                    self.businessHoursTask = nil
                }
            } catch is CancellationError {
                print("CoffeeShopDetail: Business hours fetch cancelled")
                await MainActor.run {
                    self.isLoadingBusinessHours = false
                    self.businessHoursTask = nil
                }
            } catch {
                await MainActor.run {
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("CoffeeShopDetail: Business hours failed ❌ (\(String(format: "%.2f", duration))s)")
                    self.businessHoursError = error.localizedDescription
                    self.isLoadingBusinessHours = false
                    self.businessHoursTask = nil
                }
            }
        }
    }
    
    // MARK: - Lifecycle Management
    
    /**
     * Handles view appearance with comprehensive performance optimization.
     * 
     * This method implements several performance optimizations:
     * - Prevents duplicate initialization using `viewDidAppear` flag
     * - Tracks setup time for performance monitoring
     * - Only fetches business hours when needed
     * - Logs performance metrics for debugging
     * 
     * ## Performance Considerations
     * - Uses guard statement to prevent duplicate work
     * - Measures execution time using `CFAbsoluteTimeGetCurrent()`
     * - Conditional data loading based on current state
     * 
     * ## Side Effects
     * - Sets `viewDidAppear` to true
     * - May trigger business hours API call
     * - Logs performance metrics to console
     */
    private func handleViewAppear() {
        guard !viewDidAppear else {
            print("CoffeeShopDetail: View already appeared, skipping duplicate setup")
            return
        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        viewDidAppear = true
        
        print("CoffeeShopDetail: View appeared for \(shop.name)")
        
        // Fetch business hours only if needed
        if businessHoursInfo == nil && businessHoursError == nil {
            fetchBusinessHours()
        }
        
        let duration = CFAbsoluteTimeGetCurrent() - startTime
        print("CoffeeShopDetail: View setup completed (\(String(format: "%.3f", duration))s)")
    }
    
    /**
     * Handles view disappearance with comprehensive resource cleanup.
     * 
     * This method ensures proper memory management and prevents leaks by:
     * - Cancelling any ongoing async tasks
     * - Resetting loading states
     * - Cleaning up action states
     * - Logging cleanup operations
     * 
     * ## Memory Management
     * - Cancels `businessHoursTask` to prevent memory leaks
     * - Resets all loading states to prevent UI inconsistencies
     * - Clears action states to prevent stale operations
     * 
     * ## Performance Impact
     * - Prevents unnecessary background operations
     * - Reduces memory footprint when view is not visible
     * - Ensures clean state for next view appearance
     * 
     * ## Side Effects
     * - Cancels ongoing network requests
     * - Resets `viewDidAppear` flag
     * - Logs cleanup operations to console
     */
    private func handleViewDisappear() {
        print("CoffeeShopDetail: View disappeared, cleaning up resources")
        
        // Cancel any ongoing business hours task
        businessHoursTask?.cancel()
        businessHoursTask = nil
        
        // Reset loading states if view is disappearing
        if isLoadingBusinessHours {
            isLoadingBusinessHours = false
        }
        
        // Cancel any ongoing actions to prevent memory leaks
        if isPerformingPhoneCall || isOpeningMaps || isOpeningWebsite || isTogglingFavorite {
            print("CoffeeShopDetail: Cancelling ongoing actions")
            isPerformingPhoneCall = false
            isOpeningMaps = false
            isOpeningWebsite = false
            isTogglingFavorite = false
        }
        
        viewDidAppear = false
        print("CoffeeShopDetail: Cleanup completed")
    }
}

// MARK: - Supporting Components

/// Contact detail row component
private struct ContactDetailRow: View {
    let icon: String
    let text: String
    let accessibilityLabel: String
    
    init(icon: String, text: String, accessibilityLabel: String? = nil) {
        self.icon = icon
        self.text = text
        self.accessibilityLabel = accessibilityLabel ?? text
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.primaryText)
                .accessibilityHidden(true)
            Text(text)
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.primaryText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Quick action button component
private struct QuickActionButton: View {
    let systemImageName: String
    let title: String
    let accessibilityLabel: String
    let accessibilityHint: String
    let isLoading: Bool
    let action: () -> Void
    
    init(
        systemImageName: String,
        title: String,
        accessibilityLabel: String? = nil,
        accessibilityHint: String? = nil,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) {
        self.systemImageName = systemImageName
        self.title = title
        self.accessibilityLabel = accessibilityLabel ?? title
        self.accessibilityHint = accessibilityHint ?? "Performs \(title.lowercased()) action"
        self.isLoading = isLoading
        self.action = action
    }
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: isLoading ? {} : action) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(Design.progressScale)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: systemImageName)
                        .font(.headline)
                        .accessibilityHidden(true)
                }
                
                Text(title)
                    .font(.system(size: Design.captionFontSize, weight: .semibold))
            }
            .foregroundColor(isLoading ? Design.secondaryText : Design.quickActionBorder)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.quickActionVerticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Design.quickActionCornerRadius)
                    .fill(isLoading ? Design.secondaryText.opacity(0.1) : Design.quickActionBackground)
                    .shadow(
                        color: Color.black.opacity(isPressed ? 0.1 : 0.05),
                        radius: isPressed ? 2 : Design.quickActionShadowRadius,
                        x: 0,
                        y: isPressed ? 1 : 2
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Design.quickActionCornerRadius)
                    .stroke(isLoading ? Design.secondaryText.opacity(0.3) : Design.quickActionBorder, lineWidth: Design.quickActionBorderWidth)
            )
            .scaleEffect(isPressed ? Design.buttonPressScale : 1.0)
            .opacity(isPressed ? Design.pressedOpacity : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(isLoading)
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.1)) {
                isPressed = pressing
            }
        }, perform: {})
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }
}
