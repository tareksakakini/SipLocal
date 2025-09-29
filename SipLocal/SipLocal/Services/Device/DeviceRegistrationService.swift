import Foundation
import OneSignalFramework
import FirebaseFirestore

/**
 * DeviceRegistrationService - Handles device registration and unregistration operations.
 *
 * ## Responsibilities
 * - **Device Registration**: Registers devices for users in Firestore
 * - **Device Unregistration**: Removes device registrations from Firestore
 * - **OneSignal Integration**: Manages OneSignal device ID operations
 * - **Error Handling**: Provides comprehensive error handling and logging
 *
 * ## Architecture
 * - **Service Layer Pattern**: Encapsulates device registration logic
 * - **Firebase Integration**: Manages Firestore operations
 * - **Error Handling**: Structured error handling with completion callbacks
 * - **Logging**: Comprehensive logging for debugging and monitoring
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class DeviceRegistrationService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    
    // MARK: - Design System
    
    enum Design {
        static let collectionName = "users"
        static let devicesField = "devices"
        
        // Error Messages
        static let oneSignalIdUnavailable = "OneSignal device ID not available"
        static let registrationError = "Error registering device"
        static let unregistrationError = "Error unregistering device"
        
        // Success Messages
        static let registrationSuccess = "Device registered successfully"
        static let unregistrationSuccess = "Device unregistered successfully"
    }
    
    // MARK: - Public Methods
    
    /**
     * Register device for a user
     */
    func registerDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            print("❌ \(Design.oneSignalIdUnavailable)")
            completion(false, Design.oneSignalIdUnavailable)
            return
        }
        
        let device = DeviceManager.getCurrentDeviceInfo(deviceId: oneSignalDeviceId)
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        
        userDocRef.updateData([
            "\(Design.devicesField).\(oneSignalDeviceId)": device.dictionary
        ]) { [weak self] error in
            if let error = error {
                self?.logError(Design.registrationError, error: error)
                completion(false, error.localizedDescription)
            } else {
                self?.logSuccess(Design.registrationSuccess, deviceId: oneSignalDeviceId)
                completion(true, nil)
            }
        }
    }
    
    /**
     * Unregister device for a user
     */
    func unregisterDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            print("❌ \(Design.oneSignalIdUnavailable)")
            completion(false, Design.oneSignalIdUnavailable)
            return
        }
        
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        
        userDocRef.updateData([
            "\(Design.devicesField).\(oneSignalDeviceId)": FieldValue.delete()
        ]) { [weak self] error in
            if let error = error {
                self?.logError(Design.unregistrationError, error: error)
                completion(false, error.localizedDescription)
            } else {
                self?.logSuccess(Design.unregistrationSuccess, deviceId: oneSignalDeviceId)
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
