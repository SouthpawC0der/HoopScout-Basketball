//
//  AppDelegate.swift
//  HoopScout
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

#if canImport(FirebaseAppCheck)
import FirebaseAppCheck

/// Provides a debug App Check token while developing in the simulator or
/// on internal builds (so requests aren't rejected before we register the
/// debug token in the Firebase Console), and the production App Attest
/// provider everywhere else. Must be installed BEFORE `FirebaseApp.configure()`.
final class HSAppCheckProviderFactory: NSObject, AppCheckProviderFactory {
    func createProvider(with app: FirebaseApp) -> AppCheckProvider? {
        #if DEBUG
        return AppCheckDebugProvider(app: app)
        #else
        if #available(iOS 14.0, *) {
            return AppAttestProvider(app: app)
        }
        return DeviceCheckProvider(app: app)
        #endif
    }
}
#endif

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        // App Check protects Firebase backends (Firestore, Auth, Storage,
        // Functions) from non-genuine app instances. Must be set before
        // `FirebaseApp.configure()` so the first network request is attested.
        // Requires the `FirebaseAppCheck` SPM product to be added to the
        // target — until then this block compiles out via canImport.
        #if canImport(FirebaseAppCheck)
        AppCheck.setAppCheckProviderFactory(HSAppCheckProviderFactory())
        #endif

        FirebaseApp.configure()

        let center = UNUserNotificationCenter.current()
        center.delegate = MessagingService.shared
        center.setNotificationCategories([
            UNNotificationCategory(identifier: NotificationCategory.rateCourt,
                                   actions: [], intentIdentifiers: [], options: []),
            UNNotificationCategory(identifier: NotificationCategory.rateUser,
                                   actions: [], intentIdentifiers: [], options: [])
        ])
        Messaging.messaging().delegate = MessagingService.shared

        application.registerForRemoteNotifications()
        return true
    }

    // Handle the OAuth redirect from Google Sign-In.
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication,
                     didFailToRegisterForRemoteNotificationsWithError error: Error) {
        #if DEBUG
        print("APNs registration failed:", error.localizedDescription)
        #endif
    }
}
