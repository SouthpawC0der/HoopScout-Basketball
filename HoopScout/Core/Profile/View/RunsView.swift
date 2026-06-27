//
//  RunsView.swift
//  HoopScout
//

import SwiftUI

struct RunsView: View {
    @EnvironmentObject private var auth: AuthService
    @State private var runs: [HSRunDoc] = []
    @State private var observeTask: Task<Void, Never>?

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if runs.isEmpty {
                    empty
                } else {
                    ForEach(runs) { run in
                        runCard(run)
                    }
                }
            }
            .padding(16)
        }
        .background(HSColors.bg.ignoresSafeArea())
        .navigationTitle("Runs")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: HSUserProfile.self) { profile in
            FriendProfileView(user: profile)
        }
        .task(id: auth.profile?.id) {
            observe()
        }
        .onDisappear { observeTask?.cancel() }
    }

    private func playerProfile(_ player: HSRunDoc.CoPlayer) -> HSUserProfile {
        HSUserProfile(
            id: player.uid,
            name: player.name,
            handle: "",
            location: "",
            bio: "",
            skill: "Casual",
            runs: 0,
            followers: 0,
            following: 0
        )
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: "basketball.fill")
                .font(.system(size: 28))
                .foregroundColor(HSColors.court)
            Text("No runs yet")
                .font(.system(size: 16, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text("Check in at a court and stay 10+ minutes to log a run.")
                .font(.system(size: 12))
                .foregroundColor(HSColors.gray500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func runCard(_ run: HSRunDoc) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(run.courtName)
                        .font(.system(size: 16, weight: .heavy))
                        .kerning(-0.3)
                        .foregroundColor(HSColors.gray900)
                    Text(dateLabel(run.endedAt))
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                ratedBadge(run.rated)
            }

            HStack(spacing: 20) {
                stat("Duration", "\(run.durationMinutes) min")
                divider
                stat("Hoopers", "\(run.coPlayers.count + 1)")
                divider
                stat("Rated", run.rated ? "Yes" : "No")
            }

            if !run.coPlayers.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("PLAYED WITH")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundColor(HSColors.gray500)
                    HStack(spacing: -8) {
                        ForEach(run.coPlayers.prefix(5), id: \.uid) { p in
                            NavigationLink(value: playerProfile(p)) {
                                HSAvatar(uid: p.uid, initials: p.initials, size: 28)
                                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            }
                            .buttonStyle(.plain)
                        }
                        if run.coPlayers.count > 5 {
                            Text("+\(run.coPlayers.count - 5)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(HSColors.gray700)
                                .frame(width: 28, height: 28)
                                .background(HSColors.gray200)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                }
            }
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
    }

    private func ratedBadge(_ rated: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: rated ? "checkmark.seal.fill" : "exclamationmark.bubble")
                .font(.system(size: 10, weight: .bold))
            Text(rated ? "Rated" : "Not rated")
                .font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(rated ? HSColors.live : HSColors.court)
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background((rated ? HSColors.live : HSColors.court).opacity(0.12))
        .clipShape(Capsule())
    }

    private func stat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.6)
                .foregroundColor(HSColors.gray500)
            Text(value)
                .font(.system(size: 15, weight: .heavy))
                .kerning(-0.3)
                .foregroundColor(HSColors.gray900)
        }
    }

    private var divider: some View {
        Rectangle().fill(HSColors.gray200).frame(width: 1, height: 26)
    }

    private func dateLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: date)
    }

    private func observe() {
        observeTask?.cancel()
        guard let uid = auth.profile?.id else { return }
        observeTask = Task { @MainActor in
            for await r in RunRepository.shared.observe(uid: uid) {
                self.runs = r
            }
        }
    }
}

#Preview {
    NavigationStack { RunsView() }
        .environmentObject(AuthService())
}
