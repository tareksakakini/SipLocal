import SwiftUI

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isFavorite: Bool
    @State private var showMenu = false
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
                    VStack(alignment: .leading, spacing: 0) {
                        Image(shop.imageName)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height * 0.4)
                            .clipped()
                        
                        VStack(alignment: .leading, spacing: 16) {
                            Text(shop.name)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                            
                            Text(shop.description)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            // Quick action buttons
                            HStack(spacing: 12) {
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
                            .padding(.top, 12)
                            
                            Divider()
                            
                            // Details (non-interactive rows)
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .top, spacing: 8) {
                                    Image(systemName: "mappin.and.ellipse")
                                    Text(shop.address)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                HStack(spacing: 8) {
                                    Image(systemName: "phone.fill")
                                    Text(shop.phone)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                }
                                
                            }
                            
                            
                            // Business Hours Section
                            if isLoadingBusinessHours {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading business hours...")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            } else if let businessHoursInfo = businessHoursInfo {
                                BusinessHoursView(businessHoursInfo: businessHoursInfo)
                            } else if businessHoursError != nil {
                                BusinessHoursUnavailableView()
                            }
                            
                            
                        }
                        .padding()
                        .frame(width: geometry.size.width)
                    }
                    
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            toggleFavorite()
                        }) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .padding(10)
                                .background(Color.white.opacity(0.7))
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, geometry.safeAreaInsets.top)
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
        print("📞 Attempting to call: \(cleanedPhoneNumber)")
        
        if let phoneURL = URL(string: "tel://\(cleanedPhoneNumber)") {
            if UIApplication.shared.canOpenURL(phoneURL) {
                print("✅ Opening phone app for call")
                UIApplication.shared.open(phoneURL)
            } else {
                print("❌ Cannot open phone URL - likely running on simulator")
                // Show alert for simulator testing
                #if targetEnvironment(simulator)
                print("🔍 Simulator detected - phone call would work on real device")
                #endif
            }
        } else {
            print("❌ Invalid phone URL created")
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
                print("🔍 CoffeeShopDetailView: Fetching business hours for \(shop.name)")
                let hoursInfo = try await SquareAPIService.shared.fetchBusinessHours(for: shop)
                await MainActor.run {
                    if let hoursInfo = hoursInfo {
                        print("✅ CoffeeShopDetailView: Successfully got business hours for \(shop.name)")
                        self.businessHoursInfo = hoursInfo
                    } else {
                        print("⚠️ CoffeeShopDetailView: No business hours returned for \(shop.name)")
                        self.businessHoursError = "No business hours available"
                    }
                    self.isLoadingBusinessHours = false
                }
            } catch {
                await MainActor.run {
                    print("❌ CoffeeShopDetailView: Error fetching business hours for \(shop.name): \(error)")
                    self.businessHoursError = error.localizedDescription
                    self.isLoadingBusinessHours = false
                }
            }
        }
    }
}

// MARK: - QuickActionButton
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
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.black)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
