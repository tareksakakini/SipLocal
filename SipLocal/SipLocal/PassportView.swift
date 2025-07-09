import SwiftUI

struct PassportView: View {
    let coffeeShops = DataService.loadCoffeeShops()
    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(coffeeShops) { shop in
                        Image(shop.stampName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(minWidth: 0, maxWidth: .infinity)
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