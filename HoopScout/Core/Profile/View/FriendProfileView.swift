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
    @EnvironmentObject private var blocks: BlockRepository
    @State private var isFollowing: Bool = false
    @State private var followObserveTask: Task<Void, Never>?
    @State private var userObserveTask: Task<Void, Never>?
    @State private var liveUser: HSUserProfile?

    @State private var showReport = false
    @State private var reportSubmitted = false
    @State private var showBlockConfirm = false
    @State private var openingMessage = false
    @State private var pendingThread: HSThreadDoc?
    @Environment(\.dismiss) private var dismiss

    private var currentUid: String? { auth.profile?.id }
    private var displayUser: HSUserProfile { liveUser ?? user }
    private var isMe: Bool { currentUid == displayUser.id }
    private var isBlocked: Bool {
        guard let id = displayUser.id else { return false }
        return blocks.isBlocked(id)
    }

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

            if !isMe { moderationBar }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(displayUser.name).font(.system(size: 16, weight: .bold))
            }
        }
        .task(id: user.id) {
            observeFollowState()
            observeTargetUser()
        }
        .onDisappear {
            followObserveTask?.cancel()
            userObserveTask?.cancel()
        }
        .sheet(isPresented: $showReport) {
            if let reporterUid = currentUid, let id = displayUser.id {
                ReportSheet(
                    entity: .user,
                    entityId: id,
                    reportedUid: id,
                    reporterUid: reporterUid,
                    subjectLabel: displayUser.name,
                    onSubmitted: { reportSubmitted = true }
                )
            }
        }
        .alert("Report submitted", isPresented: $reportSubmitted) {
            Button("OK") {}
        } message: {
            Text("Thanks — our team will review this account within 24 hours.")
        }
        .confirmationDialog(isBlocked ? "Unblock \(displayUser.name)?" : "Block \(displayUser.name)?",
                            isPresented: $showBlockConfirm,
                            titleVisibility: .visible) {
            if isBlocked {
                Button("Unblock") { Task { await toggleBlock() } }
            } else {
                Button("Block", role: .destructive) { Task { await toggleBlock() } }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(isBlocked
                ? "You'll see their posts and messages again."
                : "You won't see their posts, comments, or messages. They won't be told you blocked them.")
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

    private func observeTargetUser() {
        userObserveTask?.cancel()
        guard let id = user.id else { return }
        userObserveTask = Task { @MainActor in
            for await fresh in UserRepository.shared.observe(uid: id) {
                if let fresh { self.liveUser = fresh }
            }
        }
    }

    private var header: some View {
        ZStack {
            LinearGradient(colors: [HSColors.navy, HSColors.navy2],
                           startPoint: .top, endPoint: .bottom)
            VStack(spacing: 14) {
                HSAvatar(profile: displayUser, size: 88, online: displayUser.activeCheckIn != nil)
                    .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 3))
                Text(displayUser.name)
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(.white)
                HSSkillBadge(level: displayUser.skill, dark: true)
                Text(presenceLabel)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.top, 70).padding(.bottom, 60)
        }
    }

    private var presenceLabel: String {
        if let active = displayUser.activeCheckIn {
            return "Playing at \(active.name)"
        }
        return displayUser.location.isEmpty
            ? displayUser.handle
            : displayUser.location
    }

    private var statsRow: some View {
        HStack(spacing: 0) {
            tile("Runs", "\(displayUser.runs)")
            Rectangle().fill(HSColors.gray100).frame(width: 1, height: 36)
            tile("Followers", "\(displayUser.followersCount ?? displayUser.followers)")
            Rectangle().fill(HSColors.gray100).frame(width: 1, height: 36)
            tile("Following", "\(displayUser.followingCount ?? displayUser.following)")
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

            Button { Task { await openMessageThread() } } label: {
                HStack(spacing: 6) {
                    if openingMessage {
                        ProgressView().tint(HSColors.navy)
                    } else {
                        Image(systemName: "message.fill").font(.system(size: 12, weight: .bold))
                    }
                    Text("Message").font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity).frame(height: 42)
                .background(Color.white).foregroundColor(HSColors.navy)
                .overlay(Capsule().stroke(HSColors.gray200, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(openingMessage)
        }
        .padding(.horizontal, 16)
        .navigationDestination(item: $pendingThread) { thread in
            MessageThreadView(thread: thread)
        }
    }

    private func openMessageThread() async {
        guard let current = auth.profile,
              let currentId = current.id,
              let otherId = displayUser.id else { return }
        openingMessage = true
        defer { openingMessage = false }
        do {
            let id = try await MessageRepository.shared
                .createOrGetThread(current: current, other: displayUser)
            let thread = HSThreadDoc(
                id: id,
                participants: [currentId, otherId].sorted(),
                participantsInfo: [
                    currentId: .init(name: current.name, initials: current.initials),
                    otherId: .init(name: displayUser.name, initials: displayUser.initials)
                ],
                lastMessage: nil,
                unread: [currentId: 0, otherId: 0],
                updatedAt: Date()
            )
            pendingThread = thread
        } catch {
            #if DEBUG
            print("Open message thread failed:", error)
            #endif
        }
    }

    private func toggleFollow() {
        guard let me = auth.profile, let targetId = displayUser.id else { return }
        let wasFollowing = isFollowing
        isFollowing.toggle() // optimistic
        Task {
            do {
                if wasFollowing {
                    try await FriendsRepository.shared.unfollow(targetUid: targetId, asUid: me.id ?? "")
                } else {
                    try await FriendsRepository.shared.follow(target: displayUser, as: me)
                }
            } catch {
                isFollowing = wasFollowing // rollback
            }
        }
    }

    private var moderationBar: some View {
        HStack(spacing: 8) {
            Button { showReport = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "flag.fill").font(.system(size: 12, weight: .bold))
                    Text("Report").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.red)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(.thinMaterial)
                .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button { showBlockConfirm = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: isBlocked ? "hand.raised.slash.fill" : "hand.raised.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(isBlocked ? "Unblock" : "Block").font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(HSColors.gray900)
                .frame(maxWidth: .infinity).frame(height: 48)
                .background(.thinMaterial)
                .overlay(Capsule().stroke(HSColors.gray300, lineWidth: 1))
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 30)
    }

    private func toggleBlock() async {
        guard let target = displayUser.id else { return }
        do {
            if isBlocked {
                try await BlockRepository.shared.unblock(target)
            } else {
                try await BlockRepository.shared.block(target)
            }
        } catch {
            #if DEBUG
            print("toggleBlock failed:", error.localizedDescription)
            #endif
        }
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
