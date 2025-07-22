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
        // For production, get the appID from the first coffee shop's credentials
        let coffeeShops = DataService.loadCoffeeShops()
        if let firstShop = coffeeShops.first {
            SQIPInAppPaymentsSDK.squareApplicationID = firstShop.menu.appID
            print("Square In-App Payments SDK initialized with production appID: \(firstShop.menu.appID)")
        } else {
            // Fallback to sandbox if no shops are loaded
            SQIPInAppPaymentsSDK.squareApplicationID = "sandbox-sq0idb-rQ0tQ8bixxpZyp3kiP4SEA"
            print("Square In-App Payments SDK initialized with fallback sandbox appID")
        }
        
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
