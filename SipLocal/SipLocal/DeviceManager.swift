import Foundation
import OneSignalFramework
import FirebaseFirestore
import UIKit

class DeviceManager: ObservableObject {
    private let firestore = Firestore.firestore()
    
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
    
    func registerDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            completion(false, "OneSignal device ID not available")
            return
        }
        
        let device = getCurrentDeviceInfo(deviceId: oneSignalDeviceId)
        let userDocRef = firestore.collection("users").document(userId)
        
        userDocRef.updateData([
            "devices.\(oneSignalDeviceId)": device.dictionary
        ]) { error in
            if let error = error {
                print("Error registering device: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("Device registered successfully: \(oneSignalDeviceId)")
                completion(true, nil)
            }
        }
    }
    
    func unregisterDeviceForUser(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            completion(false, "OneSignal device ID not available")
            return
        }
        
        let userDocRef = firestore.collection("users").document(userId)
        
        userDocRef.updateData([
            "devices.\(oneSignalDeviceId)": FieldValue.delete()
        ]) { error in
            if let error = error {
                print("Error unregistering device: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                print("Device unregistered successfully: \(oneSignalDeviceId)")
                completion(true, nil)
            }
        }
    }
    
    func updateDeviceActivity(userId: String, completion: @escaping (Bool, String?) -> Void) {
        guard let oneSignalDeviceId = OneSignal.User.pushSubscription.id else {
            completion(false, "OneSignal device ID not available")
            return
        }
        
        let userDocRef = firestore.collection("users").document(userId)
        
        userDocRef.updateData([
            "devices.\(oneSignalDeviceId).lastActiveAt": Timestamp(date: Date())
        ]) { error in
            if let error = error {
                print("Error updating device activity: \(error.localizedDescription)")
                completion(false, error.localizedDescription)
            } else {
                completion(true, nil)
            }
        }
    }
    
    func getUserDevices(userId: String, completion: @escaping ([UserDevice]) -> Void) {
        let userDocRef = firestore.collection("users").document(userId)
        
        userDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching user devices: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data["devices"] as? [String: [String: Any]] else {
                completion([])
                return
            }
            
            let devices = devicesData.compactMap { (_, deviceData) in
                UserDevice(from: deviceData)
            }
            
            completion(devices)
        }
    }
    
    func getActiveDeviceIds(userId: String, completion: @escaping ([String]) -> Void) {
        let userDocRef = firestore.collection("users").document(userId)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        userDocRef.getDocument { document, error in
            if let error = error {
                print("Error fetching active devices: \(error.localizedDescription)")
                completion([])
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data["devices"] as? [String: [String: Any]] else {
                completion([])
                return
            }
            
            let activeDeviceIds = devicesData.compactMap { (deviceId, deviceData) -> String? in
                guard let lastActiveTimestamp = deviceData["lastActiveAt"] as? Timestamp else {
                    return nil
                }
                
                let lastActiveDate = lastActiveTimestamp.dateValue()
                return lastActiveDate > cutoffDate ? deviceId : nil
            }
            
            completion(activeDeviceIds)
        }
    }
    
    func removeInactiveDevices(userId: String, daysCutoff: Int = 90, completion: @escaping (Int, String?) -> Void) {
        let userDocRef = firestore.collection("users").document(userId)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -daysCutoff, to: Date()) ?? Date()
        
        userDocRef.getDocument { document, error in
            if let error = error {
                completion(0, error.localizedDescription)
                return
            }
            
            guard let data = document?.data(),
                  let devicesData = data["devices"] as? [String: [String: Any]] else {
                completion(0, nil)
                return
            }
            
            let inactiveDeviceIds = devicesData.compactMap { (deviceId, deviceData) -> String? in
                guard let lastActiveTimestamp = deviceData["lastActiveAt"] as? Timestamp else {
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
                result["devices.\(deviceId)"] = FieldValue.delete()
            }
            
            userDocRef.updateData(updateData) { error in
                if let error = error {
                    completion(0, error.localizedDescription)
                } else {
                    completion(inactiveDeviceIds.count, nil)
                }
            }
        }
    }
    
    private func getCurrentDeviceInfo(deviceId: String) -> UserDevice {
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