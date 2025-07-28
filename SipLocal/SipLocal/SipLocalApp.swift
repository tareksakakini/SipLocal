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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        
        // Firebase
        FirebaseApp.configure()
        print("Firebase Configured")
        
        // Square In-App Payments
        SQIPInAppPaymentsSDK.squareApplicationID = "sq0idp-e4abRkjlBijc_l97fVO62Q"
        print("Square In-App Payments SDK initialized with production appID")
        
        // ✅ OneSignal Initialization
        OneSignal.initialize("f626f99f-94ea-4859-bac9-10911153f295", withLaunchOptions: launchOptions)
        
        // ✅ Ask for push permission
        OneSignal.Notifications.requestPermission({ accepted in
            print("User accepted notifications: \(accepted)")
        }, fallbackToSettings: true)

        return true
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
        }
    }
}
