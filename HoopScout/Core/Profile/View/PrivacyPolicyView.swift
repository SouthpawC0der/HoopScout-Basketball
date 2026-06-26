//
//  PrivacyPolicyView.swift
//  HoopScout
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.6)
                    .foregroundColor(HSColors.gray900)

                Text("Last updated: June 8, 2026")
                    .font(.system(size: 12))
                    .foregroundColor(HSColors.gray500)

                section("What we collect") {
                    "Account info (name, handle, email, optional profile photo), location while the app is open or — if you opt in — in the background for auto check-in, and the courts and ratings you create."
                }

                section("How we use it") {
                    "We use your location to show nearby courts and to check you in automatically. We use your account info to power your profile, follows, and messages. Ratings you submit are visible to other HoopScout users."
                }

                section("Who we share it with") {
                    "We use Firebase (Google) for authentication, Firestore, Storage, and push notifications. We do not sell your data."
                }

                section("Your controls") {
                    "You can turn auto check-in off at any time in Profile → Settings. You can sign out, change your photo, or delete your account by contacting support."
                }

                section("Contact") {
                    "Questions? Reach us at support@hoopscout.app."
                }

                Text("This is a placeholder policy provided for development and review. Replace with your final hosted policy before production.")
                    .font(.system(size: 11))
                    .foregroundColor(HSColors.gray500)
                    .padding(.top, 8)
            }
            .padding(20)
        }
        .background(HSColors.bg.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder body: () -> String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(body())
                .font(.system(size: 14))
                .foregroundColor(HSColors.gray700)
                .lineSpacing(4)
        }
        .padding(.top, 4)
    }
}

#Preview {
    NavigationStack { PrivacyPolicyView() }
}
