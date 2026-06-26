//
//  RateUserView.swift
//  HoopScout
//

import SwiftUI

struct RateUserView: View {
    let ratedUid: String
    let ratedName: String
    let ratedInitials: String
    let courtId: String?

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var ballHandling: Int = 0
    @State private var basketballIQ: Int = 0
    @State private var teamPlay: Int = 0
    @State private var toughness: Int = 0
    @State private var comment: String = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    private var allRated: Bool {
        ballHandling > 0 && basketballIQ > 0 && teamPlay > 0 && toughness > 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Capsule().fill(HSColors.gray300).frame(width: 40, height: 4)
                    .padding(.top, 10)

                VStack(spacing: 10) {
                    HSAvatar(uid: ratedUid, initials: ratedInitials, size: 64)
                    Text("Rate \(ratedName)")
                        .font(.system(size: 20, weight: .heavy))
                        .kerning(-0.4)
                        .foregroundColor(HSColors.gray900)
                    Text("Score each category 1–5 basketballs.")
                        .font(.system(size: 13))
                        .foregroundColor(HSColors.gray500)
                }

                VStack(spacing: 14) {
                    categoryRow(title: "Ball handling skills",
                                subtitle: "Dribble, control, change of direction",
                                rating: $ballHandling)
                    categoryRow(title: "Basketball IQ",
                                subtitle: "Reads the game, makes the right play",
                                rating: $basketballIQ)
                    categoryRow(title: "Team play",
                                subtitle: "Passes, communicates, plays unselfishly",
                                rating: $teamPlay)
                    categoryRow(title: "Toughness",
                                subtitle: "Effort on defense, rebounds, hustle plays",
                                rating: $toughness)
                }
                .padding(.horizontal, 20)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Comment (optional)")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.8)
                        .foregroundColor(HSColors.gray500)
                    TextEditor(text: $comment)
                        .font(.system(size: 14))
                        .frame(minHeight: 84)
                        .padding(.horizontal, 10).padding(.vertical, 8)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(HSColors.gray200, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundColor(.red.opacity(0.85))
                        .padding(.horizontal, 24)
                }

                Button { Task { await submit() } } label: {
                    HStack {
                        if submitting { ProgressView().tint(.white) }
                        Text(submitting ? "Submitting…" : "Submit rating")
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(allRated ? HSColors.navy : HSColors.gray300)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!allRated || submitting)
                .padding(.horizontal, 20)
                .padding(.top, 4)

                Button("Not now") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HSColors.gray500)
                    .padding(.bottom, 24)
            }
        }
        .background(HSColors.bg.ignoresSafeArea())
    }

    private func categoryRow(title: String, subtitle: String,
                             rating: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
            }
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { i in
                    Button {
                        rating.wrappedValue = i
                    } label: {
                        Image(systemName: i <= rating.wrappedValue ? "basketball.fill" : "basketball")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(i <= rating.wrappedValue ? HSColors.court : HSColors.gray300)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(i) ball\(i > 1 ? "s" : "")")
                }
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func submit() async {
        guard let uid = auth.profile?.id else {
            errorMessage = "Sign in required."
            return
        }
        submitting = true
        defer { submitting = false }
        do {
            try await RatingRepository.shared.rateUser(
                ratedUid: ratedUid,
                raterUid: uid,
                raterName: auth.profile?.name,
                ballHandling: ballHandling,
                basketballIQ: basketballIQ,
                teamPlay: teamPlay,
                toughness: toughness,
                comment: comment.trimmingCharacters(in: .whitespacesAndNewlines),
                courtId: courtId)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RateUserView(ratedUid: "demo", ratedName: "Tyrese W.", ratedInitials: "TW", courtId: nil)
        .environmentObject(AuthService())
}
