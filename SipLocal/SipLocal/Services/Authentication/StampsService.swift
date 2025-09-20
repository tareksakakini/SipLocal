/**
 * StampsService.swift
 * SipLocal
 *
 * Service responsible for loyalty stamps management.
 * Extracted from AuthenticationManager to follow Single Responsibility Principle.
 *
 * ## Responsibilities
 * - **Stamps CRUD**: Add, remove, fetch user loyalty stamps
 * - **Progress Tracking**: Calculate completion percentages and achievements
 * - **Real-time Updates**: Maintain synchronized stamps state
 * - **Gamification**: Handle loyalty rewards and milestones
 *
 * ## Architecture
 * - **Single Responsibility**: Focused only on loyalty stamps management
 * - **Reactive State**: Observable stamps with real-time updates
 * - **Achievement System**: Built-in progress tracking and rewards
 * - **Performance**: Efficient operations with local caching
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */

import Foundation
import Firebase
import FirebaseFirestore
import Combine

// MARK: - StampsService

/**
 * Service for managing user loyalty stamps operations
 * 
 * Handles all stamps-related operations with progress tracking and achievements.
 * Provides reactive state management for real-time UI updates.
 */
class StampsService: ObservableObject {
    
    // MARK: - Published State
    @Published var stampedShops: Set<String> = []
    
    // MARK: - Dependencies
    private let firestore: Firestore
    private let userId: String?
    
    // MARK: - Configuration
    private enum Configuration {
        static let collectionName = "users"
        static let stampsField = "stampedShops"
        static let operationTimeout: TimeInterval = 10.0
        static let maxStamps = 100
        static let achievementThresholds = [5, 10, 25, 50, 75, 100]
    }
    
    // MARK: - Private State
    private var listener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /**
     * Number of collected stamps
     */
    var collectedStamps: Int {
        return stampedShops.count
    }
    
    /**
     * Completion percentage (0.0 to 1.0)
     */
    var completionPercentage: Double {
        let totalShops = DataService.loadCoffeeShops().count
        guard totalShops > 0 else { return 0.0 }
        return Double(collectedStamps) / Double(totalShops)
    }
    
    /**
     * Completion percentage as integer (0 to 100)
     */
    var completionPercentageInt: Int {
        return Int(completionPercentage * 100)
    }
    
    /**
     * Current achievement status based on stamp count
     */
    var achievementStatus: AchievementLevel {
        switch collectedStamps {
        case 100...: return .legend
        case 75..<100: return .master
        case 50..<75: return .enthusiast
        case 25..<50: return .explorer
        case 10..<25: return .adventurer
        case 5..<10: return .beginner
        default: return .newbie
        }
    }
    
    /**
     * Next achievement threshold
     */
    var nextAchievementThreshold: Int? {
        return Configuration.achievementThresholds.first { $0 > collectedStamps }
    }
    
    /**
     * Progress to next achievement (0.0 to 1.0)
     */
    var progressToNextAchievement: Double {
        guard let nextThreshold = nextAchievementThreshold else { return 1.0 }
        let previousThreshold = Configuration.achievementThresholds.last { $0 <= collectedStamps } ?? 0
        let progress = Double(collectedStamps - previousThreshold) / Double(nextThreshold - previousThreshold)
        return max(0.0, min(1.0, progress))
    }
    
    // MARK: - Initialization
    
    init(firestore: Firestore = Firestore.firestore(), userId: String?) {
        self.firestore = firestore
        self.userId = userId
        
        if let userId = userId {
            setupRealTimeListener(for: userId)
        }
    }
    
    deinit {
        listener?.remove()
        cancellables.removeAll()
    }
    
    // MARK: - Public Interface
    
