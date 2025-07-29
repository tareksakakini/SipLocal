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
                            
                            Divider()
                            
                            HStack {
                                Image(systemName: "mappin.and.ellipse")
                                Text(shop.address)
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Image(systemName: "phone.fill")
                                Text(shop.phone)
                            }
                            .font(.subheadline)
                            
                            HStack {
                                Image(systemName: "globe")
                                if let url = URL(string: shop.website) {
                                    Link("Visit Website", destination: url)
                                }
                            }
                            .font(.subheadline)
                            
                            Divider()
                            
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
                            
                            Divider()
                            
                            // Menu Button
                            Button(action: {
                                showMenu = true
                            }) {
                                HStack {
                                    Image(systemName: "menucard")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                    Text("View Menu")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.subheadline)
                                        .foregroundColor(.white)
                                }
                                .padding()
                                .background(Color.black)
                                .cornerRadius(12)
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
