import Foundation
import OneSignalFramework
import FirebaseFirestore

/**
 * DeviceActivityService - Handles device activity tracking and updates.
 *
 * ## Responsibilities
 * - **Activity Tracking**: Updates device activity timestamps
 * - **OneSignal Integration**: Manages OneSignal device ID operations
 * - **Firebase Operations**: Handles Firestore updates for activity data
 * - **Error Handling**: Provides comprehensive error handling and logging
 *
 * ## Architecture
 * - **Service Layer Pattern**: Encapsulates device activity logic
 * - **Firebase Integration**: Manages Firestore operations
 * - **Error Handling**: Structured error handling with completion callbacks
 * - **Logging**: Comprehensive logging for debugging and monitoring
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class DeviceActivityService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    
    // MARK: - Design System
    
    enum Design {
        static let collectionName = "users"
        static let devicesField = "devices"
        static let lastActiveField = "lastActiveAt"
        
        // Error Messages
        static let oneSignalIdUnavailable = "OneSignal device ID not available"
        static let activityUpdateError = "Error updating device activity"
    }
    
    // MARK: - Public Methods
    
    /**
     * Update device activity timestamp
     */
    func updateDeviceActivity(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            print("❌ \(Design.oneSignalIdUnavailable)")
            completion(false, Design.oneSignalIdUnavailable)
            return
        }
        
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        
        userDocRef.updateData([
            "\(Design.devicesField).\(oneSignalDeviceId).\(Design.lastActiveField)": Timestamp(date: Date())
        ]) { [weak self] error in
            if let error = error {
                self?.logError(Design.activityUpdateError, error: error)
                completion(false, error.localizedDescription)
            } else {
                self?.logSuccess("Device activity updated", deviceId: oneSignalDeviceId)
                completion(true, nil)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func logError(_ message: String, error: Error) {
        print("❌ \(message): \(error.localizedDescription)")
    }
    
    private func logSuccess(_ message: String, deviceId: String) {
        print("✅ \(message): \(deviceId)")
    }
}
