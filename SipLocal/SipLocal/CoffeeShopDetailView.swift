import SwiftUI

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var isFavorite: Bool
    
    init(shop: CoffeeShop, authManager: AuthenticationManager) {
        self.shop = shop
        self._isFavorite = State(initialValue: authManager.isFavorite(shopId: shop.id))
    }
    
    var body: some View {
        ScrollView {
            ZStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 16) {
                    Image(shop.imageName)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 250)
                        .clipped()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        Text(shop.name)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text(shop.description)
                            .font(.body)
                        
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
                    }
                    .padding()
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
                            .foregroundColor(isFavorite ? .red : .primary)
                            .padding(10)
                            .background(Color.white.opacity(0.7))
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                }
                .padding(.horizontal)
                .padding(.top, 50)
            }
        }
        .navigationBarBackButtonHidden(true)
        .edgesIgnoringSafeArea(.top)
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
} 
