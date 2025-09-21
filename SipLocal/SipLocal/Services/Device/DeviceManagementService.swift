import Foundation
import FirebaseFirestore

/**
 * DeviceManagementService - Handles device management, retrieval, and cleanup operations.
 *
 * ## Responsibilities
 * - **Device Retrieval**: Fetches user devices from Firestore
 * - **Active Device Management**: Identifies and manages active devices
 * - **Device Cleanup**: Removes inactive devices based on activity thresholds
 * - **Data Processing**: Processes device data and filters based on criteria
 *
 * ## Architecture
 * - **Service Layer Pattern**: Encapsulates device management logic
 * - **Firebase Integration**: Manages Firestore operations
 * - **Error Handling**: Structured error handling with completion callbacks
 * - **Logging**: Comprehensive logging for debugging and monitoring
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class DeviceManagementService {
    
    // MARK: - Properties
    
    private let firestore = Firestore.firestore()
    
    // MARK: - Design System
    
    enum Design {
        static let collectionName = "users"
        static let devicesField = "devices"
        static let lastActiveField = "lastActiveAt"
        
        // Default Values
        static let defaultActiveDays = 30
        static let defaultInactiveDays = 90
        
        // Error Messages
        static let fetchDevicesError = "Error fetching user devices"
        static let fetchActiveDevicesError = "Error fetching active devices"
        static let removeInactiveDevicesError = "Error removing inactive devices"
    }
    
    // MARK: - Public Methods
    
    /**
     * Get all devices for a user
     */
    func getUserDevices(userId: String, completion: @escaping ([DeviceManager.UserDevice]) -> Void) {
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        
        userDocRef.getDocument { [weak self] document, error in
            if let error = error {
                self?.logError(Design.fetchDevicesError, error: error)
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data[Design.devicesField] as? [String: [String: Any]] else {
                completion([])
                return
            }
            
            let devices = devicesData.compactMap { (_, deviceData) in
                DeviceManager.UserDevice(from: deviceData)
            }
            
            completion(devices)
        }
    }
    
    /**
     * Get active device IDs for a user
     */
    func getActiveDeviceIds(userId: String, completion: @escaping ([String]) -> Void) {
        getActiveDeviceIds(userId: userId, activeDays: Design.defaultActiveDays, completion: completion)
    }
    
    /**
     * Get active device IDs for a user with custom active days threshold
     */
    func getActiveDeviceIds(userId: String, activeDays: Int, completion: @escaping ([String]) -> Void) {
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -activeDays, to: Date()) ?? Date()
        
        userDocRef.getDocument { [weak self] document, error in
            if let error = error {
                self?.logError(Design.fetchActiveDevicesError, error: error)
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data[Design.devicesField] as? [String: [String: Any]] else {
                completion([])
                return
            }
            
            let activeDeviceIds = devicesData.compactMap { (deviceId, deviceData) -> String? in
                guard let lastActiveTimestamp = deviceData[Design.lastActiveField] as? Timestamp else {
                    return nil
                }
                
                let lastActiveDate = lastActiveTimestamp.dateValue()
                return lastActiveDate > cutoffDate ? deviceId : nil
            }
            
            completion(activeDeviceIds)
        }
    }
    
    /**
     * Remove inactive devices for a user
     */
    func removeInactiveDevices(userId: String, daysCutoff: Int = Design.defaultInactiveDays, completion: @escaping (Int, String?) -> Void) {
        let userDocRef = firestore.collection(Design.collectionName).document(userId)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysCutoff, to: Date()) ?? Date()
        
        userDocRef.getDocument { [weak self] document, error in
            if let error = error {
                self?.logError(Design.removeInactiveDevicesError, error: error)
                completion(0, error.localizedDescription)
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data[Design.devicesField] as? [String: [String: Any]] else {
                completion(0, nil)
                return
            }
            
            let inactiveDeviceIds = devicesData.compactMap { (deviceId, deviceData) -> String? in
                guard let lastActiveTimestamp = deviceData[Design.lastActiveField] as? Timestamp else {
                    return deviceId // Remove devices without lastActiveAt
                }
                
                let lastActiveDate = lastActiveTimestamp.dateValue()
                return lastActiveDate < cutoffDate ? deviceId : nil
            }
            
            guard !inactiveDeviceIds.isEmpty else {
                completion(0, nil)
                return
            }
            
            let updateData: [String: Any] = inactiveDeviceIds.reduce(into: [:]) { result, deviceId in
                result["\(Design.devicesField).\(deviceId)"] = FieldValue.delete()
            }
            
            userDocRef.updateData(updateData) { [weak self] error in
                if let error = error {
                    self?.logError(Design.removeInactiveDevicesError, error: error)
                    completion(0, error.localizedDescription)
                } else {
                    self?.logSuccess("Removed \(inactiveDeviceIds.count) inactive devices")
                    completion(inactiveDeviceIds.count, nil)
                }
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func logError(_ message: String, error: Error) {
        print("❌ \(message): \(error.localizedDescription)")
    }
    
    private func logSuccess(_ message: String) {
        print("✅ \(message)")
    }
}
