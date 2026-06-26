//
//  FriendProfileView.swift
//  HoopScout
//
//  View another user's profile. Used when tapping a row in follow lists.
//

import SwiftUI

struct FriendProfileView: View {
    let user: HSUserProfile

    @EnvironmentObject private var auth: AuthService
    @State private var isFollowing: Bool = false
    @State private var followObserveTask: Task<Void, Never>?

    @State private var showReportConfirm = false
    @State private var reportSubmitted = false
    @Environment(\.dismiss) private var dismiss

    private var currentUid: String? { auth.profile?.id }
    private var isMe: Bool { currentUid == user.id }

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    statsRow.offset(y: -40).padding(.bottom, -40)
                    if !isMe { actionRow.padding(.top, 14) }
                    Spacer(minLength: 140)
                }
            }
            .background(HSColors.bg)
            .ignoresSafeArea(edges: .top)

            if !isMe { reportButton }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(user.name).font(.system(size: 16, weight: .bold))
            }
        }
        .task(id: user.id) { observeFollowState() }
        .onDisappear { followObserveTask?.cancel() }
        .confirmationDialog("Report \(user.name)?",
                            isPresented: $showReportConfirm,
                            titleVisibility: .visible) {
            Button("Spam or harassment", role: .destructive) { reportSubmitted = true }
            Button("Inappropriate behavior", role: .destructive) { reportSubmitted = true }
            Button("Fake account", role: .destructive) { reportSubmitted = true }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Report submitted", isPresented: $reportSubmitted) {
            Button("OK") {}
        } message: {
            Text("Thanks — we'll review this account.")
        }
    }

    private func observeFollowState() {
        followObserveTask?.cancel()
        guard let me = currentUid, let target = user.id, me != target else { return }
        followObserveTask = Task { @MainActor in
            for await value in FriendsRepository.shared
                .observeIsFollowing(me: me, target: target) {
                self.isFollowing = value
            }
        }
    }

    private var header: some View {
        ZStack {
            LinearGradient(colors: [HSColors.navy, HSColors.navy2],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                HSAvatar(profile: user, size: 88, online: user.activeCheckIn != nil)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 3))
                Text(user.name)
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(.white)
                HSSkillBadge(level: user.skill, dark: true)
                Text(presenceLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 70).padding(.bottom, 60)
        }
    }

    private var presenceLabel: String {
        if let active = user.activeCheckIn {
            return "Playing at \(active.name)"
        }
        return user.location.isEmpty ? "@\(user.handle.trimmingCharacters(in: CharacterSet(charactersIn: "@")))"
                                     : user.location
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            tile("Runs", "\(user.runs)")
            Rectangle().fill(HSColors.gray100).frame(width: 1, height: 36)
            tile("Followers", "\(user.followersCount ?? user.followers)")
            Rectangle().fill(HSColors.gray100).frame(width: 1, height: 36)
            tile("Following", "\(user.followingCount ?? user.following)")
        }
        .padding(.vertical, 14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 20, weight: .heavy)).kerning(-0.5)
                .foregroundColor(HSColors.gray900)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .bold))
                .kerning(0.4)
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button { toggleFollow() } label: {
                HStack(spacing: 6) {
                    Image(systemName: isFollowing ? "checkmark" : "person.badge.plus")
                        .font(.system(size: 12, weight: .bold))
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(isFollowing ? HSColors.gray100 : HSColors.navy)
                .foregroundColor(isFollowing ? HSColors.navy : .white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {} label: {
                HStack(spacing: 6) {
                    Image(systemName: "message.fill").font(.system(size: 12, weight: .bold))
                    Text("Message").font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(Color.white).foregroundColor(HSColors.navy)
                .overlay(Capsule().stroke(HSColors.gray200, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
    }

    private func toggleFollow() {
        guard let me = auth.profile, let targetId = user.id else { return }
        let wasFollowing = isFollowing
        isFollowing.toggle() // optimistic
        Task {
            do {
                if wasFollowing {
                    try await FriendsRepository.shared.unfollow(targetUid: targetId, asUid: me.id ?? "")
                } else {
                    try await FriendsRepository.shared.follow(target: user, as: me)
                }
            } catch {
                isFollowing = wasFollowing // rollback
            }
        }
    }

    private var reportButton: some View {
        Button { showReportConfirm = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "flag.fill").font(.system(size: 12, weight: .bold))
                Text("Report player").font(.system(size: 14, weight: .bold))
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity).frame(height: 48)
            .background(.thinMaterial)
            .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }
}

#Preview {
    NavigationStack {
        FriendProfileView(user: HSUserProfile(
            id: "preview",
            name: "Jane Doe",
            handle: "@jane",
            location: "Brooklyn, NY",
            bio: "",
            skill: "Competitive",
            runs: 42,
            followers: 183, following: 127
        ))
        .environmentObject(AuthService())
    }
}
