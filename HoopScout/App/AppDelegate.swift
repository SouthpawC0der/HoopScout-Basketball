//
//  AppDelegate.swift
//  HoopScout
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import GoogleSignIn
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
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