    /**
     * Add a stamp with optimistic update
     */
    func addStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            print("StampsService: No user ID available ❌")
            completion(false)
            return
        }
        
        // Check if already stamped
        guard !stampedShops.contains(shopId) else {
            print("StampsService: Shop already stamped ⚠️")
            completion(true)
            return
        }
        
        // Check stamps limit
        guard stampedShops.count < Configuration.maxStamps else {
            print("StampsService: Stamps limit reached ❌")
            completion(false)
            return
        }
        
        // Check for achievement unlock
        let previousLevel = achievementStatus
        
        // Optimistic UI update
        stampedShops.insert(shopId)
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.stampsField: FieldValue.arrayUnion([shopId])
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                DispatchQueue.main.async {
                    self?.stampedShops.remove(shopId)
                }
                print("StampsService: Add stamp failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                // Check for achievement unlock
                if let self = self, self.achievementStatus.rawValue > previousLevel.rawValue {
                    self.handleAchievementUnlock(newLevel: self.achievementStatus)
                }
                print("StampsService: Add stamp successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Remove a stamp with optimistic update
     */
    func removeStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            print("StampsService: No user ID available ❌")
            completion(false)
            return
        }
        
        // Check if stamp exists
        guard stampedShops.contains(shopId) else {
            print("StampsService: Shop not stamped ⚠️")
            completion(true)
            return
        }
        
        // Optimistic UI update
        stampedShops.remove(shopId)
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.stampsField: FieldValue.arrayRemove([shopId])
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                DispatchQueue.main.async {
                    self?.stampedShops.insert(shopId)
                }
                print("StampsService: Remove stamp failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                print("StampsService: Remove stamp successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Toggle stamp status for a shop
     */
    func toggleStamp(shopId: String, completion: @escaping (Bool) -> Void) {
        if stampedShops.contains(shopId) {
            removeStamp(shopId: shopId, completion: completion)
        } else {
            addStamp(shopId: shopId, completion: completion)
        }
    }
    
    /**
     * Check if a shop is stamped
     */
    func isStamped(shopId: String) -> Bool {
        return stampedShops.contains(shopId)
    }
    
    /**
     * Get all stamped shop IDs
     */
    func getAllStamps() -> Set<String> {
        return stampedShops
    }
    
    /**
     * Clear all stamps
     */
    func clearAllStamps(completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        // Optimistic UI update
        let previousStamps = stampedShops
        stampedShops.removeAll()
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.stampsField: []
        ]) { [weak self] error in
            if let error = error {
                // Revert optimistic update on failure
                DispatchQueue.main.async {
                    self?.stampedShops = previousStamps
                }
                print("StampsService: Clear stamps failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                print("StampsService: Clear stamps successful ✅")
                completion(true)
            }
        }
    }
    
    /**
     * Fetch stamps from server (manual refresh)
     */
    func fetchStamps(completion: @escaping (Bool) -> Void = { _ in }) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.getDocument { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("StampsService: Fetch stamps failed ❌ - \(error.localizedDescription)")
                    completion(false)
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data(),
                      let stamps = data[Configuration.stampsField] as? [String] else {
                    print("StampsService: No stamps data found")
                    self?.stampedShops = []
                    completion(true)
                    return
                }
                
                self?.stampedShops = Set(stamps)
                print("StampsService: Fetch stamps successful ✅ - \(stamps.count) stamps")
                completion(true)
            }
        }
    }
    
    /**
     * Update user ID and setup listener
     */
    func updateUserId(_ newUserId: String?) {
        // Remove existing listener
        listener?.remove()
        listener = nil
        
        if let newUserId = newUserId {
            setupRealTimeListener(for: newUserId)
        } else {
            stampedShops.removeAll()
        }
    }
    
    // MARK: - Private Methods
    
    private func setupRealTimeListener(for userId: String) {
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        
        listener = userDocument.addSnapshotListener { [weak self] document, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("StampsService: Real-time listener error ❌ - \(error.localizedDescription)")
                    return
                }
                
                guard let document = document,
                      document.exists,
                      let data = document.data() else {
                    print("StampsService: User document not found")
                    self?.stampedShops = []
                    return
                }
                
                if let stamps = data[Configuration.stampsField] as? [String] {
                    let newStamps = Set(stamps)
                    if self?.stampedShops != newStamps {
                        self?.stampedShops = newStamps
                        print("StampsService: Real-time update ✅ - \(stamps.count) stamps")
                    }
                }
            }
        }
    }
    
    private func handleAchievementUnlock(newLevel: AchievementLevel) {
        print("🏆 Achievement Unlocked: \(newLevel.displayName)!")
        // In a real app, this would trigger achievement notifications/animations
    }
}

// MARK: - Achievement System

/**
 * Achievement levels based on stamp collection
 */
enum AchievementLevel: Int, CaseIterable {
    case newbie = 0
    case beginner = 5
    case adventurer = 10
    case explorer = 25
    case enthusiast = 50
    case master = 75
    case legend = 100
    
    var displayName: String {
        switch self {
        case .newbie: return "Newbie Brewer"
        case .beginner: return "Coffee Beginner"
        case .adventurer: return "Coffee Adventurer"
        case .explorer: return "Coffee Explorer"
        case .enthusiast: return "Coffee Enthusiast"
        case .master: return "Coffee Master"
        case .legend: return "Coffee Legend"
        }
    }
    
