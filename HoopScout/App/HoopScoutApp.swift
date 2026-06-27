//
//  HoopScoutApp.swift
//  HoopScout
//

import SwiftUI

@main
struct HoopScoutApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var auth = AuthService()
    @StateObject private var location = LocationManager()
    @StateObject private var courtSearch = CourtSearchService()
    @StateObject private var courtRepo = CourtRepository.shared
    @StateObject private var checkIn = CheckInService.shared
    @StateObject private var messaging = MessagingService.shared
    @StateObject private var friends = FriendsRepository.shared
    @StateObject private var notifications = NotificationRepository.shared
    @StateObject private var tabRouter = TabRouter()
    @StateObject private var blocks = BlockRepository.shared
    @StateObject private var subscriptions = SubscriptionService.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(location)
                .environmentObject(courtSearch)
                .environmentObject(courtRepo)
                .environmentObject(checkIn)
                .environmentObject(messaging)
                .environmentObject(friends)
                .environmentObject(notifications)
                .environmentObject(tabRouter)
                .environmentObject(blocks)
                .environmentObject(subscriptions)
        }
    }
}
