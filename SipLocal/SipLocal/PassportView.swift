import SwiftUI

struct PassportView: View {
    let coffeeShops = DataService.loadCoffeeShops()
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    @State private var stampedShops: Set<String> = []
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(coffeeShops) { shop in
                        let isStamped = stampedShops.contains(shop.id)
                        
                        Image(shop.stampName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .grayscale(isStamped ? 0.0 : 1.0)
                            .opacity(isStamped ? 1.0 : 0.6)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if isStamped {
                                        stampedShops.remove(shop.id)
                                    } else {
                                        stampedShops.insert(shop.id)
                                    }
                                }
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("Passport")
        }
    }
}

struct PassportView_Previews: PreviewProvider {
    static var previews: some View {
        PassportView()
    }
} 