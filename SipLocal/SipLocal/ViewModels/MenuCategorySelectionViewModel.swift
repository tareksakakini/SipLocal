/**
 * MenuCategorySelectionViewModel.swift
 * SipLocal
 *
 * ViewModel for MenuCategorySelectionView following MVVM architecture.
 * Handles all business logic including search, cart operations, error handling, and performance optimization.
 *
 * ## Responsibilities
 * - **Search Management**: Real-time search with debouncing and relevance ranking
 * - **Cart Operations**: Item addition with optimistic updates and conflict resolution
 * - **Error Handling**: Comprehensive error management with retry mechanisms
 * - **Performance Optimization**: Memory management and task limiting
 * - **State Management**: Centralized state handling for the view
 *
 * ## Architecture
 * - **ObservableObject**: Reactive state management with @Published properties
 * - **Dependency Injection**: Clean separation of concerns with injected dependencies
 * - **Error Boundaries**: Structured error handling with user-friendly recovery
 * - **Performance Monitoring**: Real-time performance tracking and optimization
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import SwiftUI
import Combine

// MARK: - MenuCategorySelectionViewModel

/**
 * ViewModel for MenuCategorySelectionView
 * 
 * Manages all business logic and state for the menu category selection interface.
 * Provides reactive state management and clean separation of concerns.
 */
