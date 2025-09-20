/**
 * OrderViewModel.swift
 * SipLocal
 *
 * ViewModel for OrderView following MVVM architecture.
 * Handles coffee shop listing, search functionality, and business hours management.
 *
 * ## Responsibilities
 * - **Shop Listing**: Load and display coffee shops for ordering
 * - **Search Functionality**: Real-time search with filtering capabilities
 * - **Business Hours**: Manage business hours loading and status display
 * - **Navigation**: Handle navigation to menu selection and shop details
 * - **State Management**: Handle loading states and empty search results
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected CartManager
 * - **Search Logic**: Efficient filtering with real-time updates
 * - **Business Hours Integration**: Async business hours loading and caching
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - OrderViewModel

/**
 * ViewModel for OrderView
 * 
 * Manages coffee shop ordering interface, search functionality, and business hours.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class OrderViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var cartManager: CartManager
    
    // MARK: - Published State Properties
    @Published var coffeeShops: [CoffeeShop] = []
    @Published var searchText: String = ""
    @Published var isSearching: Bool = false
    @Published var isLoadingShops: Bool = true
    @Published var selectedShop: CoffeeShop?
    @Published var showMenuSelection: Bool = false
    
    // MARK: - Design Constants
    private enum Design {
        static let searchDebounceDelay: Double = 0.3
        static let loadingDelay: Double = 0.1
        static let businessHoursRefreshInterval: Double = 300.0 // 5 minutes
        static let maxSearchResults: Int = 50
        static let minSearchCharacters: Int = 2
    }
    
    // MARK: - Private State
    private var searchTask: Task<Void, Never>?
    private var businessHoursRefreshTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastBusinessHoursRefresh: Date = Date.distantPast
    
    // MARK: - Computed Properties
    
    /// Filtered coffee shops based on search text
    var filteredShops: [CoffeeShop] {
        let trimmedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return coffeeShops }
        
        let lowercasedSearch = trimmedSearch.lowercased()
        return coffeeShops.filter { shop in
            shop.name.lowercased().contains(lowercasedSearch) ||
            shop.address.lowercased().contains(lowercasedSearch) ||
            shop.description.lowercased().contains(lowercasedSearch)
        }
        .prefix(Design.maxSearchResults)
        .map { $0 }
    }
    
    /// Returns whether search results are empty
    var hasEmptySearchResults: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && filteredShops.isEmpty
    }
    
    /// Returns whether to show search results
    var shouldShowSearchResults: Bool {
        !searchText.isEmpty || isSearching
    }
    
    /// Returns shops sorted by availability (open shops first)
    var shopsSortedByAvailability: [CoffeeShop] {
        filteredShops.sorted { shop1, shop2 in
            let isOpen1 = cartManager.isShopOpen(shop: shop1) ?? false
            let isOpen2 = cartManager.isShopOpen(shop: shop2) ?? false
            
            if isOpen1 && !isOpen2 {
                return true
            } else if !isOpen1 && isOpen2 {
                return false
            } else {
                return shop1.name < shop2.name
            }
        }
    }
    
    /// Returns shops grouped by open/closed status
    var shopsGroupedByStatus: (open: [CoffeeShop], closed: [CoffeeShop], unknown: [CoffeeShop]) {
        var openShops: [CoffeeShop] = []
        var closedShops: [CoffeeShop] = []
        var unknownShops: [CoffeeShop] = []
        
        for shop in filteredShops {
            if let isOpen = cartManager.isShopOpen(shop: shop) {
                if isOpen {
                    openShops.append(shop)
                } else {
                    closedShops.append(shop)
                }
            } else {
                unknownShops.append(shop)
            }
        }
        
        return (
            open: openShops.sorted { $0.name < $1.name },
            closed: closedShops.sorted { $0.name < $1.name },
            unknown: unknownShops.sorted { $0.name < $1.name }
        )
    }
    
    /// Returns search suggestions based on current input
    var searchSuggestions: [String] {
        guard searchText.count >= Design.minSearchCharacters else { return [] }
        
        let query = searchText.lowercased()
        var suggestions: Set<String> = []
        
        // Add shop names that start with the query
        coffeeShops.forEach { shop in
            let name = shop.name.lowercased()
            if name.hasPrefix(query) && name != query {
                suggestions.insert(shop.name)
            }
        }
        
        return Array(suggestions).sorted().prefix(5).map { $0 }
    }
    
    // MARK: - Initialization
    
    init(cartManager: CartManager) {
        self.cartManager = cartManager
        setupSearchDebouncing()
        setupBusinessHoursRefresh()
        loadCoffeeShops()
    }
    
    deinit {
        searchTask?.cancel()
        businessHoursRefreshTimer?.invalidate()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Load coffee shops data
    func loadCoffeeShops() {
        isLoadingShops = true
        
        // Load coffee shops (instant from local data)
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.loadingDelay) {
            self.coffeeShops = DataService.loadCoffeeShops()
            self.isLoadingShops = false
            self.loadBusinessHoursForAllShops()
            print("🏪 Loaded \(self.coffeeShops.count) coffee shops for ordering")
        }
    }
    
    /// Handle search text changes
    func handleSearchTextChange(_ newValue: String) {
        searchText = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Start searching (focus on search bar)
    func startSearching() {
        isSearching = true
    }
    
    /// Stop searching (unfocus search bar)
    func stopSearching() {
        isSearching = false
    }
    
    /// Clear search text and results
    func clearSearch() {
        withAnimation(.easeInOut(duration: 0.2)) {
            searchText = ""
            isSearching = false
        }
    }
    
    /// Navigate to menu selection for a shop
    func navigateToMenuSelection(for shop: CoffeeShop) {
        selectedShop = shop
        showMenuSelection = true
        print("📋 Navigating to menu selection for: \(shop.name)")
    }
    
    /// Get business hours status for a shop
    func getBusinessHoursStatus(for shop: CoffeeShop) -> BusinessHoursStatus {
        if let isLoading = cartManager.isLoadingBusinessHours[shop.id], isLoading {
            return .loading
        } else if let isOpen = cartManager.isShopOpen(shop: shop) {
            return isOpen ? .open : .closed
        } else {
            return .unknown
        }
    }
    
    /// Check if business hours are loading for a shop
    func isBusinessHoursLoading(for shop: CoffeeShop) -> Bool {
        cartManager.isLoadingBusinessHours[shop.id] ?? false
    }
    
    /// Refresh business hours for all shops
    func refreshBusinessHours() {
        guard Date().timeIntervalSince(lastBusinessHoursRefresh) > Design.businessHoursRefreshInterval else {
            return
        }
        
        loadBusinessHoursForAllShops()
    }
    
    /// Get shop by ID
    func getShop(by id: String) -> CoffeeShop? {
        coffeeShops.first { $0.id == id }
    }
    
    /// Update the cart manager (for environment object injection)
    func updateCartManager(_ cartManager: CartManager) {
        self.cartManager = cartManager
    }
    
    /// Reset all states
    func resetState() {
        searchText = ""
        isSearching = false
        selectedShop = nil
        showMenuSelection = false
        searchTask?.cancel()
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
    
    private func setupBusinessHoursRefresh() {
        businessHoursRefreshTimer = Timer.scheduledTimer(withTimeInterval: Design.businessHoursRefreshInterval, repeats: true) { [weak self] _ in
            self?.refreshBusinessHours()
        }
    }
    
    private func performSearch(query: String) {
        searchTask?.cancel()
        
        searchTask = Task {
            await MainActor.run {
                // Search results are computed via filteredShops property
                if !query.isEmpty && self.filteredShops.isEmpty {
                    print("🔍 No shops found for: \"\(query)\"")
                } else if !query.isEmpty {
                    print("🔍 Found \(self.filteredShops.count) shops for: \"\(query)\"")
                }
            }
        }
    }
    
    private func loadBusinessHoursForAllShops() {
        lastBusinessHoursRefresh = Date()
        
        // Load business hours for all shops asynchronously
        for shop in coffeeShops {
            Task {
                await cartManager.fetchBusinessHours(for: shop)
            }
        }
        
        print("⏰ Loading business hours for \(coffeeShops.count) shops")
    }
}

// MARK: - Business Hours Status

enum BusinessHoursStatus {
    case loading
    case open
    case closed
    case unknown
    
    var displayText: String {
        switch self {
        case .loading:
            return "Loading..."
        case .open:
            return "Open"
        case .closed:
            return "Closed"
        case .unknown:
            return ""
        }
    }
    
    var color: Color {
        switch self {
        case .loading:
            return .orange
        case .open:
            return .green
        case .closed:
            return .red
        case .unknown:
            return .clear
        }
    }
}

// MARK: - Search Extensions

extension OrderViewModel {
    
    /// Advanced search with multiple criteria
    func advancedSearch(query: String, includeDescription: Bool = true, includeAddress: Bool = true) -> [CoffeeShop] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return coffeeShops }
        
        let lowercasedQuery = trimmedQuery.lowercased()
        
        return coffeeShops.compactMap { shop -> (CoffeeShop, Int)? in
            var score = 0
            let shopName = shop.name.lowercased()
            let shopAddress = shop.address.lowercased()
            let shopDescription = shop.description.lowercased()
            
            // Exact name match gets highest priority
            if shopName == lowercasedQuery {
                score = 100
            }
            // Name starts with query
            else if shopName.hasPrefix(lowercasedQuery) {
                score = 80
            }
            // Name contains query
            else if shopName.contains(lowercasedQuery) {
                score = 60
            }
            // Address contains query (if enabled)
            else if includeAddress && shopAddress.contains(lowercasedQuery) {
                score = 40
            }
            // Description contains query (if enabled)
            else if includeDescription && shopDescription.contains(lowercasedQuery) {
                score = 30
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
    
    /// Get popular search terms (mock implementation)
    var popularSearchTerms: [String] {
        return ["Coffee", "Espresso", "Downtown", "Drive-thru", "WiFi"]
    }
}

// MARK: - Analytics Extensions

extension OrderViewModel {
    
    /// Get ordering statistics
    var orderingStatistics: (totalShops: Int, openShops: Int, closedShops: Int) {
        let grouped = shopsGroupedByStatus
        return (
            totalShops: coffeeShops.count,
            openShops: grouped.open.count,
            closedShops: grouped.closed.count
        )
    }
    
    /// Get search analytics
    func trackSearchQuery(_ query: String) {
        // In a real app, this would send analytics data
        print("📊 Search query tracked: \"\(query)\" -> \(filteredShops.count) results")
    }
}
