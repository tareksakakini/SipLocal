//
//  ExploreView.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import MapKit

// MARK: - Design Constants

private enum Design {
    // Map Configuration
    static let defaultLatitude: Double = 38.5816  // Sacramento, CA
    static let defaultLongitude: Double = -121.4944
    static let defaultSpanDelta: Double = 0.1
    static let focusedSpanDelta: Double = 0.01
    
    // Search Configuration
    static let maxSearchResults: Int = 3
    
    // UI Constants
    static let mapAnnotationSize: CGFloat = 32
    static let mapAnnotationIconSize: CGFloat = 16
    static let selectedAnnotationScale: CGFloat = 1.3
    static let selectedLabelScale: CGFloat = 1.1
    
    static let searchBarCornerRadius: CGFloat = 10
    static let cardCornerRadius: CGFloat = 15
    static let suggestionItemCornerRadius: CGFloat = 10
    static let buttonCornerRadius: CGFloat = 10
    
    static let shadowRadius: CGFloat = 5
    static let annotationShadowRadius: CGFloat = 2
    static let labelShadowRadius: CGFloat = 1
    
    // Colors
    static let accentColor = Color.orange
    static let primaryButtonColor = Color.blue
    static let backgroundOpacity: Double = 0.9
    static let labelBackgroundOpacity: Double = 0.9
    static let shadowOpacity: Double = 0.3
    static let lightShadowOpacity: Double = 0.2
    
    // Animation
    static let springResponse: Double = 0.3
    static let springDamping: Double = 0.7
    static let selectSpringResponse: Double = 0.5
}

// MARK: - Explore View

