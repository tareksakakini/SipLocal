//
//  SipLocalApp.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import FirebaseCore
import Firebase
import SquareInAppPaymentsSDK
import OneSignalFramework
import Stripe
import PassKit

// MARK: - App Configuration

/// Centralized app configuration management
/// Reads sensitive configuration from Config.plist to keep API keys out of source code
struct AppConfiguration {
    
    private static let configPlist: NSDictionary = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) else {
            fatalError("❌ Config.plist not found. Please ensure Config.plist exists in the app bundle.")
        }
        return config
    }()
    
    // MARK: - API Keys (from Config.plist)
    
    static let squareApplicationID: String = {
        guard let key = configPlist["SquareApplicationID"] as? String, !key.isEmpty else {
            fatalError("❌ SquareApplicationID not found or empty in Config.plist")
        }
        return key
    }()
    
    static let stripePublishableKey: String = {
        guard let key = configPlist["StripePublishableKey"] as? String, !key.isEmpty else {
            fatalError("❌ StripePublishableKey not found or empty in Config.plist")
        }
        return key
    }()
    
    static let oneSignalAppID: String = {
        guard let key = configPlist["OneSignalAppID"] as? String, !key.isEmpty else {
            fatalError("❌ OneSignalAppID not found or empty in Config.plist")
        }
        return key
    }()
    
    // MARK: - App Settings (from Config.plist)
    
    static let environment: String = {
        return configPlist["Environment"] as? String ?? "Development"
    }()
    
    static let cacheMemoryCapacity: Int = {
        let capacityMB = configPlist["CacheMemoryCapacityMB"] as? Int ?? 50
        return capacityMB * 1024 * 1024 // Convert MB to bytes
    }()
    
    static let cacheDiskCapacity: Int = {
        let capacityMB = configPlist["CacheDiskCapacityMB"] as? Int ?? 200
        return capacityMB * 1024 * 1024 // Convert MB to bytes
    }()
    
    // MARK: - Debug Information
    
    static func printConfiguration() {
        print("🔧 App Configuration Loaded:")
        print("   Environment: \(environment)")
        print("   Square App ID: \(squareApplicationID.prefix(10))...")
        print("   Stripe Key: \(stripePublishableKey.prefix(10))...")
        print("   OneSignal ID: \(oneSignalAppID.prefix(10))...")
        print("   Cache Memory: \(cacheMemoryCapacity / 1024 / 1024)MB")
        print("   Cache Disk: \(cacheDiskCapacity / 1024 / 1024)MB")
    }
}

// MARK: - Service Configuration Manager

/// Handles initialization of third-party services
class ServiceConfigurationManager {
    
    static func configureServices(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        AppConfiguration.printConfiguration()
        configureFirebase()
        configureSquarePayments()
        configureStripe()
        configureURLCache()
        configureOneSignal(launchOptions: launchOptions)
    }
    
    private static func configureFirebase() {
        FirebaseApp.configure()
        print("✅ Firebase configured successfully")
    }
    
    private static func configureSquarePayments() {
        SQIPInAppPaymentsSDK.squareApplicationID = AppConfiguration.squareApplicationID
        print("✅ Square In-App Payments SDK initialized")
    }
    
    private static func configureStripe() {
        StripeAPI.defaultPublishableKey = AppConfiguration.stripePublishableKey
        print("✅ Stripe SDK initialized")
    }
    
    private static func configureURLCache() {
        let cache = URLCache(
            memoryCapacity: AppConfiguration.cacheMemoryCapacity,
            diskCapacity: AppConfiguration.cacheDiskCapacity
        )
        URLCache.shared = cache
        print("✅ URL Cache configured")
    }
    
    private static func configureOneSignal(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        OneSignal.initialize(AppConfiguration.oneSignalAppID, withLaunchOptions: launchOptions)
        
        OneSignal.Notifications.requestPermission({ accepted in
            print("OneSignal notifications permission: \(accepted)")
        }, fallbackToSettings: true)
        
        // Setup device ID with delay to ensure OneSignal is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let deviceId = OneSignal.User.pushSubscription.id {
                print("OneSignal Device ID: \(deviceId)")
            } else {
                print("OneSignal Device ID not yet available")
            }
        }
        
        print("✅ OneSignal configured successfully")
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        ServiceConfigurationManager.configureServices(launchOptions: launchOptions)
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AppDidBecomeActive"),
            object: nil
        )
    }
}

@main
struct SipLocalApp: App {
    // register app delegate for Firebase + OneSignal setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var cartManager = CartManager()
    @StateObject private var orderManager = OrderManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
                .environmentObject(cartManager)
                .environmentObject(orderManager)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AppDidBecomeActive"))) { _ in
                    authManager.updateDeviceActivity()
                }
        }
    }
}
