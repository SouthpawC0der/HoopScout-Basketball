//
//  ContentView.swift
//  HoopScout
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var auth: AuthService
    @AppStorage("hs_onboarded") private var onboarded: Bool = false

    /// Profile is briefly nil after sign-in while it loads from Firestore.
    /// We treat that as "still settling" so the gate logic doesn't flicker.
    private var profileLoaded: Bool { auth.profile != nil }
    private var hasAcceptedTOS: Bool { auth.profile?.tosAcceptedAt != nil }

    var body: some View {
        Group {
            if !auth.isSignedIn {
                LoginView()
            } else if !profileLoaded {
                // Brief loading window after sign-in.
                ProgressView()
                    .tint(HSColors.navy)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(HSColors.bg.ignoresSafeArea())
            } else if !hasAcceptedTOS {
                NavigationStack {
                    TermsOfServiceView()
                }
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
