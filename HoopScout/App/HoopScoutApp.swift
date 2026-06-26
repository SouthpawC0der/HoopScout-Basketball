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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .environmentObject(location)
                .environmentObject(courtSearch)
        }
    }
}
