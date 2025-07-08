//
//  SipLocalApp.swift
//  SipLocal
//
//  Created by Tarek Sakakini on 7/7/25.
//

import SwiftUI
import FirebaseCore
import Firebase

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        print("Firebase Configured")
        return true
    }
}

@main
struct SipLocalApp: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var authManager = AuthenticationManager()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(authManager)
        }
    }
}
