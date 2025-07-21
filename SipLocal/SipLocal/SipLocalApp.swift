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

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase Configured")
        
        // Initialize Square In-App Payments SDK
        // Note: You'll need to replace this with your actual Square Application ID
        // For now, using a placeholder - this will be configured in the next step
        SQIPInAppPaymentsSDK.squareApplicationID = "sandbox-sq0idb-rQ0tQ8bixxpZyp3kiP4SEA"
        print("Square In-App Payments SDK initialized")
        
        return true
    }
}

@main
struct SipLocalApp: App {
    // register app delegate for Firebase setup
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
