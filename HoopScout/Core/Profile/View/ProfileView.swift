//
//  ProfileView.swift
//  HoopScout
//

import SwiftUI

struct ProfileView: View {
    @State private var tab: HSProfileSelection = .stats
    private let user = HSMockData.user

    var body: some View {
        ZStack {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    header
                    statsCard.offset(y: -50).padding(.bottom, -50)
                    actionRow.padding(.top, 14)
                    Group {
                        switch tab {
                        case .stats: statsPanel
                        case .followers: followList(kind: .followers)
                        case .following: followList(kind: .following)
                        }
                    }
                    settings
                    footer
                }
                .padding(.bottom, 100)
            }
        }
    }

    private var header: some View {
        ZStack {
            LinearGradient(colors: [HSColors.navy, HSColors.navy2],
                           startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("PROFILE")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(1.5)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button {} label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        HSAvatar(user: user, size: 80)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
                        Circle().fill(HSColors.live).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 22, weight: .heavy))
                            .kerning(-0.5)
                            .foregroundColor(.white)
                        Text("\(user.handle) · \(user.location)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                        HSSkillBadge(level: user.skill, dark: true)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20).padding(.top, 20)

                Text(user.bio)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .padding(.horizontal, 20).padding(.top, 14)
            }
            .padding(.top, 54).padding(.bottom, 70)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            statTile("Runs", value: "\(user.runs)", selection: .stats)
            divider
            statTile("Followers", value: "\(user.followers)", selection: .followers)
            divider
            statTile("Following", value: "\(user.following)", selection: .following)
        }
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
    }

    private func statTile(_ label: String, value: String, selection: HSProfileSelection) -> some View {
        Button { withAnimation { tab = selection } } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(HSColors.gray900)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.4)
                    .foregroundColor(tab == selection ? HSColors.navy : HSColors.gray500)
                if tab == selection {
                    Capsule().fill(HSColors.navy).frame(width: 20, height: 3)
                } else {
                    Color.clear.frame(width: 20, height: 3)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(HSColors.gray100).frame(width: 1).padding(.vertical, 12)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {} label: {
                Text("Edit profile")
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(HSColors.navy).foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Button {} label: {
                Text("Share profile")
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(Color.white).foregroundColor(HSColors.navy)
                    .font(.system(size: 14, weight: .bold))
                    .overlay(Capsule().stroke(HSColors.gray200, lineWidth: 1))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("This month").padding(.top, 16)

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible())], spacing: 10) {
                metricTile("Runs logged", value: "12", sub: "+3 vs last mo")
                metricTile("Hours hooping", value: "34h", sub: "avg 2.8h/run")
                metricTile("Regular court", value: "The Cage", sub: "7 visits")
                metricTile("Top teammate", value: "Tyrese W.", sub: "5 runs together")
            }
            .padding(.horizontal, 16).padding(.top, 10)

            sectionLabel("Recent runs").padding(.top, 18)

            VStack(spacing: 0) {
                recentRun(name: "West 4th Street", desc: "Today · 2h", v: .hero1, last: false)
                recentRun(name: "Rucker Park", desc: "2 days ago · 3h", v: .hero2, last: false)
                recentRun(name: "Pier 2 Courts", desc: "5 days ago · 1.5h", v: .hero7, last: true)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.2)
            .foregroundColor(HSColors.gray500)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricTile(_ label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.4)
                .foregroundColor(HSColors.gray500)
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .kerning(-0.5)
                .foregroundColor(HSColors.gray900)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(HSColors.gray500)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func recentRun(name: String, desc: String, v: HSCourtImageVariant, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HSCourtImage(variant: v, height: 44, cornerRadius: 10)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 1) {
                    Text(name).font(.system(size: 14, weight: .bold))
                    Text(desc).font(.system(size: 12)).foregroundColor(HSColors.gray500)
                }
                Spacer()
            }
            .padding(12)
            if !last { Divider().background(HSColors.gray100) }
        }
    }

    private enum FollowKind { case followers, following }

    private func followList(kind: FollowKind) -> some View {
        let base = HSMockData.friends
        let extras = HSMockData.friends.prefix(3).map { f in
            HSFriend(id: f.id + "-2",
                     name: f.name + " Jr.",
                     initials: String(f.initials.first ?? Character("J")) + "J",
                     skill: f.skill, avatarColors: f.avatarColors)
        }
        let list = (base + extras).prefix(8)
        return VStack(spacing: 0) {
            ForEach(Array(list.enumerated()), id: \.element.id) { idx, f in
                HStack(spacing: 12) {
                    HSAvatar(friend: f, size: 42)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(f.name).font(.system(size: 14, weight: .bold))
                        Text("\(f.skill) · \((idx * 7 + 12)) runs")
                            .font(.system(size: 12))
                            .foregroundColor(HSColors.gray500)
                    }
                    Spacer()
                    Button {} label: {
                        Text(kind == .following ? "Following" : "Follow back")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(kind == .following ? HSColors.gray900 : .white)
                            .padding(.horizontal, 14).frame(height: 30)
                            .background(kind == .following ? HSColors.gray100 : HSColors.navy)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                if idx < list.count - 1 { Divider().background(HSColors.gray100) }
            }
        }
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 14)
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Settings").padding(.top, 16)
            VStack(spacing: 0) {
                settingsRow(icon: "📍", label: "Location sharing", value: "Always on", last: false)
                settingsRow(icon: "🔔", label: "Notifications", value: "3 active", last: false)
                settingsRow(icon: "🏀", label: "Default skill level", value: user.skill, last: false)
                settingsRow(icon: "🗺️", label: "Map app", value: "Apple Maps", last: false)
                settingsRow(icon: "🔒", label: "Privacy", value: nil, last: false)
                settingsRow(icon: "❓", label: "Help & support", value: nil, last: true)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func settingsRow(icon: String, label: String, value: String?, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .background(HSColors.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HSColors.gray900)
                Spacer()
                if let v = value {
                    Text(v).font(.system(size: 13)).foregroundColor(HSColors.gray500)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            if !last { Divider().background(HSColors.gray100) }
        }
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("HoopScout v1.4.2 · ").foregroundColor(HSColors.gray500)
            Text("Sign out").foregroundColor(HSColors.navy).fontWeight(.semibold)
        }
        .font(.system(size: 12))
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
}
