//
//  CourtDetailView.swift
//  HoopScout
//

import SwiftUI

struct CourtDetailView: View {
    let court: HSCourt
    @State private var checkedIn = false
    @Environment(\.dismiss) private var dismiss

    private var playingCount: Int {
        court.playing + (checkedIn ? 1 : 0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    hero
                    titleCard
                    liveCountCard
                    friendsCard
                    if court.hasGame { nextRunCard }
                    Spacer(minLength: 100)
                }
            }
            .ignoresSafeArea(edges: .top)

            stickyPlayButton
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var hero: some View {
        ZStack(alignment: .top) {
            HSCourtImage(variant: court.img, height: 280, cornerRadius: 0)

            HStack {
                circleButton(systemName: "chevron.left") { dismiss() }
                Spacer()
                circleButton(systemName: "square.and.arrow.up") {}
            }
            .padding(.horizontal, 16)
            .padding(.top, 58)

            VStack { Spacer(); pageDots }
                .frame(height: 280)
        }
    }

    private var pageDots: some View {
        HStack(spacing: 6) {
            ForEach(0..<4, id: \.self) { i in
                Capsule()
                    .fill(i == 0 ? Color.white : Color.white.opacity(0.5))
                    .frame(width: i == 0 ? 18 : 6, height: 6)
            }
        }
        .padding(.bottom, 12)
    }

    private func circleButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(HSColors.navy)
                .frame(width: 38, height: 38)
                .background(.thinMaterial)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var titleCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(court.name)
                        .font(.system(size: 22, weight: .heavy))
                        .kerning(-0.7)
                        .foregroundColor(HSColors.gray900)
                    Text(court.address)
                        .font(.system(size: 13))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                HSSkillBadge(level: court.skill)
            }

            Divider().background(HSColors.gray100)

            HStack(spacing: 6) {
                statTile(icon: "star.fill", iconColor: HSColors.navy,
                         label: "Rating", value: String(format: "%.1f", court.rating),
                         sub: "\(court.reviews)")
                statTile(icon: "mappin.circle.fill", iconColor: HSColors.court,
                         label: "Distance", value: "\(court.distance) mi", sub: "from you")
                statTile(icon: "rectangle", iconColor: HSColors.gray700,
                         label: "Court", value: court.type.split(separator: "·").first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? court.type,
                         sub: court.type.split(separator: "·").dropFirst().first.map { String($0).trimmingCharacters(in: .whitespaces) } ?? "")
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
        .offset(y: -24)
        .padding(.bottom, -24)
    }

    private func statTile(icon: String, iconColor: Color, label: String, value: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11)).foregroundColor(iconColor)
                Text(label.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .kerning(0.6)
                    .foregroundColor(HSColors.gray500)
            }
            Text(value)
                .font(.system(size: 17, weight: .heavy))
                .kerning(-0.4)
                .foregroundColor(HSColors.gray900)
            Text(sub)
                .font(.system(size: 11))
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var liveCountCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    HSLivePulse(size: 8, color: HSColors.court)
                    Text("LIVE · UPDATED NOW")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.8)
                        .foregroundColor(.white.opacity(0.7))
                }

                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("\(playingCount)")
                        .font(.system(size: 52, weight: .heavy))
                        .kerning(-2)
                        .foregroundColor(.white)
                    Text("hoopers playing")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(spacing: 6) {
                    HStack {
                        Text("Capacity")
                        Spacer()
                        Text("\(playingCount) / \(court.maxCap)")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.15))
                            Capsule().fill(HSColors.court)
                                .frame(width: geo.size.width * min(1, Double(playingCount) / Double(court.maxCap)))
                        }
                    }
                    .frame(height: 6)
                }

                Button { withAnimation { checkedIn.toggle() } } label: {
                    HStack(spacing: 6) {
                        if checkedIn {
                            Image(systemName: "checkmark").font(.system(size: 12, weight: .bold))
                            Text("You're in. Count: \(playingCount)")
                        } else {
                            Text("I'm playing here — count me")
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 44)
                    .background(checkedIn ? HSColors.live.opacity(0.25) : Color.white)
                    .foregroundColor(checkedIn ? .white : HSColors.navy)
                    .overlay(
                        Capsule().stroke(checkedIn ? HSColors.live.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .font(.system(size: 14, weight: .bold))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .background(
                LinearGradient(colors: [HSColors.navy, HSColors.navyDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .padding(.horizontal, 16)
    }

    private var friendsCard: some View {
        let friends = court.friendsHere.compactMap { HSMockData.friend(id: $0) }
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(friends.isEmpty ? "No friends here" : "Your guys are here")
                    .font(.system(size: 16, weight: .heavy))
                    .kerning(-0.3)
                    .foregroundColor(HSColors.gray900)
                Spacer()
                if !friends.isEmpty {
                    HStack(spacing: 5) {
                        HSLivePulse(size: 6)
                        Text("\(friends.count) playing")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(HSColors.live)
                    }
                }
            }

            if friends.isEmpty {
                Text("\(court.playing) hoopers runnin' right now. First to pull up gets next.")
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray500)
                    .lineSpacing(3)
            } else {
                VStack(spacing: 10) {
                    ForEach(friends) { f in
                        HStack(spacing: 12) {
                            HSAvatar(friend: f, size: 42, online: true)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.name).font(.system(size: 15, weight: .bold))
                                    .foregroundColor(HSColors.gray900)
                                Text("Checked in · \(f.skill)")
                                    .font(.system(size: 12))
                                    .foregroundColor(HSColors.gray500)
                            }
                            Spacer()
                            Button {} label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "message.fill").font(.system(size: 10, weight: .bold))
                                    Text("Message").font(.system(size: 12, weight: .bold))
                                }
                                .foregroundColor(HSColors.navy)
                                .padding(.horizontal, 12).frame(height: 32)
                                .background(HSColors.gray100)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var nextRunCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Next run")
                .font(.system(size: 16, weight: .heavy))
                .kerning(-0.3)
                .foregroundColor(HSColors.gray900)
            HStack(spacing: 12) {
                Image(systemName: "clock.fill")
                    .font(.system(size: 18))
                    .foregroundColor(HSColors.court)
                    .frame(width: 48, height: 48)
                    .background(HSColors.court.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 2) {
                    Text(court.gameInfo ?? "")
                        .font(.system(size: 15, weight: .bold))
                    Text("\(court.skill) · Hosted by Tyrese W.")
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Button {} label: {
                    Text("I'm in")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14).frame(height: 34)
                        .background(HSColors.court)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var stickyPlayButton: some View {
        Button {} label: {
            HStack(spacing: 8) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 16, weight: .bold))
                Text("Play — open in Apple Maps")
                    .font(.system(size: 15, weight: .bold))
                    .kerning(-0.2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(HSColors.navy)
            .clipShape(Capsule())
            .shadow(color: HSColors.navy.opacity(0.4), radius: 30, x: 0, y: 10)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
}

#Preview {
    CourtDetailView(court: HSMockData.courts[0])
}
