import Foundation
import OneSignalFramework
import FirebaseFirestore
import UIKit

/**
 * DeviceManager - Coordinates device registration, management, and cleanup operations.
 *
 * ## Responsibilities
 * - **Device Registration**: Registers and unregisters devices for users
 * - **Activity Tracking**: Updates device activity timestamps
 * - **Device Management**: Retrieves and manages user devices
 * - **Cleanup Operations**: Removes inactive devices
 *
 * ## Architecture
 * - **Service Extraction Pattern**: Delegates to specialized services
 * - **Coordinator Pattern**: Acts as a coordinator for device-related operations
 * - **Error Handling**: Comprehensive error handling with completion callbacks
 * - **Firebase Integration**: Manages Firestore operations for device data
 *
 * Created by SipLocal Development Team
 * Copyright © 2024 SipLocal. All rights reserved.
 */
class DeviceManager: ObservableObject {
    
    // MARK: - Private Services
    
    private let deviceRegistrationService: DeviceRegistrationService
    private let deviceActivityService: DeviceActivityService
    private let deviceManagementService: DeviceManagementService
    
    // MARK: - Initialization
    
    init() {
        self.deviceRegistrationService = DeviceRegistrationService()
        self.deviceActivityService = DeviceActivityService()
        self.deviceManagementService = DeviceManagementService()
        print("📱 DeviceManager initialized with service extraction pattern")
    }
    
    // MARK: - Public Methods
    
    func registerDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        deviceRegistrationService.registerDeviceForUser(userId: userId, completion: completion)
    }
    
    func unregisterDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        deviceRegistrationService.unregisterDeviceForUser(userId: userId, completion: completion)
    }
    
    func updateDeviceActivity(userId: String, completion: @escaping (Bool, String?) -> Void) {
        deviceActivityService.updateDeviceActivity(userId: userId, completion: completion)
    }
    
    func getUserDevices(userId: String, completion: @escaping ([UserDevice]) -> Void) {
        deviceManagementService.getUserDevices(userId: userId, completion: completion)
    }
    
    func getActiveDeviceIds(userId: String, completion: @escaping ([String]) -> Void) {
        deviceManagementService.getActiveDeviceIds(userId: userId, completion: completion)
    }
    
    func removeInactiveDevices(userId: String, daysCutoff: Int = 90, completion: @escaping (Int, String?) -> Void) {
        deviceManagementService.removeInactiveDevices(userId: userId, daysCutoff: daysCutoff, completion: completion)
    }
}

// MARK: - UserDevice Model

extension DeviceManager {
    
    struct UserDevice {
        let deviceId: String
        let deviceName: String
        let deviceModel: String 
        let osVersion: String
        let registeredAt: Date
        let lastActiveAt: Date
        
        var dictionary: [String: Any] {
            return [
                "deviceId": deviceId,
                "deviceName": deviceName,
                "deviceModel": deviceModel,
                "osVersion": osVersion,
                "registeredAt": Timestamp(date: registeredAt),
                "lastActiveAt": Timestamp(date: lastActiveAt)
            ]
        }
        
        init(deviceId: String, deviceName: String, deviceModel: String, osVersion: String, registeredAt: Date, lastActiveAt: Date) {
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceModel = deviceModel
            self.osVersion = osVersion
            self.registeredAt = registeredAt
            self.lastActiveAt = lastActiveAt
        }
        
        init?(from dictionary: [String: Any]) {
            guard let deviceId = dictionary["deviceId"] as? String,
                  let deviceName = dictionary["deviceName"] as? String,
                  let deviceModel = dictionary["deviceModel"] as? String,
                  let osVersion = dictionary["osVersion"] as? String,
                  let registeredAt = dictionary["registeredAt"] as? Timestamp,
                  let lastActiveAt = dictionary["lastActiveAt"] as? Timestamp else {
                return nil
            }
            
            self.deviceId = deviceId
            self.deviceName = deviceName
            self.deviceModel = deviceModel
            self.osVersion = osVersion
            self.registeredAt = registeredAt.dateValue()
            self.lastActiveAt = lastActiveAt.dateValue()
        }
    }
}

// MARK: - Device Info Helper

extension DeviceManager {
    
    static func getCurrentDeviceInfo(deviceId: String) -> UserDevice {
        let device = UIDevice.current
        let deviceName = device.name
        let deviceModel = device.model
        let osVersion = device.systemVersion
        let now = Date()
        
        return UserDevice(
            deviceId: deviceId,
            deviceName: deviceName,
            deviceModel: deviceModel,
            osVersion: osVersion,
            registeredAt: now,
            lastActiveAt: now
        )
    }
}