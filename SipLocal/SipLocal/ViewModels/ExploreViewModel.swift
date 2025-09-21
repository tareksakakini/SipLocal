/**
 * ExploreViewModel.swift
 * SipLocal
 *
 * ViewModel for ExploreView following MVVM architecture.
 * Handles coffee shop discovery, map management, search functionality, and location services.
 *
 * ## Responsibilities
 * - **Coffee Shop Data**: Load and manage coffee shop data
 * - **Map Management**: Handle map region, annotations, and user interactions
 * - **Search Functionality**: Real-time search with filtering and suggestions
 * - **Location Services**: User location and map positioning
 * - **Shop Selection**: Manage selected shop state and details display
 * - **Navigation**: Handle shop detail navigation and map focusing
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **MapKit Integration**: Clean map coordinate and region management
 * - **Search Logic**: Efficient filtering with relevance scoring
 * - **Location Services**: Optional user location integration
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import MapKit
import Combine

// MARK: - ExploreViewModel

/**
 * ViewModel for ExploreView
 * 
 * Manages coffee shop discovery, map interactions, and search functionality.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class ExploreViewModel: ObservableObject {
    
    // MARK: - Published State Properties
    @Published var coffeeShops: [CoffeeShop] = []
    @Published var searchText: String = ""
    @Published var mapRegion: MKCoordinateRegion
    @Published var selectedShop: CoffeeShop?
    @Published var isLoadingShops: Bool = true
    @Published var showSearchResults: Bool = false
    @Published var isMapInteractive: Bool = true
    
    // MARK: - Design Constants
    private enum Design {
        // Map Configuration
        static let defaultLatitude: Double = 38.5816  // Sacramento, CA
        static let defaultLongitude: Double = -121.4944
        static let defaultSpanDelta: Double = 0.1
        static let focusedSpanDelta: Double = 0.01
        
        // Search Configuration
        static let maxSearchResults: Int = 3
        static let searchDebounceDelay: Double = 0.3
        static let minSearchCharacters: Int = 2
        
        // Animation
        static let mapAnimationDuration: Double = 0.5
        static let searchAnimationDuration: Double = 0.3
        static let springResponse: Double = 0.3
        static let springDamping: Double = 0.7
    }
    
    // MARK: - Private State
    private var searchTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Filtered search results based on current search text
    var searchResults: [CoffeeShop] {
        guard !searchText.isEmpty, searchText.count >= Design.minSearchCharacters else { 
            return [] 
        }
        
        let query = searchText.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        
        return coffeeShops.compactMap { shop -> (CoffeeShop, Int)? in
            var score = 0
            let shopName = shop.name.lowercased()
            let shopAddress = shop.address.lowercased()
            
            // Exact name match gets highest priority
            if shopName == query {
                score = 100
            }
            // Name starts with query
            else if shopName.hasPrefix(query) {
                score = 80
            }
            // Name contains query
            else if shopName.contains(query) {
                score = 60
            }
            // Address contains query
            else if shopAddress.contains(query) {
                score = 40
            }
            // Word boundary matches in name
            else if shopName.components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
                        .contains(where: { $0.hasPrefix(query) }) {
                score = 50
            }
            else {
                return nil
            }
            
            return (shop, score)
        }
        .sorted { $0.1 > $1.1 }  // Sort by score descending
        .prefix(Design.maxSearchResults)
        .map { $0.0 }
    }
    
    /// Returns whether search results should be displayed
    var shouldShowSearchResults: Bool {
        !searchText.isEmpty && !searchResults.isEmpty
    }
    
    /// Returns whether the search interface should be active
    var isSearchActive: Bool {
        !searchText.isEmpty
    }
    
    /// Returns map annotations for all coffee shops
    var mapAnnotations: [CoffeeShopAnnotation] {
        coffeeShops.map { shop in
            CoffeeShopAnnotation(
                id: shop.id,
                name: shop.name,
                coordinate: CLLocationCoordinate2D(
                    latitude: shop.latitude,
                    longitude: shop.longitude
                ),
                shop: shop
            )
        }
    }
    
    /// Returns the currently selected annotation
    var selectedAnnotation: CoffeeShopAnnotation? {
        guard let selectedShop = selectedShop else { return nil }
        return mapAnnotations.first { $0.shop.id == selectedShop.id }
    }
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default map region
        self.mapRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: Design.defaultLatitude,
                longitude: Design.defaultLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: Design.defaultSpanDelta,
                longitudeDelta: Design.defaultSpanDelta
            )
        )
        
        setupSearchDebouncing()
        loadCoffeeShops()
    }
    
    deinit {
        searchTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Load coffee shops data
    func loadCoffeeShops() {
        isLoadingShops = true
        
        // Load coffee shops (instant from local data)
        coffeeShops = CoffeeShopDataService.loadCoffeeShops()
        isLoadingShops = false
        
        print("📍 Loaded \(coffeeShops.count) coffee shops for exploration")
    }
    
    /// Handle search text changes
    func handleSearchTextChange(_ newValue: String) {
        searchText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        showSearchResults = shouldShowSearchResults
    }
    
    /// Select a coffee shop from search results
    func selectShop(_ shop: CoffeeShop) {
        withAnimation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping)) {
            selectedShop = shop
            searchText = ""
            showSearchResults = false
            focusMapOnShop(shop)
        }
    }
    
    /// Clear selected shop
    func clearSelectedShop() {
        withAnimation(.spring(response: Design.springResponse, dampingFraction: Design.springDamping)) {
            selectedShop = nil
        }
    }
    
    /// Focus map on a specific shop
    func focusMapOnShop(_ shop: CoffeeShop) {
        let newRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: shop.latitude,
                longitude: shop.longitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: Design.focusedSpanDelta,
                longitudeDelta: Design.focusedSpanDelta
            )
        )
        
        withAnimation(.easeInOut(duration: Design.mapAnimationDuration)) {
            mapRegion = newRegion
        }
    }
    
    /// Reset map to default view
    func resetMapView() {
        let defaultRegion = MKCoordinateRegion(
            center: CLLocationCoordinate2D(
                latitude: Design.defaultLatitude,
                longitude: Design.defaultLongitude
            ),
            span: MKCoordinateSpan(
                latitudeDelta: Design.defaultSpanDelta,
                longitudeDelta: Design.defaultSpanDelta
            )
        )
        
        withAnimation(.easeInOut(duration: Design.mapAnimationDuration)) {
            mapRegion = defaultRegion
            selectedShop = nil
        }
    }
    
    /// Clear search and hide results
    func clearSearch() {
        withAnimation(.easeInOut(duration: Design.searchAnimationDuration)) {
            searchText = ""
            showSearchResults = false
        }
    }
    
    /// Handle map annotation selection
    func handleAnnotationSelection(_ annotation: CoffeeShopAnnotation) {
        selectShop(annotation.shop)
    }
    
    /// Handle background tap (clear selection)
    func handleBackgroundTap() {
        clearSelectedShop()
        clearSearch()
    }
    
    /// Get shop by ID
    func getShop(by id: String) -> CoffeeShop? {
        coffeeShops.first { $0.id == id }
    }
    
    /// Check if shop is currently selected
    func isShopSelected(_ shop: CoffeeShop) -> Bool {
        selectedShop?.id == shop.id
    }
    
    /// Refresh coffee shops data
    func refreshShops() {
        loadCoffeeShops()
    }
    
    // MARK: - Private Methods
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .seconds(Design.searchDebounceDelay), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                self?.performSearch(query: newValue)
            }
            .store(in: &cancellables)
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                // Update search results (computed property handles the logic)
                self.showSearchResults = self.shouldShowSearchResults
                
                if !query.isEmpty && self.searchResults.isEmpty {
                    print("🔍 No search results found for: \"\(query)\"")
                } else if !query.isEmpty {
                    print("🔍 Found \(self.searchResults.count) results for: \"\(query)\"")
                }
            }
        }
    }
}

// MARK: - Map Annotation Model

/// Custom annotation for coffee shops on the map
class CoffeeShopAnnotation: NSObject, ObservableObject, Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    let shop: CoffeeShop
    
    init(id: String, name: String, coordinate: CLLocationCoordinate2D, shop: CoffeeShop) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.shop = shop
        super.init()
    }
}

// MARK: - Location Extensions

extension ExploreViewModel {
    
    /// Calculate distance between two coordinates
    func distance(from coord1: CLLocationCoordinate2D, to coord2: CLLocationCoordinate2D) -> CLLocationDistance {
        let location1 = CLLocation(latitude: coord1.latitude, longitude: coord1.longitude)
        let location2 = CLLocation(latitude: coord2.latitude, longitude: coord2.longitude)
        return location1.distance(from: location2)
    }
    
    /// Get shops sorted by distance from a coordinate
    func shopsSortedByDistance(from coordinate: CLLocationCoordinate2D) -> [CoffeeShop] {
        coffeeShops.sorted { shop1, shop2 in
            let coord1 = CLLocationCoordinate2D(latitude: shop1.latitude, longitude: shop1.longitude)
            let coord2 = CLLocationCoordinate2D(latitude: shop2.latitude, longitude: shop2.longitude)
            
            let distance1 = distance(from: coordinate, to: coord1)
            let distance2 = distance(from: coordinate, to: coord2)
            
            return distance1 < distance2
        }
    }
    
    /// Get nearest shop to a coordinate
    func nearestShop(to coordinate: CLLocationCoordinate2D) -> CoffeeShop? {
        shopsSortedByDistance(from: coordinate).first
    }
    
    /// Check if coordinate is within a reasonable bounds
    func isCoordinateValid(_ coordinate: CLLocationCoordinate2D) -> Bool {
        coordinate.latitude >= -90 && coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 && coordinate.longitude <= 180
    }
}

// MARK: - Search Extensions

extension ExploreViewModel {
    
    /// Get search suggestions based on current input
    var searchSuggestions: [String] {
        guard !searchText.isEmpty else { return [] }
        
        let query = searchText.lowercased()
        var suggestions: Set<String> = []
        
        // Add shop names that start with the query
        coffeeShops.forEach { shop in
            let name = shop.name.lowercased()
            if name.hasPrefix(query) && name != query {
                suggestions.insert(shop.name)
            }
        }
        
        // Add unique neighborhoods/areas from addresses
        coffeeShops.forEach { shop in
            let addressComponents = shop.address.lowercased().components(separatedBy: .whitespacesAndNewlines.union(.punctuationCharacters))
            addressComponents.forEach { component in
                if component.hasPrefix(query) && component != query && component.count > 2 {
                    suggestions.insert(component.capitalized)
                }
            }
        }
        
        return Array(suggestions).sorted().prefix(5).map { $0 }
    }
    
    /// Clear search and reset to default state
    func resetSearchState() {
        searchText = ""
        showSearchResults = false
        searchTask?.cancel()
    }
}
