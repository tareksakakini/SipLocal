/**
 * PassportViewModel.swift
 * SipLocal
 *
 * ViewModel for PassportView following MVVM architecture.
 * Handles loyalty stamps logic, progress tracking, and stamp operations.
 *
 * ## Responsibilities
 * - **Stamps Management**: Add/remove stamps with animation and feedback
 * - **Progress Tracking**: Calculate completion percentage and statistics
 * - **Data Loading**: Load coffee shop data for stamp display
 * - **State Management**: Handle stamp operations and loading states
 * - **User Feedback**: Provide visual feedback for stamp operations
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation with injected AuthenticationManager
 * - **Animation Coordination**: Smooth animations for stamp interactions
 * - **Progress Calculation**: Real-time progress updates
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - PassportViewModel

/**
 * ViewModel for PassportView
 * 
 * Manages loyalty stamps logic, progress tracking, and user interaction state.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class PassportViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private var authManager: AuthenticationManager
    
    // MARK: - Published State Properties
    @Published var coffeeShops: [CoffeeShop] = []
    @Published var isLoadingShops: Bool = true
    @Published var isPerformingStampOperation: Bool = false
    @Published var lastStampedShopId: String? = nil
    @Published var showStampFeedback: Bool = false
    @Published var stampFeedbackMessage: String = ""
    
    // MARK: - Design Constants
    private enum Design {
        static let gridColumns: Int = 3
        static let stampAnimationDuration: Double = 0.2
        static let feedbackDisplayDuration: Double = 1.5
        static let progressAnimationDuration: Double = 0.3
        static let stampOperationCooldown: Double = 0.5
        
        // Visual constants
        static let unstampedOpacity: Double = 0.6
        static let stampedOpacity: Double = 1.0
        static let unstampedGrayscale: Double = 1.0
        static let stampedGrayscale: Double = 0.0
        
        // Progress colors
        static let progressTintColor = Color.blue
        static let progressBackgroundColor = Color.gray.opacity(0.3)
    }
    
    // MARK: - Private State
    private var lastStampOperation: Date = Date.distantPast
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Returns the current stamped shops from AuthManager
    var stampedShops: Set<String> {
        Set(authManager.stampedShops)
    }
    
    /// Returns the total number of available stamps
    var totalStamps: Int {
        coffeeShops.count
    }
    
    /// Returns the number of collected stamps
    var collectedStamps: Int {
        stampedShops.count
    }
    
    /// Returns the completion percentage (0.0 to 1.0)
    var completionPercentage: Double {
        guard totalStamps > 0 else { return 0.0 }
        return Double(collectedStamps) / Double(totalStamps)
    }
    
    /// Returns the completion percentage as an integer (0 to 100)
    var completionPercentageInt: Int {
        Int(completionPercentage * 100)
    }
    
    /// Returns whether the user has collected all stamps
    var isCompleteCollection: Bool {
        totalStamps > 0 && collectedStamps == totalStamps
    }
    
    /// Returns a progress description for accessibility
    var progressDescription: String {
        "\(collectedStamps) of \(totalStamps) stamps collected. \(completionPercentageInt) percent complete."
    }
    
    /// Returns whether stamp operations are currently disabled
    var isStampOperationDisabled: Bool {
        isPerformingStampOperation || 
        Date().timeIntervalSince(lastStampOperation) < Design.stampOperationCooldown
    }
    
    /// Grid layout configuration
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible()), count: Design.gridColumns)
    }
    
    // MARK: - Initialization
    
    init(authManager: AuthenticationManager) {
        self.authManager = authManager
        loadCoffeeShops()
        setupProgressTracking()
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /// Load coffee shops data
    func loadCoffeeShops() {
        isLoadingShops = true
        
        // Simulate async loading (in real app, this might be from network/database)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.coffeeShops = DataService.loadCoffeeShops()
            self.isLoadingShops = false
            print("📍 Loaded \(self.coffeeShops.count) coffee shops for passport")
        }
    }
    
    /// Toggle stamp collection status for a coffee shop
    func toggleStamp(for shop: CoffeeShop) {
        // Prevent rapid-fire operations
        guard !isStampOperationDisabled else { return }
        
        let isCurrentlyStamped = stampedShops.contains(shop.id)
        lastStampOperation = Date()
        isPerformingStampOperation = true
        lastStampedShopId = shop.id
        
        withAnimation(.easeInOut(duration: Design.stampAnimationDuration)) {
            if isCurrentlyStamped {
                removeStamp(for: shop)
            } else {
                addStamp(for: shop)
            }
        }
        
        // Reset operation state
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.stampAnimationDuration) {
            self.isPerformingStampOperation = false
        }
    }
    
    /// Check if a shop is stamped
    func isStamped(_ shop: CoffeeShop) -> Bool {
        stampedShops.contains(shop.id)
    }
    
    /// Get stamp visual properties for a shop
    func stampVisualProperties(for shop: CoffeeShop) -> (opacity: Double, grayscale: Double) {
        let isStamped = isStamped(shop)
        return (
            opacity: isStamped ? Design.stampedOpacity : Design.unstampedOpacity,
            grayscale: isStamped ? Design.stampedGrayscale : Design.unstampedGrayscale
        )
    }
    
    /// Get accessibility information for a stamp
    func stampAccessibilityInfo(for shop: CoffeeShop) -> (label: String, value: String, hint: String) {
        let isStamped = isStamped(shop)
        return (
            label: "Stamp for \(shop.name)",
            value: isStamped ? "Collected" : "Not collected",
            hint: "Tap to \(isStamped ? "remove" : "add") stamp"
        )
    }
    
    /// Refresh stamps data
    func refreshStamps() {
        // Force refresh of stamped shops from auth manager
        objectWillChange.send()
        print("🔄 Refreshed passport stamps data")
    }
    
    /// Update the authentication manager (for environment object injection)
    func updateAuthManager(_ authManager: AuthenticationManager) {
        self.authManager = authManager
        setupProgressTracking()
    }
    
    // MARK: - Private Methods
    
    private func addStamp(for shop: CoffeeShop) {
        authManager.addStamp(shopId: shop.id) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showStampFeedback("✓ Stamp added for \(shop.name)!")
                    print("✅ Added stamp for: \(shop.name)")
                } else {
                    self?.showStampFeedback("Failed to add stamp")
                    print("❌ Failed to add stamp for: \(shop.name)")
                }
            }
        }
    }
    
    private func removeStamp(for shop: CoffeeShop) {
        authManager.removeStamp(shopId: shop.id) { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    self?.showStampFeedback("✗ Stamp removed for \(shop.name)")
                    print("🗑️ Removed stamp for: \(shop.name)")
                } else {
                    self?.showStampFeedback("Failed to remove stamp")
                    print("❌ Failed to remove stamp for: \(shop.name)")
                }
            }
        }
    }
    
    private func showStampFeedback(_ message: String) {
        stampFeedbackMessage = message
        showStampFeedback = true
        
        // Auto-hide feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.feedbackDisplayDuration) {
            self.showStampFeedback = false
        }
    }
    
    private func setupProgressTracking() {
        // Watch for changes in stamped shops to trigger progress updates
        // This would typically observe changes in the auth manager's stampedShops
        // For now, we'll rely on SwiftUI's automatic updates through @Published
        print("📊 Progress tracking setup for passport view")
    }
}

// MARK: - Statistics Extensions

extension PassportViewModel {
    
    /// Returns detailed statistics about stamp collection
    var collectionStatistics: (collected: Int, total: Int, percentage: Int, isComplete: Bool) {
        (
            collected: collectedStamps,
            total: totalStamps,
            percentage: completionPercentageInt,
            isComplete: isCompleteCollection
        )
    }
    
    /// Returns a formatted progress string
    var progressString: String {
        "\(collectedStamps)/\(totalStamps) stamps collected"
    }
    
    /// Returns shops grouped by stamp status
    var shopsGroupedByStatus: (stamped: [CoffeeShop], unstamped: [CoffeeShop]) {
        let stamped = coffeeShops.filter { stampedShops.contains($0.id) }
        let unstamped = coffeeShops.filter { !stampedShops.contains($0.id) }
        return (stamped: stamped, unstamped: unstamped)
    }
    
    /// Returns the next shop to visit (first unstamped shop)
    var nextShopToVisit: CoffeeShop? {
        coffeeShops.first { !stampedShops.contains($0.id) }
    }
    
    /// Returns achievement status
    var achievementStatus: String {
        switch completionPercentageInt {
        case 0:
            return "Start your coffee journey!"
        case 1..<25:
            return "Coffee Explorer"
        case 25..<50:
            return "Coffee Enthusiast"
        case 50..<75:
            return "Coffee Connoisseur"
        case 75..<100:
            return "Coffee Master"
        case 100:
            return "Coffee Legend! 🏆"
        default:
            return "Coffee Lover"
        }
    }
}