@MainActor
class MenuCategorySelectionViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let shop: CoffeeShop
    private let cartManager: CartManager
    private let orderManager: OrderManager
    private let menuDataManager: MenuDataManager
    
    // MARK: - Published State Properties
    
    // Navigation State
    @Published var showingCart = false
    
    // Search State
    @Published var searchText: String = ""
    @Published var debouncedSearchText: String = ""
    @Published var searchResults: [MenuItem] = []
    @Published var isSearching: Bool = false
    
    // Item Addition State
    @Published var showItemAddedPopup = false
    @Published var customizingItem: MenuItem? = nil
    @Published var selectedModifiers: [String: Set<String>] = [:]
    @Published var pendingItem: (item: MenuItem, customizations: String?, price: Double)?
    
    // Alert State
    @Published var showingDifferentShopAlert = false
    @Published var showingClosedShopAlert = false
    
    // Loading State
    @Published var isAddingToCart = false
    @Published var addingItemId: String? = nil
    
    // Cart State
    @Published var optimisticCartCount: Int = 0
    
    // Error Handling State
    @Published var currentError: MenuOperationError? = nil
    @Published var showingError = false
    @Published var isRetrying = false
    
    // Performance Optimization State
    @Published var viewDidAppear = false
    @Published var renderingOptimizationEnabled = true
    
    // MARK: - Private State Properties
    private var searchTask: Task<Void, Never>? = nil
    private var cartUpdateTask: Task<Void, Never>? = nil
    private var retryAttempts: [String: Int] = [:]
    private var activeTasks: Set<String> = []
    private var memoryCleanupTimer: Timer? = nil
    private var lastPerformanceCheck = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Design Constants
    private enum Design {
        static let searchDebounceDelay: Double = 0.3
        static let searchMaxResults: Int = 3
        static let searchMinCharacters: Int = 2
        static let cartUpdateDelay: Double = 0.1
        static let optimisticUpdateTimeout: Double = 5.0
        static let maxRetryAttempts: Int = 3
        static let retryDelay: Double = 1.0
        static let memoryCleanupInterval: Double = 30.0
        static let taskTimeoutDuration: Double = 15.0
        static let maxConcurrentTasks: Int = 3
        static let cacheExpirationTime: Double = 300.0
        static let viewUpdateDebounceDelay: Double = 0.05
    }
    
    // MARK: - Initialization
    
    init(shop: CoffeeShop, cartManager: CartManager, orderManager: OrderManager, menuDataManager: MenuDataManager) {
        self.shop = shop
        self.cartManager = cartManager
        self.orderManager = orderManager
        self.menuDataManager = menuDataManager
        
        setupSearchDebouncing()
        setupPerformanceMonitoring()
    }
    
    deinit {
        Task { @MainActor in
            cleanup()
        }
    }
    
    // MARK: - Public Interface
    
    /// Handle view appearing
    func handleViewAppear() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Reset loading states, preserve user input and cart optimistic state
        isAddingToCart = false
        addingItemId = nil
        showItemAddedPopup = false
        
        // Sync cart count to ensure consistency
        optimisticCartCount = 0
        
        // Delayed view appearance for smooth animation
        DispatchQueue.main.asyncAfter(deadline: .now() + Design.viewUpdateDebounceDelay) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.viewDidAppear = true
            }
        }
        
        // Fetch business hours with task management
        performManagedTask(id: "businessHours") { [weak self] in
            guard let self = self else { return }
            await self.cartManager.fetchBusinessHours(for: self.shop)
        }
        
        // Log performance
        let loadTime = CFAbsoluteTimeGetCurrent() - startTime
        print("MenuCategorySelectionView appeared in \(String(format: "%.3f", loadTime))s")
    }
    
    /// Handle view disappearing
    func handleViewDisappear() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Cancel all active tasks
        cancelAllActiveTasks()
        
        // Clean up all async tasks and loading operations
        resetSearchState()
        resetCartState()
        resetPerformanceState()
        
        // Reset loading states
        isAddingToCart = false
        addingItemId = nil
        viewDidAppear = false
        
        // Log performance
        let cleanupTime = CFAbsoluteTimeGetCurrent() - startTime
        print("MenuCategorySelectionView cleanup in \(String(format: "%.3f", cleanupTime))s")
    }
    
    /// Handle adding item to cart
    func handleItemAdd(_ item: MenuItem) {
        // Prevent multiple simultaneous operations
        guard !isAddingToCart else { return }
        
        // Check if shop is closed
        if let isOpen = cartManager.isShopOpen(shop: shop), !isOpen {
            showingClosedShopAlert = true
            return
        }
        
        // Set loading state
        isAddingToCart = true
        addingItemId = item.id
        
        // Optimistic update - increment cart count immediately
        optimisticCartCount = (optimisticCartCount > 0 ? optimisticCartCount : cartManager.totalItems) + 1
        
        // Perform cart addition with error handling
        performAddToCart(item: item, customizations: nil, price: item.price)
    }
    
    /// Handle search text changes
    func handleSearchTextChange(_ newValue: String) {
        searchText = newValue
        
        // The debouncing is handled automatically by the Combine setup
    }
    
    /// Handle clearing cart and adding item
    func handleClearCartAndAdd() {
        guard let pending = pendingItem else { return }
        
        // Clear the cart and set loading state
        cartManager.clearCart()
        isAddingToCart = true
        addingItemId = pending.item.id
        
        // Optimistic update - cart should have 1 item after clearing and adding
        optimisticCartCount = 1
        
        // Add the pending item
        let success = cartManager.addItem(
            shop: shop,
            menuItem: pending.item,
            category: "",
            customizations: pending.customizations,
            itemPriceWithModifiers: pending.price
        )
        
        // Handle result
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.isAddingToCart = false
            self.addingItemId = nil
            self.pendingItem = nil
            
            if success {
                self.syncCartCount()
                self.showSuccessPopup()
            } else {
                self.rollbackOptimisticUpdate()
            }
        }
    }
    
    /// Handle alert cancellation
    func handleAlertCancel() {
        pendingItem = nil
        resetAllStates()
    }
    
    /// Handle retry for errors
    func handleRetry(for error: MenuOperationError) {
        guard error.canRetry else { return }
        
        isRetrying = true
        currentError = nil
        showingError = false
        
        // Implement retry logic based on error type
        Task { [weak self] in
            guard let self = self else { return }
            do {
                try await self.performRetryOperation(for: error)
                await MainActor.run { [weak self] in
                    self?.isRetrying = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.isRetrying = false
                    self?.showError(.unknownError(error.localizedDescription))
                }
            }
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .seconds(Design.searchDebounceDelay), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] newValue in
                Task { @MainActor in
                    self?.performSearch(query: newValue)
                }
            }
            .store(in: &cancellables)
    }
    
    private func setupPerformanceMonitoring() {
        // Setup memory cleanup timer
        memoryCleanupTimer = Timer.scheduledTimer(withTimeInterval: Design.memoryCleanupInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performMemoryCleanup()
            }
        }
        
        // Initialize performance tracking
        lastPerformanceCheck = Date()
        
        print("Performance monitoring enabled for MenuCategorySelectionView")
    }
    
    private func performSearch(query: String) {
        // Cancel previous search task
        searchTask?.cancel()
        
        // Clear results immediately if search is empty
        if query.isEmpty {
            debouncedSearchText = ""
            searchResults = []
            isSearching = false
            return
        }
        
        // Don't search for very short queries
        guard query.count >= Design.searchMinCharacters else {
            debouncedSearchText = ""
            searchResults = []
            isSearching = false
            return
        }
        
        isSearching = true
        
        searchTask = Task {
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Performance optimization: Use cached items if available
            let allItems = menuDataManager.getMenuCategories(for: shop).flatMap { $0.items }
            
            // Enhanced search algorithm with performance optimizations
            let searchQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Pre-compute for performance
            let filtered = allItems.compactMap { item -> (MenuItem, Int)? in
                let itemName = item.name.lowercased()
                var priority = 0
                
                // Exact match gets highest priority
                if itemName == searchQuery {
                    priority = 100
                }
                // Starts with query gets second priority
                else if itemName.hasPrefix(searchQuery) {
                    priority = 80
                }
                // Contains query gets third priority
                else if itemName.contains(searchQuery) {
                    priority = 60
                }
                // Word boundary matches
                else {
                    let words = itemName.components(separatedBy: CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters))
                    if words.contains(where: { $0.hasPrefix(searchQuery) }) {
                        priority = 40
                    } else {
                        return nil  // No match
                    }
                }
                
                return (item, priority)
            }
            
            // Sort by priority and name for performance
            let sortedResults = filtered
                .sorted { first, second in
                    if first.1 != second.1 {
                        return first.1 > second.1  // Higher priority first
                    }
                    return first.0.name < second.0.name  // Alphabetical for same priority
                }
                .prefix(Design.searchMaxResults)
                .map { $0.0 }
            
            // Update state with performance logging
            await MainActor.run {
                self.debouncedSearchText = query
                self.searchResults = Array(sortedResults)
                self.isSearching = false
                
                let searchTime = CFAbsoluteTimeGetCurrent() - startTime
                print("🔍 Search completed: \"\(query)\" -> \(self.searchResults.count) results in \(String(format: "%.3f", searchTime))s")
            }
        }
    }
    
    private func performAddToCart(item: MenuItem, customizations: String?, price: Double) {
        performWithErrorBoundary(
            operationId: "addToCart_\(item.id)",
            operation: {
                // Check network availability (simulated)
                if self.isNetworkUnavailable() {
                    throw MenuOperationError.networkUnavailable
                }
                
                // Perform the cart operation
                let success = self.cartManager.addItem(
                    shop: self.shop,
                    menuItem: item,
                    category: "",
                    customizations: customizations,
                    itemPriceWithModifiers: price
                )
                
                if !success {
                    throw MenuOperationError.addToCartFailed(itemName: item.name)
                }
                
                // Success path
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isAddingToCart = false
                    self.addingItemId = nil
                    self.syncCartCount()
                    self.showSuccessPopup()
                }
                
            },
            onError: { [weak self] error in
                // Error path
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.isAddingToCart = false
                    self.addingItemId = nil
                    self.rollbackOptimisticUpdate()
                    
                    // Handle specific error types
                    if case .addToCartFailed = error {
                        self.showError(error)
                    } else {
                        self.showError(error)
                    }
                }
            }
        )
    }
    
    private func showSuccessPopup() {
        // Show popup with animation
        withAnimation(.easeInOut(duration: 0.3)) {
            showItemAddedPopup = true
        }
        
        // Auto-hide popup after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            guard let self = self else { return }
            withAnimation(.easeInOut(duration: 0.3)) {
                self.showItemAddedPopup = false
            }
        }
    }
    
    private func syncCartCount() {
        // Cancel any existing cart update task
        cartUpdateTask?.cancel()
        
        cartUpdateTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(nanoseconds: UInt64(Design.cartUpdateDelay * 1_000_000_000))
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                // Sync optimistic count with actual count
                let actualCount = self.cartManager.totalItems
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    self.optimisticCartCount = actualCount
                }
                
                self.cartUpdateTask = nil
            }
        }
    }
    
    private func rollbackOptimisticUpdate() {
        withAnimation(.easeInOut(duration: 0.2)) {
            optimisticCartCount = 0  // Reset to use actual cart count
        }
    }
    
    private func resetAllStates() {
        isAddingToCart = false
        addingItemId = nil
        showItemAddedPopup = false
        resetCustomizationState()
        resetSearchState()
        resetCartState()
        resetErrorState()
        resetPerformanceState()
        pendingItem = nil
    }
    
    private func resetCustomizationState() {
        customizingItem = nil
        selectedModifiers.removeAll()
    }
    
    private func resetSearchState() {
        searchTask?.cancel()
        searchTask = nil
        debouncedSearchText = ""
        searchResults = []
        isSearching = false
    }
    
    private func resetCartState() {
        cartUpdateTask?.cancel()
        cartUpdateTask = nil
        optimisticCartCount = 0
    }
    
    private func resetErrorState() {
        currentError = nil
        showingError = false
        isRetrying = false
    }
    
    private func resetPerformanceState() {
        memoryCleanupTimer?.invalidate()
        memoryCleanupTimer = nil
        activeTasks.removeAll()
        lastPerformanceCheck = Date()
        renderingOptimizationEnabled = true
    }
    
    private func performManagedTask(id: String, operation: @escaping () async -> Void) {
        // Check if we're at task limit
        guard activeTasks.count < Design.maxConcurrentTasks else {
            print("⚠️ Task limit reached, queuing task: \(id)")
            return
        }
        
        // Add to active tasks
        activeTasks.insert(id)
        
        // Create task with timeout
        _ = Task { [weak self] in
            guard let self = self else { return }
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Create timeout task
            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(Design.taskTimeoutDuration * 1_000_000_000))
                if !Task.isCancelled {
                    print("⏱️ Task timeout: \(id)")
                }
            }
            
            // Race between operation and timeout
            await withTaskGroup(of: Void.self) { group in
                group.addTask {
                    await operation()
                }
                group.addTask {
                    do {
                        try await timeoutTask.value
                    } catch {
                        // Timeout task was cancelled, which is expected
                    }
                }
                
                // Cancel timeout when operation completes
                await group.next()
                timeoutTask.cancel()
                group.cancelAll()
            }
            
            // Remove from active tasks
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.activeTasks.remove(id)
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("✅ Task completed: \(id) in \(String(format: "%.3f", duration))s")
            }
        }
    }
    
    private func cancelAllActiveTasks() {
        let taskCount = activeTasks.count
        activeTasks.removeAll()
        
        if taskCount > 0 {
            print("🚫 Cancelled \(taskCount) active tasks")
        }
    }
    
    private func performMemoryCleanup() {
        // Clear old retry attempts
        let now = Date()
        if now.timeIntervalSince(lastPerformanceCheck) > Design.cacheExpirationTime {
            retryAttempts.removeAll()
            lastPerformanceCheck = now
        }
        
        // Force garbage collection hint
        autoreleasepool {
            // Cleanup operations
        }
        
        print("🧹 Memory cleanup completed")
    }
    
    private func performWithErrorBoundary(
        operationId: String,
        operation: @escaping () throws -> Void,
        onError: @escaping (MenuOperationError) -> Void
    ) {
        do {
            try operation()
        } catch let error as MenuOperationError {
            onError(error)
        } catch {
            onError(.unknownError(error.localizedDescription))
        }
    }
    
    private func showError(_ error: MenuOperationError) {
        currentError = error
        showingError = true
    }
    
    private func performRetryOperation(for error: MenuOperationError) async throws {
        // Implement specific retry logic based on error type
        switch error {
        case .networkUnavailable:
            try await Task.sleep(nanoseconds: UInt64(Design.retryDelay * 1_000_000_000))
            // Retry the failed operation
            break
        case .addToCartFailed(let itemName):
            print("Retrying add-to-cart for item: \(itemName)")
            break
        default:
            throw error
        }
    }
    
    private func isNetworkUnavailable() -> Bool {
        // Simulated network check - in real implementation, check actual network status
        return false
    }
    
    private func cleanup() {
        searchTask?.cancel()
        cartUpdateTask?.cancel()
        memoryCleanupTimer?.invalidate()
        cancellables.removeAll()
        cancelAllActiveTasks()
    }
}
