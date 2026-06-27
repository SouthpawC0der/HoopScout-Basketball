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

                Text("Last updated: June 19, 2026")
                    .font(.system(size: 12))
                    .foregroundColor(HSColors.gray500)

                section("What we collect",
                        "Account info (name, handle, email, optional profile photo), location while the app is open or — if you opt in — in the background for auto check-in, and the courts, ratings, posts, and messages you create.")

                section("How we use it",
                        "We use your location to show nearby courts and to check you in automatically. We use your account info to power your profile, follows, and messages. Ratings, posts, and comments you submit are visible to other HoopScout users.")

                section("Who we share it with",
                        "We use Firebase (Google) for authentication, Firestore, Cloud Storage, and push notifications. We do not sell your data or share it with advertisers.")

                section("Your controls",
                        "Turn auto check-in off any time in Profile → Settings. Block other users from any profile, post, or message. Sign out, edit your profile, or permanently delete your account in Profile → Preferences → Delete account.")

                section("Account deletion",
                        "Deleting your account removes your profile, posts, ratings, check-ins, and messages from HoopScout. Authentication records and operational logs are retained for up to 30 days for fraud prevention, then deleted.")

                section("Reports & moderation",
                        "Reports of objectionable content or abusive users are reviewed and acted on within 24 hours. Repeated violations result in account removal.")

                section("Contact",
                        "Questions or data requests? Reach us at support@hoopscoutapp.com.")
            }
            .padding(20)
        }
        .background(HSColors.bg.ignoresSafeArea())
        .navigationTitle("Privacy")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(body)
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
