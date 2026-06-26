//
//  RateCourtView.swift
//  HoopScout
//

import SwiftUI

struct RateCourtView: View {
    let courtId: String
    let courtName: String

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var stars: Int = 0
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 20) {
            Capsule().fill(HSColors.gray300).frame(width: 40, height: 4)
                .padding(.top, 10)

            VStack(spacing: 6) {
                Text("Rate this run")
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(HSColors.gray900)
                Text(courtName)
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray500)
            }

            starPicker
                .padding(.top, 6)

            Text(label(for: stars))
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HSColors.gray700)
                .frame(height: 16)

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12))
                    .foregroundColor(.red.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            Spacer(minLength: 4)

            Button { Task { await submit() } } label: {
                HStack {
                    if submitting { ProgressView().tint(.white) }
                    Text(submitting ? "Submitting…" : "Submit rating")
                        .font(.system(size: 15, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(stars == 0 ? HSColors.gray300 : HSColors.navy)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(stars == 0 || submitting)
            .padding(.horizontal, 20)

            Button("Not now") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HSColors.gray500)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
    }

    private var starPicker: some View {
        HStack(spacing: 10) {
            ForEach(1...5, id: \.self) { i in
                Button {
                    stars = i
                } label: {
                    Image(systemName: i <= stars ? "basketball.fill" : "basketball")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(i <= stars ? HSColors.court : HSColors.gray300)
                        .scaleEffect(i <= stars ? 1.0 : 0.95)
                        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: stars)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(i) ball\(i > 1 ? "s" : "")")
            }
        }
    }

    private func label(for s: Int) -> String {
        switch s {
        case 1: return "Skip it"
        case 2: return "Meh"
        case 3: return "Solid run"
        case 4: return "Great court"
        case 5: return "Top tier"
        default: return "Tap a ball to rate"
        }
    }

    private func submit() async {
        guard let uid = auth.profile?.id else {
            errorMessage = "Sign in required."
            return
        }
        submitting = true
        defer { submitting = false }
        do {
            try await RatingRepository.shared.rateCourt(
                courtId: courtId, raterUid: uid, stars: stars)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    RateCourtView(courtId: "demo", courtName: "West 4th Street")
        .environmentObject(AuthService())
}