/// Main discovery view for finding and exploring local coffee shops
/// Features interactive map with annotations, search functionality, and detailed shop information
struct ExploreView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var coffeeShops: [CoffeeShop] = DataService.loadCoffeeShops()
    @State private var searchText: String = ""
    @State private var region: MKCoordinateRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(
            latitude: Design.defaultLatitude, 
            longitude: Design.defaultLongitude
        ),
        span: MKCoordinateSpan(
            latitudeDelta: Design.defaultSpanDelta, 
            longitudeDelta: Design.defaultSpanDelta
        )
    )
    @State private var selectedShop: CoffeeShop?
    
    // MARK: - Computed Properties
    
    /// Filtered search results based on current search text
    var searchResults: [CoffeeShop] {
        guard !searchText.isEmpty else { return [] }
        
        return coffeeShops.filter { shop in
            shop.name.localizedCaseInsensitiveContains(searchText) ||
            shop.address.localizedCaseInsensitiveContains(searchText)
        }
        .prefix(Design.maxSearchResults)
        .map { $0 }
    }
    
    var body: some View {
        NavigationStack {
            mapView
        }
    }
    
    // MARK: - View Components
    
    /// Main map interface with search and shop details
    private var mapView: some View {
        ZStack(alignment: .top) {
            backgroundTapDetector
            mapWithAnnotations
            searchInterface
        }
    }
    
    /// Invisible background for tap detection to dismiss selection
    private var backgroundTapDetector: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation {
                    selectedShop = nil
                }
            }
    }
    
    /// Map with coffee shop annotations
    private var mapWithAnnotations: some View {
        Map(coordinateRegion: $region, annotationItems: coffeeShops) { shop in
            MapAnnotation(coordinate: shop.coordinate) {
                mapAnnotationView(for: shop)
            }
        }
        .edgesIgnoringSafeArea(.top)
    }
    
    /// Individual map annotation for a coffee shop
    private func mapAnnotationView(for shop: CoffeeShop) -> some View {
        Button(action: {
            withAnimation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping)) {
                selectedShop = shop
            }
        }) {
            VStack(spacing: 2) {
                annotationIcon(for: shop)
                annotationLabel(for: shop)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Coffee shop: \(shop.name)")
        .accessibilityHint("Tap to view details")
    }
    
    /// Coffee cup icon for map annotation
    private func annotationIcon(for shop: CoffeeShop) -> some View {
        ZStack {
            Circle()
                .fill(Design.accentColor)
                .frame(width: Design.mapAnnotationSize, height: Design.mapAnnotationSize)
            
            Image(systemName: "cup.and.saucer.fill")
                .font(.system(size: Design.mapAnnotationIconSize))
                .foregroundColor(.white)
        }
        .shadow(
            color: .black.opacity(Design.shadowOpacity), 
            radius: Design.annotationShadowRadius, 
            x: 0, y: 1
        )
        .scaleEffect(selectedShop?.id == shop.id ? Design.selectedAnnotationScale : 1.0)
    }
    
    /// Shop name label for map annotation
    private func annotationLabel(for shop: CoffeeShop) -> some View {
        Text(shop.name)
            .font(.caption2)
            .foregroundColor(.primary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.white.opacity(Design.labelBackgroundOpacity))
            .cornerRadius(4)
            .shadow(
                color: .black.opacity(Design.lightShadowOpacity), 
                radius: Design.labelShadowRadius, 
                x: 0, y: 1
            )
            .scaleEffect(selectedShop?.id == shop.id ? Design.selectedLabelScale : 1.0)
    }
    
    /// Search bar and results overlay
    private var searchInterface: some View {
        VStack(spacing: 0) {
            searchBar
            
            if !searchResults.isEmpty {
                searchSuggestions
            }
            
            Spacer()
            
            if let shop = selectedShop {
                shopDetailCard(for: shop)
            }
        }
    }
    
    /// Search bar with clear button
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search for a coffee shop", text: $searchText)
                .accessibilityLabel("Search coffee shops")
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .accessibilityLabel("Clear search")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Design.searchBarCornerRadius)
        .shadow(radius: Design.shadowRadius)
        .padding(.horizontal)
        .padding(.top)
    }
    
    /// Search suggestions dropdown
    private var searchSuggestions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Suggestions")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)

            ForEach(searchResults) { shop in
                suggestionRow(for: shop)
                
                if shop.id != searchResults.last?.id {
                    Divider().padding(.leading, 46)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(Design.suggestionItemCornerRadius)
        .shadow(radius: Design.shadowRadius)
        .padding(.horizontal)
        .padding(.top, 4)
    }
    
    /// Individual suggestion row
    private func suggestionRow(for shop: CoffeeShop) -> some View {
        Button(action: {
            selectShop(shop)
        }) {
            HStack(spacing: 12) {
                Image(systemName: "cup.and.saucer.fill")
                    .foregroundColor(Design.accentColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(shop.name)
                        .foregroundColor(.primary)
                        .fontWeight(.medium)
                    Text(shop.address)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(12)
        }
        .accessibilityLabel("Select \(shop.name)")
    }
    
    /// Detailed shop information card
    private func shopDetailCard(for shop: CoffeeShop) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            shopDetailHeader(for: shop)
            shopDetailInfo(for: shop)
            shopDetailButton(for: shop)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(Design.cardCornerRadius)
        .shadow(radius: Design.shadowRadius)
        .padding(.horizontal)
        .padding(.bottom, 8)
        .transition(.opacity)
    }
    
    /// Shop detail card header with name and close button
    private func shopDetailHeader(for shop: CoffeeShop) -> some View {
        HStack {
            Text(shop.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                withAnimation {
                    selectedShop = nil
                }
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.gray)
            }
            .accessibilityLabel("Close shop details")
        }
    }
    
    /// Shop detail information (address and phone)
    private func shopDetailInfo(for shop: CoffeeShop) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(shop.address)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(shop.phone)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    /// Shop detail view more button
    private func shopDetailButton(for shop: CoffeeShop) -> some View {
        NavigationLink(destination: CoffeeShopDetailView(shop: shop, authManager: authManager)) {
            HStack {
                Text("View More")
                    .fontWeight(.semibold)
                Spacer()
                Image(systemName: "arrow.right")
            }
            .foregroundColor(.white)
            .padding(12)
            .background(Design.primaryButtonColor)
            .cornerRadius(Design.buttonCornerRadius)
        }
        .accessibilityLabel("View more details for \(shop.name)")
    }
    
    // MARK: - Actions
    
    /// Select a coffee shop from search results or map
    private func selectShop(_ shop: CoffeeShop) {
        searchText = ""
        withAnimation(.spring(response: Design.selectSpringResponse, dampingFraction: Design.springDamping)) {
            selectedShop = shop
            region.center = shop.coordinate
            region.span = MKCoordinateSpan(
                latitudeDelta: Design.focusedSpanDelta, 
                longitudeDelta: Design.focusedSpanDelta
            )
        }
    }
}

// MARK: - Previews

struct ExploreView_Previews: PreviewProvider {
    static var previews: some View {
        ExploreView()
            .environmentObject(AuthenticationManager())
    }
} 