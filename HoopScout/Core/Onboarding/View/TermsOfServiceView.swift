//
//  TermsOfServiceView.swift
//  HoopScout
//
//  Gate shown between sign-in and the Courts tab when the signed-in user
//  hasn't yet accepted the Terms of Service. Acceptance is persisted as
//  users/{uid}.tosAcceptedAt so it survives reinstalls and follows the
//  account across devices.
//

import SwiftUI

struct TermsOfServiceView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var checked = false
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    body(text: """
                        Welcome to HoopScout. By tapping "I accept" below, you agree to the following terms.
                        """)

                    section("1. Who can use HoopScout",
                            "You must be at least 13 years old and able to legally form a binding contract with us in your jurisdiction.")

                    section("2. Your account",
                            "You're responsible for your account credentials and any activity that happens on it. Keep your sign-in method (Apple / Google / email) secure.")

                    section("3. Location & check-ins",
                            "HoopScout uses your location to show nearby courts and to auto-check you in when you opt in. You can turn auto check-in off at any time in Profile → Settings.")

                    section("4. Community conduct",
                            "Don't harass, threaten, dox, or impersonate other hoopers. Don't post anything illegal, hateful, or sexual. We may remove content or accounts that violate these rules.")

                    section("5. Ratings & reviews",
                            "Ratings of courts and other users are visible to everyone in the community. Rate honestly. Don't review-bomb or coordinate fake reviews.")

                    section("6. Content you post",
                            "You keep ownership of what you post. By posting, you grant HoopScout a non-exclusive license to display it in the app and to other users.")

                    section("7. Disclaimers",
                            "HoopScout is provided as-is. Pickup basketball involves physical risk — we don't guarantee the safety of any court, run, or user you meet through the app.")

                    section("8. Changes",
                            "We may update these terms and will surface a new acceptance screen if changes are material. Continued use after non-material changes constitutes acceptance.")

                    section("9. Contact",
                            "Questions? support@hoopscoutapp.com")

                    Text("Last updated: June 19, 2026")
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                        .padding(.top, 10)

                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield")
                            Text("Read the Privacy Policy")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(HSColors.navy)
                        .padding(.top, 8)
                    }
                }
                .padding(20)
                .padding(.bottom, 200)
            }

            footer
        }
        .navigationBarHidden(true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TERMS OF SERVICE")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.4)
                .foregroundColor(HSColors.gray500)
            Text("Before you hoop")
                .font(.system(size: 32, weight: .heavy))
                .kerning(-1.0)
                .foregroundColor(HSColors.gray900)
        }
        .padding(.top, 30)
    }

    private func body(text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(HSColors.gray700)
            .lineSpacing(3)
            .padding(.top, 4)
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 14, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(body)
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray700)
                .lineSpacing(3)
        }
        .padding(.top, 10)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            Button { checked.toggle() } label: {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: checked ? "checkmark.square.fill" : "square")
                        .font(.system(size: 22))
                        .foregroundColor(checked ? HSColors.navy : HSColors.gray300)
                    Text("I'm 13+ and I agree to the Terms of Service and Privacy Policy.")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(HSColors.gray900)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Button { Task { await accept() } } label: {
                HStack {
                    if submitting { ProgressView().tint(.white) }
                    Text(submitting ? "Saving…" : "I accept")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(checked && !submitting ? HSColors.navy : HSColors.gray300)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!checked || submitting)

            Button {
                auth.signOut()
            } label: {
                Text("Decline and sign out")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HSColors.gray500)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Color.white
                .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: -4)
                .mask(Rectangle().padding(.top, -20))
        )
    }

    private func accept() async {
        guard let uid = auth.profile?.id else {
            errorMessage = "Sign in required."
            return
        }
        submitting = true
        defer { submitting = false }
        do {
            try await UserRepository.shared.acceptTOS(uid: uid)
            // Update local profile so ContentView's gate releases immediately.
            if var p = auth.profile {
                p.tosAcceptedAt = Date()
                auth.applyLocalProfileUpdate(p)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack { TermsOfServiceView() }
        .environmentObject(AuthService())
}
