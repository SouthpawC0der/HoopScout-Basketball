//
//  ContentView.swift
//  HoopScout
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("hs_onboarded") private var onboarded: Bool = false

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if !onboarded {
                OnboardingView(onComplete: {
                    onboarded = true
                    Task { await MessagingService.shared.requestAuthorization() }
                })
            } else {
                HoopTabView()
            }
        }
    }
}

#Preview {
    ContentView().environmentObject(AuthService())
}
