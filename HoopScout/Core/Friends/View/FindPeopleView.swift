//
//  FindPeopleView.swift
//  HoopScout
//
//  Discover other hoopers and follow them.
//

import SwiftUI

struct FindPeopleView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var query: String = ""
    @State private var users: [HSUserProfile] = []
    @State private var followingIds: Set<String> = []
    @State private var isLoading: Bool = true
    @State private var loadError: String?
    @State private var observeTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    private var filtered: [HSUserProfile] {
        guard !query.isEmpty else { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.handle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            ProgressView()
                                .tint(HSColors.navy)
                                .padding(40)
                        } else if let err = loadError {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundColor(.red.opacity(0.8))
                                .padding(40)
                        } else if filtered.isEmpty {
                            Text(query.isEmpty ? "No other hoopers yet." : "No results for \"\(query)\".")
                                .font(.system(size: 14))
                                .foregroundColor(HSColors.gray500)
                                .padding(40)
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, u in
                                row(for: u, isLast: idx == filtered.count - 1)
                            }
                        }
                    }
                    .background(filtered.isEmpty ? Color.clear : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(filtered.isEmpty ? Color.clear : HSColors.gray200, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(HSColors.bg)
            }
            .navigationTitle("Find people")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(HSColors.navy)
                }
            }
            .navigationDestination(for: HSUserProfile.self) { profile in
                FriendProfileView(user: profile)
            }
            .task { await loadUsers() }
            .task(id: auth.profile?.id) { observeFollowing() }
            .onDisappear { observeTask?.cancel() }
        }
    }

    private func loadUsers() async {
        isLoading = true
        loadError = nil
        do {
            users = try await UserRepository.shared.fetchAll(excluding: auth.profile?.id)
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func observeFollowing() {
        observeTask?.cancel()
        guard let uid = auth.profile?.id else {
            followingIds = []
            return
        }
        observeTask = Task { @MainActor in
            for await docs in FriendsRepository.shared.observeFollowing(for: uid) {
                self.followingIds = Set(docs.compactMap { $0.id })
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(HSColors.gray500)
            TextField("Search name or handle", text: $query)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12).frame(height: 40)
        .background(HSColors.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.top, 10)
    }

    private func row(for u: HSUserProfile, isLast: Bool) -> some View {
        let following = followingIds.contains(u.id ?? "")
        return VStack(spacing: 0) {
            HStack(spacing: 12) {
                NavigationLink(value: u) {
                    HStack(spacing: 12) {
                        HSAvatar(profile: u, size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(u.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(HSColors.gray900)
                            Text(u.handle.isEmpty ? u.location : u.handle)
                                .font(.system(size: 12))
                                .foregroundColor(HSColors.gray500)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button { toggleFollow(u, currentlyFollowing: following) } label: {
                    Text(following ? "Following" : "Follow")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(following ? HSColors.gray900 : .white)
                        .padding(.horizontal, 14).frame(height: 30)
                        .background(following ? HSColors.gray100 : HSColors.navy)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }

    private func toggleFollow(_ u: HSUserProfile, currentlyFollowing: Bool) {
        guard let me = auth.profile, let targetId = u.id else { return }
        // Optimistic toggle on the local set; the observer will reconcile.
        if currentlyFollowing { followingIds.remove(targetId) }
        else { followingIds.insert(targetId) }
        Task {
            do {
                if currentlyFollowing {
                    try await FriendsRepository.shared.unfollow(targetUid: targetId, asUid: me.id ?? "")
                } else {
                    try await FriendsRepository.shared.follow(target: u, as: me)
                }
            } catch {
                // Revert on failure
                if currentlyFollowing { followingIds.insert(targetId) }
                else { followingIds.remove(targetId) }
            }
        }
    }
}

#Preview {
    FindPeopleView().environmentObject(AuthService())
}