    var emoji: String {
        switch self {
        case .newbie: return "☕"
        case .beginner: return "🌱"
        case .adventurer: return "🗺️"
        case .explorer: return "🔍"
        case .enthusiast: return "❤️"
        case .master: return "👑"
        case .legend: return "🏆"
        }
    }
    
    var description: String {
        switch self {
        case .newbie: return "Just getting started on your coffee journey"
        case .beginner: return "Beginning to explore local coffee culture"
        case .adventurer: return "Adventuring through different coffee experiences"
        case .explorer: return "Exploring the diverse world of coffee"
        case .enthusiast: return "A true coffee enthusiast with passion"
        case .master: return "Master of local coffee scene"
        case .legend: return "Legendary status in coffee exploration"
        }
    }
}

// MARK: - Async/Await Interface

extension StampsService {
    
    /**
     * Add stamp using async/await
     */
    func addStamp(shopId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            addStamp(shopId: shopId) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StampsError.addFailed(shopId))
                }
            }
        }
    }
    
    /**
     * Remove stamp using async/await
     */
    func removeStamp(shopId: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            removeStamp(shopId: shopId) { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StampsError.removeFailed(shopId))
                }
            }
        }
    }
    
    /**
     * Fetch stamps using async/await
     */
    func fetchStamps() async throws {
        return try await withCheckedThrowingContinuation { continuation in
            fetchStamps { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: StampsError.fetchFailed)
                }
            }
        }
    }
}

// MARK: - StampsError

/**
 * Structured error types for stamps operations
 */
enum StampsError: LocalizedError {
    case addFailed(String)
    case removeFailed(String)
    case fetchFailed
    case limitReached(Int)
    case userNotAuthenticated
    case networkUnavailable
    
    var errorDescription: String? {
        switch self {
        case .addFailed(let shopId):
            return "Failed to add stamp for shop \(shopId)"
        case .removeFailed(let shopId):
            return "Failed to remove stamp for shop \(shopId)"
        case .fetchFailed:
            return "Failed to fetch stamps"
        case .limitReached(let limit):
            return "Stamps limit reached (\(limit) maximum)"
        case .userNotAuthenticated:
            return "User not authenticated"
        case .networkUnavailable:
            return "Network is unavailable"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .addFailed, .removeFailed, .fetchFailed:
            return "Please check your network connection and try again."
        case .limitReached:
            return "Congratulations on reaching the maximum stamps!"
        case .userNotAuthenticated:
            return "Please sign in to manage stamps."
        case .networkUnavailable:
            return "Please check your internet connection."
        }
    }
}

// MARK: - Analytics Extensions

extension StampsService {
    
    /**
     * Get stamps analytics data
     */
    var analyticsData: [String: Any] {
        return [
            "total_stamps": collectedStamps,
            "completion_percentage": completionPercentageInt,
            "achievement_level": achievementStatus.displayName,
            "progress_to_next": progressToNextAchievement,
            "last_updated": Date().timeIntervalSince1970
        ]
    }
    
    /**
     * Track stamps operations for analytics
     */
    func trackStampsOperation(_ operation: String, shopId: String, success: Bool) {
        // In a real app, this would send analytics data
        let status = success ? "✅" : "❌"
        print("📊 StampsService: \(operation) for shop \(shopId) \(status)")
    }
}

// MARK: - Utility Extensions

extension StampsService {
    
    /**
     * Export stamps as array for sharing/backup
     */
    func exportStamps() -> [String] {
        return Array(stampedShops).sorted()
    }
    
    /**
     * Import stamps from array
     */
    func importStamps(_ stamps: [String], completion: @escaping (Bool) -> Void) {
        guard let userId = userId else {
            completion(false)
            return
        }
        
        // Validate stamps count
        let validStamps = Array(stamps.prefix(Configuration.maxStamps))
        
        let userDocument = firestore.collection(Configuration.collectionName).document(userId)
        userDocument.updateData([
            Configuration.stampsField: validStamps
        ]) { [weak self] error in
            if let error = error {
                print("StampsService: Import stamps failed ❌ - \(error.localizedDescription)")
                completion(false)
            } else {
                DispatchQueue.main.async {
                    self?.stampedShops = Set(validStamps)
                }
                print("StampsService: Import stamps successful ✅")
                completion(true)
            }
        }
    }
}
