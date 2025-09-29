//
//  SipLocalApp.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import Foundation
import SwiftUI
import FirebaseCore
import Firebase
import SquareInAppPaymentsSDK
import OneSignalFramework
import Stripe
import PassKit

// MARK: - App Configuration

/// Centralized app configuration management
/// Reads configuration from Config.plist with overrides via Config.secrets.plist or environment variables
struct AppConfiguration {
    
    private static let configPlist: NSDictionary = {
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) else {
            fatalError("❌ Config.plist not found. Please ensure Config.plist exists in the app bundle.")
        }
        return config
    }()
    
    private static let secretsPlist: NSDictionary? = {
        guard let path = Bundle.main.path(forResource: "Config.secrets", ofType: "plist"),
              let config = NSDictionary(contentsOfFile: path) else {
            return nil
        }
        return config
    }()
    
    private static func configurationValue(for key: String, envKey: String? = nil) -> Any? {
        if let envKey = envKey,
           let envValue = ProcessInfo.processInfo.environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return envValue
        }
        if let secretsPlist, let value = secretsPlist[key] {
            if let stringValue = value as? String {
                let trimmed = stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            } else {
                return value
            }
        }
        return configPlist[key]
    }

    private static func configurationSourceDescription(for key: String, envKey: String? = nil) -> String {
        if let envKey = envKey,
           let envValue = ProcessInfo.processInfo.environment[envKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envValue.isEmpty {
            return "environment variable \(envKey)"
        }
        if let secretsPlist, let value = secretsPlist[key] {
            if let stringValue = value as? String,
               !stringValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Config.secrets.plist"
            } else if !(value is NSNull) {
                return "Config.secrets.plist"
            }
        }
        return "Config.plist"
    }

    private enum FirebaseOptionsSource: Equatable {
        case environmentPath
        case bundleSecrets
        case bundleDefault

        var description: String {
            switch self {
            case .environmentPath:
                return "environment path (FIREBASE_OPTIONS_PATH)"
            case .bundleSecrets:
                return "GoogleService-Info.secrets.plist (bundle)"
            case .bundleDefault:
                return "GoogleService-Info.plist (bundle)"
            }
        }
    }

    private static var cachedFirebaseOptionsSource: FirebaseOptionsSource?

    private static func locateFirebaseOptions() -> (FirebaseOptionsSource, String)? {
        let env = ProcessInfo.processInfo.environment
        if let envPath = env["FIREBASE_OPTIONS_PATH"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !envPath.isEmpty,
           FileManager.default.fileExists(atPath: envPath) {
            return (.environmentPath, envPath)
        }
        if let path = Bundle.main.path(forResource: "GoogleService-Info.secrets", ofType: "plist") {
            return (.bundleSecrets, path)
        }
        if let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") {
            return (.bundleDefault, path)
        }
        return nil
    }

    static func firebaseOptionsSourceDescription() -> String {
        if let cached = cachedFirebaseOptionsSource {
            return cached.description
        }
        guard let (source, _) = locateFirebaseOptions() else {
            return "not found"
        }
        cachedFirebaseOptionsSource = source
        return source.description
    }

    static func makeFirebaseOptions() -> FirebaseOptions {
        if let cached = cachedFirebaseOptionsSource,
           let (source, path) = locateFirebaseOptions(),
           source == cached,
           let options = FirebaseOptions(contentsOfFile: path) {
            return options
        }

        guard let (source, path) = locateFirebaseOptions() else {
            fatalError("❌ Firebase configuration not found. Provide a GoogleService-Info.secrets.plist file or set FIREBASE_OPTIONS_PATH.")
        }

        guard let options = FirebaseOptions(contentsOfFile: path) else {
            fatalError("❌ Failed to load Firebase options from path: \(path)")
        }

        cachedFirebaseOptionsSource = source
        return options
    }

    
    // MARK: - API Keys
    
    static let squareApplicationID: String = {
        guard let key = configurationValue(for: "SquareApplicationID", envKey: "SQUARE_APPLICATION_ID") as? String, !key.isEmpty else {
            fatalError("❌ SquareApplicationID not found. Provide it via Config.plist, Config.secrets.plist, or the SQUARE_APPLICATION_ID environment variable.")
        }
        return key
    }()
    
    static let stripePublishableKey: String = {
        guard let key = configurationValue(for: "StripePublishableKey", envKey: "STRIPE_PUBLISHABLE_KEY") as? String, !key.isEmpty else {
            fatalError("❌ StripePublishableKey not found. Set the STRIPE_PUBLISHABLE_KEY environment variable or supply a Config.secrets.plist file.")
        }
        return key
    }()
    
    static let oneSignalAppID: String = {
        guard let key = configurationValue(for: "OneSignalAppID", envKey: "ONESIGNAL_APP_ID") as? String, !key.isEmpty else {
            fatalError("❌ OneSignalAppID not found. Provide it via Config.plist, Config.secrets.plist, or the ONESIGNAL_APP_ID environment variable.")
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
        print("   Square App ID Source: \(configurationSourceDescription(for: "SquareApplicationID", envKey: "SQUARE_APPLICATION_ID"))")
        print("   Stripe Key Source: \(configurationSourceDescription(for: "StripePublishableKey", envKey: "STRIPE_PUBLISHABLE_KEY"))")
        print("   OneSignal ID Source: \(configurationSourceDescription(for: "OneSignalAppID", envKey: "ONESIGNAL_APP_ID"))")
        print("   Firebase Options Source: \(firebaseOptionsSourceDescription())")
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
        guard FirebaseApp.app() == nil else { return }
        let options = AppConfiguration.makeFirebaseOptions()
        FirebaseApp.configure(options: options)
        print("✅ Firebase configured using \(AppConfiguration.firebaseOptionsSourceDescription())")
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
