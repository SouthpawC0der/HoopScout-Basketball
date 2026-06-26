//
//  PlayerOfWeekDetailView.swift
//  HoopScout
//
//  Dedicated page for the local Player of the Week. Reached by tapping the
//  POTW card on the Home tab. Surfaces the recap, week stats, the city the
//  honor is scoped to, and a button into the full friend profile.
//

import SwiftUI

struct PlayerOfWeekDetailView: View {
    let player: HSHomePlayerOfWeek
    let profile: HSUserProfile?
    let cityLabel: String?

    @State private var goToProfile = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero
                recapCard
                statsCard
                if profile != nil { viewProfileButton }
                Spacer(minLength: 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .background(HSColors.bg.ignoresSafeArea())
        .navigationTitle("Player of the Week")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $goToProfile) {
            if let profile {
                FriendProfileView(user: profile)
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 14) {
            HStack(spacing: 6) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HSColors.court)
                Text("WEEK \(player.weekNumber)")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.3)
                    .foregroundColor(HSColors.court)
                if let cityLabel, !cityLabel.isEmpty {
                    Text("·")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(HSColors.gray300)
                    Text(cityLabel.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.3)
                        .foregroundColor(HSColors.gray500)
                }
            }

            HSAvatar(uid: player.uid,
                     initials: player.initials,
                     size: 96,
                     ring: true)

            VStack(spacing: 4) {
                Text(player.name)
                    .font(.system(size: 26, weight: .heavy))
                    .kerning(-0.6)
                    .foregroundColor(HSColors.gray900)
                Text(player.handle)
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray500)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEEK RECAP")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
            Text(player.recap)
                .font(.system(size: 14))
                .foregroundColor(HSColors.gray700)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statCell(value: player.runs, label: "RUNS")
            divider
            statCell(value: player.rating, label: "RATING")
            divider
            statCell(value: player.courts, label: "COURTS")
        }
        .padding(.vertical, 18)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(1.0)
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    private var divider: some View {
        Rectangle()
            .fill(HSColors.gray200)
            .frame(width: 1, height: 32)
    }

    private var viewProfileButton: some View {
        Button { goToProfile = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: 14, weight: .bold))
                Text("View full profile")
                    .font(.system(size: 15, weight: .bold))
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(HSColors.navy)
            .foregroundColor(.white)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        PlayerOfWeekDetailView(
            player: HSHomeMock.playerOfTheWeek,
            profile: nil,
            cityLabel: "Brooklyn, NY"
        )
    }
    .environmentObject(AuthService())
}
