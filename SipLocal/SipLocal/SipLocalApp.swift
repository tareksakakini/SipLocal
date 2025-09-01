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
import OneSignalFramework // ✅ Import OneSignal
import Stripe
import PassKit

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase
        FirebaseApp.configure()
        print("Firebase Configured")
        
        // Square In-App Payments
        SQIPInAppPaymentsSDK.squareApplicationID = "sq0idp-e4abRkjlBijc_l97fVO62Q"
        print("Square In-App Payments SDK initialized with production appID")
        
        // Stripe Configuration - LIVE KEYS
        StripeAPI.defaultPublishableKey = "pk_live_51RtCBVRsMlbL5TPdurlxI1BMGWdtJ4NCkYHBUS9iHEh3cI0pwKyAdBSMnTlBHzopcF7lDGYAZUWqseG0TKEZ5M6t00lNb0vvdR"
        print("Stripe SDK initialized with LIVE keys")
        
        // Configure larger URLCache to speed up image and API response caching
        let memoryCapacity = 50 * 1024 * 1024 // 50 MB
        let diskCapacity = 200 * 1024 * 1024  // 200 MB
        let cache = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
        URLCache.shared = cache
        
        // ✅ OneSignal Initialization
        OneSignal.initialize("f626f99f-94ea-4859-bac9-10911153f295", withLaunchOptions: launchOptions)
        
        // ✅ Ask for push permission
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: true)
        
        // ✅ Set up OneSignal external user ID when device is ready
        setupOneSignalDeviceId()

        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationCenter.default.post(name: NSNotification.Name("AppDidBecomeActive"), object: nil)
    }
    
    private func setupOneSignalDeviceId() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let deviceId = OneSignal.User.pushSubscription.id {
                print("OneSignal Device ID: \(deviceId)")
            } else {
                print("OneSignal Device ID not yet available")
            }
        }
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
