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
    
    // Progress
    static let progressScale: CGFloat = 0.8
}

// MARK: - Coffee Shop Detail View

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    
    // MARK: - State Management
    
    /// Favorite state
    @State private var isFavorite: Bool
    
    /// Navigation states
    @State private var showMenu = false
    
    /// Business hours states
    @State private var businessHoursInfo: BusinessHoursInfo?
    @State private var isLoadingBusinessHours = false
    @State private var businessHoursError: String?
    
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
        }
        .sheet(isPresented: $showMenu) {
            MenuCategorySelectionView(shop: shop)
        }
        .onAppear {
            fetchBusinessHours()
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
        Image(shop.imageName)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: geometry.size.width, height: geometry.size.height * Design.imageHeightRatio)
            .clipped()
    }
    
    /// Shop details section
    private func shopDetails(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: Design.sectionSpacing) {
            shopHeader
            quickActionsSection
            Divider()
            contactDetailsSection
            businessHoursSection
        }
        .padding(Design.contentPadding)
        .frame(width: geometry.size.width)
    }
    
    /// Shop name and description header
    private var shopHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(shop.name)
                .font(.system(size: Design.titleFontSize, weight: .bold))
                .lineLimit(Design.titleMaxLines)
                .minimumScaleFactor(Design.titleMinScale)
            
            Text(shop.description)
                .font(.system(size: Design.bodyFontSize))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    /// Quick action buttons row
    private var quickActionsSection: some View {
        HStack(spacing: Design.quickActionSpacing) {
            QuickActionButton(systemImageName: "menucard", title: "Menu") {
                showMenu = true
            }
            QuickActionButton(systemImageName: "mappin.and.ellipse", title: "Directions") {
                openMapsForDirections(to: shop.address)
            }
            QuickActionButton(systemImageName: "globe", title: "Website") {
                openWebsite(shop.website)
            }
            QuickActionButton(systemImageName: "phone.fill", title: "Call") {
                makePhoneCall(to: shop.phone)
            }
        }
        .padding(.top, Design.quickActionTopPadding)
    }
    
    /// Contact details section
    private var contactDetailsSection: some View {
        VStack(alignment: .leading, spacing: Design.detailRowSpacing) {
            ContactDetailRow(icon: "mappin.and.ellipse", text: shop.address)
            ContactDetailRow(icon: "phone.fill", text: shop.phone)
        }
    }
    
    /// Business hours section
    private var businessHoursSection: some View {
        Group {
            if isLoadingBusinessHours {
                businessHoursLoadingView
            } else if let businessHoursInfo = businessHoursInfo {
                BusinessHoursView(businessHoursInfo: businessHoursInfo)
            } else if businessHoursError != nil {
                BusinessHoursUnavailableView()
            }
        }
    }
    
    /// Loading state for business hours
    private var businessHoursLoadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(Design.progressScale)
            Text("Loading business hours...")
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.secondaryText)
        }
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
    }
    
    /// Favorite toggle button
    private var favoriteButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: Design.favoriteAnimationDuration)) {
                toggleFavorite()
            }
        }) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.headline)
                .foregroundColor(isFavorite ? .red : Design.primaryText)
                .frame(width: Design.overlayButtonSize, height: Design.overlayButtonSize)
                .background(Design.overlayBackground)
                .clipShape(Circle())
                .shadow(radius: Design.overlayShadowRadius)
        }
    }
    
    private func toggleFavorite() {
        let originalState = self.isFavorite
        self.isFavorite.toggle()
        
        if originalState {
            authManager.removeFavorite(shopId: shop.id) { success in
                if !success {
                    self.isFavorite = originalState
                }
            }
        } else {
            authManager.addFavorite(shopId: shop.id) { success in
                if !success {
                    self.isFavorite = originalState
                }
            }
        }
    }
    
    private func makePhoneCall(to phoneNumber: String) {
        let cleanedPhoneNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        
        if let phoneURL = URL(string: "tel://\(cleanedPhoneNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                print("CoffeeShopDetail: Phone call initiated")
                UIApplication.shared.open(phoneURL)
            } else {
                print("CoffeeShopDetail: Phone call unavailable")
            }
        }
    }
    
    private func openMapsForDirections(to address: String) {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        if let mapsURL = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") {
            UIApplication.shared.open(mapsURL)
        }
    }
    
    private func openWebsite(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }
    
    private func fetchBusinessHours() {
        isLoadingBusinessHours = true
        businessHoursError = nil
        
        Task {
            do {
                let posService = POSServiceFactory.createService(for: shop)
                let hoursInfo = try await posService.fetchBusinessHours(for: shop)
                await MainActor.run {
                    if let hoursInfo = hoursInfo {
                        print("CoffeeShopDetail: Business hours loaded ✅")
                        self.businessHoursInfo = hoursInfo
                    } else {
                        self.businessHoursError = "No business hours available"
                    }
                    self.isLoadingBusinessHours = false
                }
            } catch {
                await MainActor.run {
                    print("CoffeeShopDetail: Business hours failed ❌")
                    self.businessHoursError = error.localizedDescription
                    self.isLoadingBusinessHours = false
                }
            }
        }
    }
}

// MARK: - Supporting Components

/// Contact detail row component
private struct ContactDetailRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.primaryText)
            Text(text)
                .font(.system(size: Design.detailFontSize))
                .foregroundColor(Design.primaryText)
        }
    }
}

/// Quick action button component
private struct QuickActionButton: View {
    let systemImageName: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: systemImageName)
                    .font(.headline)
                Text(title)
                    .font(.system(size: Design.captionFontSize, weight: .semibold))
            }
            .foregroundColor(Design.quickActionBorder)
            .frame(maxWidth: .infinity)
            .padding(.vertical, Design.quickActionVerticalPadding)
            .background(Design.quickActionBackground)
            .cornerRadius(Design.quickActionCornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Design.quickActionCornerRadius)
                    .stroke(Design.quickActionBorder, lineWidth: Design.quickActionBorderWidth)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}
