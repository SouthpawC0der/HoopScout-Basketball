//
//  HamburgerMenuView.swift
//  HoopScout
//
//  Slide-in side drawer that hosts the user's profile entry point and the
//  preferences/links that used to live on the dedicated Profile tab.
//

import SwiftUI

struct HamburgerMenuView: View {
    @EnvironmentObject private var auth: AuthService
    @Binding var isOpen: Bool

    @State private var showProfile = false
    @State private var showSavedHighlights = false
    @State private var showAdPayments = false
    @State private var showAccountPrivacy = false
    @State private var showTeams = false
    @State private var showBlocked = false
    @State private var showInviteHoopers = false
    @State private var showAbout = false
    @State private var showMerch = false

    private static let merchURL = URL(string: "https://hoopscoutapp.com/shop")!

    var body: some View {
        ZStack(alignment: .topLeading) {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    profileHeader
                        .padding(.top, 60)

                    Divider()
                        .background(HSColors.gray200)
                        .padding(.vertical, 12)

                    menuItem(icon: "bookmark.fill", title: "Saved Highlights") {
                        showSavedHighlights = true
                    }
                    menuItem(icon: "dollarsign.circle.fill",
                             title: "Ad Payments",
                             trailing: "Coming Soon",
                             disabled: true) {}
                    menuItem(icon: "lock.fill", title: "Account Privacy") {
                        showAccountPrivacy = true
                    }
                    menuItem(icon: "person.3.fill", title: "Teams") {
                        showTeams = true
                    }
                    menuItem(icon: "nosign", title: "Blocked") {
                        showBlocked = true
                    }
                    menuItem(icon: "paperplane.fill", title: "Invite Hoopers") {
                        showInviteHoopers = true
                    }
                    menuItem(icon: "bag.fill", title: "Buy Merch") {
                        showMerch = true
                    }
                    menuItem(icon: "info.circle.fill", title: "About") {
                        showAbout = true
                    }

                    Spacer(minLength: 60)
                }
                .padding(.horizontal, 20)
            }
        }
        .sheet(isPresented: $showProfile) {
            NavigationStack { ProfileView() }
        }
        .sheet(isPresented: $showSavedHighlights) {
            NavigationStack { SavedHighlightsView() }
        }
        .sheet(isPresented: $showAccountPrivacy) {
            NavigationStack { AccountPrivacyView() }
        }
        .sheet(isPresented: $showTeams) {
            NavigationStack { TeamsView() }
        }
        .sheet(isPresented: $showBlocked) {
            NavigationStack { BlockedView() }
        }
        .sheet(isPresented: $showInviteHoopers) {
            NavigationStack { InviteHoopersView() }
        }
        .sheet(isPresented: $showAbout) {
            NavigationStack { AboutView() }
        }
        .sheet(isPresented: $showMerch) {
            SafariView(url: Self.merchURL)
                .ignoresSafeArea()
        }
    }

    // MARK: - Profile header

    private var profileHeader: some View {
        Button {
            showProfile = true
        } label: {
            HStack(spacing: 14) {
                if let profile = auth.profile {
                    HSAvatar(profile: profile, size: 56)
                } else {
                    HSAvatar(uid: "guest", initials: "?", size: 56)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(auth.profile?.name ?? "Sign in")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundColor(HSColors.gray900)
                        .lineLimit(1)

                    Text(positionLabel)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(HSColors.gray500)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var positionLabel: String {
        let position = auth.profile?.position?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let position, !position.isEmpty {
            return position
        }
        if let skill = auth.profile?.skill, !skill.isEmpty {
            return skill
        }
        return "Add your position"
    }

    // MARK: - Row

    private func menuItem(icon: String,
                          title: String,
                          trailing: String? = nil,
                          disabled: Bool = false,
                          action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(disabled ? HSColors.gray300 : HSColors.navy)
                    .frame(width: 26)

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(disabled ? HSColors.gray500 : HSColors.gray900)

                Spacer()

                if let trailing {
                    Text(trailing)
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.6)
                        .foregroundColor(HSColors.gray500)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(HSColors.gray100)
                        .clipShape(Capsule())
                } else if !disabled {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(HSColors.gray300)
                }
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }
}

#Preview {
    HamburgerMenuView(isOpen: .constant(true))
        .environmentObject(AuthService())
}
