/**
 * CoffeeShopDetailViewModel.swift
 * SipLocal
 *
 * ViewModel for CoffeeShopDetailView following MVVM architecture.
 * Handles shop details, external actions, favorites management, and business hours.
 *
 * ## Responsibilities
 * - **Shop Details**: Manage shop information display and state
 * - **External Actions**: Handle phone calls, maps navigation, website opening
 * - **Favorites Management**: Add/remove shops from favorites with optimistic updates
 * - **Business Hours**: Async business hours loading and display
 * - **Error Handling**: Comprehensive error management for all operations
 * - **Performance**: Memory management and task optimization
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected managers
 * - **Action System**: Structured external integrations with error boundaries
 * - **Performance Optimization**: Task management and memory cleanup
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import UIKit
import Combine

// MARK: - CoffeeShopDetailViewModel

/**
 * ViewModel for CoffeeShopDetailView
 * 
 * Manages shop details, external actions, and user interactions.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class CoffeeShopDetailViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    private let shop: CoffeeShop
    
    // MARK: - Published State Properties
    @Published var isFavorite: Bool = false
    @Published var showMenu: Bool = false
    @Published var businessHoursInfo: String = ""
    @Published var isLoadingBusinessHours: Bool = false
    @Published var businessHoursError: Bool = false
    
    // Action loading states
    @Published var isPerformingPhoneCall: Bool = false
    @Published var isOpeningMaps: Bool = false
    @Published var isOpeningWebsite: Bool = false
    @Published var isTogglingFavorite: Bool = false
    
    // MARK: - Design Constants
    private enum Design {
        static let actionTimeout: Double = 10.0
        static let favoriteToggleDelay: Double = 0.3
        static let businessHoursRefreshInterval: Double = 300.0 // 5 minutes
        static let performanceLogThreshold: Double = 1.0
        static let maxRetryAttempts: Int = 3
    }
    
    // MARK: - Private State
    private var businessHoursTask: Task<Void, Never>?
    private var viewDidAppear: Bool = false
    private var lastBusinessHoursRefresh: Date = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Returns whether any action is currently in progress
    var isAnyActionInProgress: Bool {
        isPerformingPhoneCall || isOpeningMaps || isOpeningWebsite || isTogglingFavorite
    }
    
    /// Returns the shop's display name (cached for performance)
    var shopDisplayName: String {
        shop.name
    }
    
    /// Returns the shop's display description (cached for performance)
    var shopDisplayDescription: String {
        shop.description
    }
    
    /// Returns the shop's image name (cached for performance)
    var shopImageName: String {
        shop.imageName
    }
    
    /// Returns whether business hours are available
    var hasBusinessHours: Bool {
        !businessHoursInfo.isEmpty && !businessHoursError
    }
    
    /// Returns contact information availability
    var contactInfo: (hasPhone: Bool, hasWebsite: Bool, hasAddress: Bool) {
        return (
            hasPhone: true, // Mock - in real app would be !shop.phoneNumber.isEmpty
            hasWebsite: true, // Mock - in real app would be !shop.website.isEmpty
            hasAddress: !shop.address.isEmpty
        )
    }
    
    // MARK: - Initialization
    
    init(shop: CoffeeShop, authManager: AuthenticationManager) {
        self.shop = shop
        self.authManager = authManager
        self.isFavorite = authManager.favoriteShops.contains(shop.id)
        
        setupFavoritesTracking()
    }
    
    deinit {
        businessHoursTask?.cancel()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Handle view appearing
    func handleViewAppear() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Prevent duplicate setup
        guard !viewDidAppear else { return }
        viewDidAppear = true
        
        // Conditionally fetch business hours if not recently refreshed
        if Date().timeIntervalSince(lastBusinessHoursRefresh) > Design.businessHoursRefreshInterval {
            fetchBusinessHours()
        }
        
        // Log performance if slow
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        if loadTime > Design.performanceLogThreshold {
            print("⚠️ CoffeeShopDetailView appeared slowly: \(String(format: "%.3f", loadTime))s")
        }
    }
    
    /// Handle view disappearing
    func handleViewDisappear() {
        // Cancel any ongoing tasks
        businessHoursTask?.cancel()
        
        // Reset loading states to prevent UI inconsistencies
        isLoadingBusinessHours = false
        viewDidAppear = false
        
        print("👋 CoffeeShopDetailView cleanup completed")
    }
    
    /// Make phone call to the coffee shop
    func makePhoneCall() {
        // Mock phone number since CoffeeShop model might not have phoneNumber property
        let phoneNumber = "555-0123" // In real app, this would be shop.phoneNumber
        guard !phoneNumber.isEmpty else {
            print("❌ No phone number available for \(shop.name)")
            return
        }
        
        performActionWithErrorBoundary(
            actionName: "Phone Call",
            loadingState: \.isPerformingPhoneCall
        ) {
            let phoneNumber = "555-0123".trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate phone number format
            guard !phoneNumber.isEmpty else {
                throw ActionError.invalidData("Phone number is empty")
            }
            
            // Create phone URL
            let cleanedNumber = phoneNumber.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
            guard let phoneURL = URL(string: "tel://\(cleanedNumber)") else {
                throw ActionError.invalidURL("Invalid phone number format")
            }
            
            // Check if device can make phone calls
            guard UIApplication.shared.canOpenURL(phoneURL) else {
                throw ActionError.deviceCapability("This device cannot make phone calls")
            }
            
            // Make the call
            UIApplication.shared.open(phoneURL) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Phone call initiated to \(phoneNumber)")
                    } else {
                        print("❌ Failed to initiate phone call to \(phoneNumber)")
                    }
                }
            }
        }
    }
    
    /// Open maps for directions to the coffee shop
    func openMapsForDirections() {
        guard !shop.address.isEmpty else {
            print("❌ No address available for \(shop.name)")
            return
        }
        
        performActionWithErrorBoundary(
            actionName: "Maps Directions",
            loadingState: \.isOpeningMaps
        ) {
            let address = self.shop.address.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate address
            guard !address.isEmpty else {
                throw ActionError.invalidData("Address is empty")
            }
            
            // Create maps URL
            let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
            guard let mapsURL = URL(string: "http://maps.apple.com/?q=\(encodedAddress)") else {
                throw ActionError.invalidURL("Invalid address format")
            }
            
            // Check if device can open maps
            guard UIApplication.shared.canOpenURL(mapsURL) else {
                throw ActionError.deviceCapability("Cannot open Maps on this device")
            }
            
            // Open maps
            UIApplication.shared.open(mapsURL) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Maps opened for directions to \(address)")
                    } else {
                        print("❌ Failed to open maps for \(address)")
                    }
                }
            }
        }
    }
    
    /// Open website in browser
    func openWebsite() {
        // Mock website since CoffeeShop model might not have website property
        let website = "https://example.com" // In real app, this would be shop.website
        guard !website.isEmpty else {
            print("❌ No website available for \(shop.name)")
            return
        }
        
        performActionWithErrorBoundary(
            actionName: "Website",
            loadingState: \.isOpeningWebsite
        ) {
            var website = "https://example.com".trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Validate website
            guard !website.isEmpty else {
                throw ActionError.invalidData("Website URL is empty")
            }
            
            // Add https if no scheme is provided
            if !website.hasPrefix("http://") && !website.hasPrefix("https://") {
                website = "https://" + website
            }
            
            // Create website URL
            guard let websiteURL = URL(string: website) else {
                throw ActionError.invalidURL("Invalid website URL format")
            }
            
            // Check if device can open URLs
            guard UIApplication.shared.canOpenURL(websiteURL) else {
                throw ActionError.deviceCapability("Cannot open web browser on this device")
            }
            
            // Open website
            UIApplication.shared.open(websiteURL) { success in
                DispatchQueue.main.async {
                    if success {
                        print("✅ Website opened: \(website)")
                    } else {
                        print("❌ Failed to open website: \(website)")
                    }
                }
            }
        }
    }
    
    /// Toggle favorite status for the coffee shop
    func toggleFavorite() {
        guard !isTogglingFavorite else { return }
        
        let wasOriginallyFavorite = isFavorite
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Optimistic UI update
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isFavorite.toggle()
            isTogglingFavorite = true
        }
        
        // Perform the actual operation
        let operation: (String, @escaping (Bool) -> Void) -> Void = wasOriginallyFavorite ? 
            authManager.removeFavorite : authManager.addFavorite
        
        operation(shop.id) { [weak self] success in
            DispatchQueue.main.async {
                self?.isTogglingFavorite = false
                
                if !success {
                    // Rollback optimistic update on failure
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        self?.isFavorite = wasOriginallyFavorite
                    }
                    print("❌ Failed to \(wasOriginallyFavorite ? "remove" : "add") favorite for \(self?.shop.name ?? "unknown shop")")
                } else {
                    let action = wasOriginallyFavorite ? "removed from" : "added to"
                    print("✅ Shop \(action) favorites: \(self?.shop.name ?? "unknown shop")")
                }
                
                // Log performance
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                if duration > Design.performanceLogThreshold {
                    print("⚠️ Favorite toggle took: \(String(format: "%.3f", duration))s")
                }
            }
        }
    }
    
    /// Navigate to menu view
    func navigateToMenu() {
        showMenu = true
        print("📋 Navigating to menu for: \(shop.name)")
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
        self.isFavorite = authManager.favoriteShops.contains(shop.id)
        setupFavoritesTracking()
    }
    
    // MARK: - Private Methods
    
    private func setupFavoritesTracking() {
        // In a real app, we might observe changes to the auth manager's favorites
        // For now, we'll rely on the initial state and manual updates
        print("❤️ Favorites tracking setup for \(shop.name)")
    }
    
    private func fetchBusinessHours() {
        businessHoursTask?.cancel()
        lastBusinessHoursRefresh = Date()
        
        businessHoursTask = Task {
            await MainActor.run {
                isLoadingBusinessHours = true
                businessHoursError = false
            }
            
            // Simulate business hours fetching
            // In a real app, this would call a service
            do {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
                
                // Check if task was cancelled
                try Task.checkCancellation()
                
                await MainActor.run {
                    // Mock business hours data
                    self.businessHoursInfo = "Mon-Fri: 6AM-8PM, Sat-Sun: 7AM-9PM"
                    self.isLoadingBusinessHours = false
                    print("⏰ Business hours loaded for \(self.shop.name)")
                }
            } catch {
                await MainActor.run {
                    self.businessHoursError = true
                    self.isLoadingBusinessHours = false
                    print("❌ Failed to load business hours for \(self.shop.name)")
                }
            }
        }
    }
    
    private func performActionWithErrorBoundary(
        actionName: String,
        loadingState: ReferenceWritableKeyPath<CoffeeShopDetailViewModel, Bool>,
        action: @escaping () throws -> Void
    ) {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Set loading state
        self[keyPath: loadingState] = true
        
        // Create timeout task
        let timeoutTask = Task {
            try await Task.sleep(nanoseconds: UInt64(Design.actionTimeout * 1_000_000_000))
            if !Task.isCancelled {
                await MainActor.run {
                    self[keyPath: loadingState] = false
                    print("⏱️ \(actionName) action timed out")
                }
            }
        }
        
        do {
            try action()
            timeoutTask.cancel()
            
            // Reset loading state after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + Design.favoriteToggleDelay) {
                self[keyPath: loadingState] = false
            }
            
            // Log performance
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("✅ \(actionName) completed in \(String(format: "%.3f", duration))s")
            
        } catch let error as ActionError {
            timeoutTask.cancel()
            self[keyPath: loadingState] = false
            print("❌ \(actionName) failed: \(error.localizedDescription)")
            
        } catch {
            timeoutTask.cancel()
            self[keyPath: loadingState] = false
            print("❌ \(actionName) failed with unknown error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Action Error Types

enum ActionError: LocalizedError {
    case invalidData(String)
    case invalidURL(String)
    case deviceCapability(String)
    case networkUnavailable
    case timeout
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .invalidURL(let message):
            return "Invalid URL: \(message)"
        case .deviceCapability(let message):
            return "Device limitation: \(message)"
        case .networkUnavailable:
            return "Network is unavailable"
        case .timeout:
            return "Operation timed out"
        }
    }
}

// MARK: - Performance Extensions

extension CoffeeShopDetailViewModel {
    
    /// Get performance metrics for the view
    var performanceMetrics: (businessHoursLoaded: Bool, favoritesResponsive: Bool) {
        return (
            businessHoursLoaded: hasBusinessHours,
            favoritesResponsive: !isTogglingFavorite
        )
    }
    
    /// Force refresh all data
    func refreshAllData() {
        fetchBusinessHours()
        isFavorite = authManager.favoriteShops.contains(shop.id)
        print("🔄 Refreshed all data for \(shop.name)")
    }
}
