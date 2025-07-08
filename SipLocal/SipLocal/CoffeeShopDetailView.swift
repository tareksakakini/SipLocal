import SwiftUI

struct CoffeeShopDetailView: View {
    let shop: CoffeeShop
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("\(shop.imageName)")
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
        }
        .navigationTitle(shop.name)
        .navigationBarTitleDisplayMode(.inline)
        .edgesIgnoringSafeArea(.top)
    }
} 
