//
//  FeedView.swift
//  HoopScout
//
//  Social feed: hooper thoughts, game recaps, court call-outs.
//

import SwiftUI

struct FeedView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var blocks: BlockRepository
    @State private var filter: Filter = .all
    @State private var livePosts: [HSFeedPost] = []
    @State private var legacyPosts: [HSFeedPost] = FeedPostStore.shared.load()
    @State private var liked: Set<String> = []
    @State private var showComposer = false
    @State private var feedObserveTask: Task<Void, Never>?

    @State private var searchQuery: String = ""
    @State private var userResults: [HSUserProfile] = []
    @State private var userSearchTask: Task<Void, Never>?
    @State private var isSearching = false

    enum Filter: String, CaseIterable, Identifiable {
        case all, thoughts, games, courts
        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .thoughts: return "Thoughts"
            case .games: return "Games"
            case .courts: return "Courts"
            }
        }
    }

    /// Merge Firestore-backed posts with any legacy local-only posts and the
    /// session mock feed, dedupe by id, enforce 180-day retention, and sort
    /// newest first. Posts with no `createdAt` (mock seeds) keep their
    /// authored order at the tail.
    private var posts: [HSFeedPost] {
        var seen = Set<String>()
        var merged: [HSFeedPost] = []
        let sources: [[HSFeedPost]] = [livePosts, legacyPosts, HSFeedMock.posts]
        for source in sources {
            for post in source where seen.insert(post.id).inserted {
                merged.append(post)
            }
        }
        return merged.sorted { lhs, rhs in
            switch (lhs.createdAt, rhs.createdAt) {
            case let (l?, r?): return l > r
            case (_?, nil):    return true
            case (nil, _?):    return false
            case (nil, nil):   return false
            }
        }
    }

    private var displayed: [HSFeedPost] {
        // Enforce 180-day retention before any tab filtering.
        let kept = posts.filter { $0.isWithinRetention }
        let scoped = scopedToLocalArea(kept)
        let unblocked = scoped.filter { !blocks.isBlocked($0.authorId) }
        switch filter {
        case .all: return unblocked
        case .thoughts: return unblocked.filter { $0.kind == .text }
        case .games: return unblocked.filter { $0.kind == .game }
        case .courts: return unblocked.filter { $0.kind == .court }
        }
    }

    /// If the user has a known city, keep posts from that city plus posts
    /// that have no city tag (mocks, legacy local posts). When the user's
    /// city is unknown we don't filter — better to show something than an
    /// empty feed.
    private func scopedToLocalArea(_ posts: [HSFeedPost]) -> [HSFeedPost] {
        guard let myCity = location.cityLabel, !myCity.isEmpty else { return posts }
        return posts.filter { post in
            guard let postCity = post.cityLabel, !postCity.isEmpty else { return true }
            return postCity.caseInsensitiveCompare(myCity) == .orderedSame
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HSColors.bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        if isSearching {
                            userResultsSection
                        } else {
                            header
                            filters
                            composerPrompt
                            ForEach(displayed) { post in
                                FeedPostCard(
                                    post: post,
                                    liked: liked.contains(post.id),
                                    onToggleLike: { toggleLike(post.id) }
                                )
                                .padding(.horizontal, 16)
                            }
                            if displayed.isEmpty {
                                Text("Nothing here yet — be the first to post.")
                                    .font(.system(size: 13))
                                    .foregroundColor(HSColors.gray500)
                                    .padding(.vertical, 36)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            // Hide the bar's *background* (so the custom inline header is the
            // only visible chrome) but keep the bar itself so the searchable
            // drawer below has somewhere to anchor and slide out from.
            .toolbarBackground(.hidden, for: .navigationBar)
            .searchable(
                text: $searchQuery,
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "Search players by name"
            )
            .onChange(of: searchQuery) { _, newValue in
                runUserSearch(newValue)
            }
            .navigationDestination(for: HSUserProfile.self) { profile in
                FriendProfileView(user: profile)
            }
            .task {
                await observeFeed()
            }
            .onDisappear { feedObserveTask?.cancel() }
        }
        .sheet(isPresented: $showComposer) {
            FeedComposerView { post in
                var stamped = post
                stamped.cityLabel = location.cityLabel
                stamped.authorName = auth.profile?.name
                stamped.authorInitials = auth.profile?.initials
                livePosts.insert(stamped, at: 0)
                showComposer = false
                publish(stamped)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }

    private func observeFeed() async {
        feedObserveTask?.cancel()
        feedObserveTask = Task { @MainActor in
            for await snapshot in FeedRepository.shared.observe() {
                self.livePosts = snapshot
            }
        }
    }

    private func publish(_ post: HSFeedPost) {
        guard let profile = auth.profile else { return }
        Task {
            do {
                try await FeedRepository.shared.add(
                    post: post,
                    author: profile,
                    location: location.location,
                    cityLabel: location.cityLabel)
            } catch {
                #if DEBUG
                print("Feed publish failed:", error.localizedDescription)
                #endif
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("THE FEED")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(HSColors.gray500)
                Text("What hoopers\nare saying")
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-1.2)
                    .foregroundColor(HSColors.gray900)
                    .lineSpacing(-4)
            }
            Spacer()
            Button { showComposer = true } label: {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(HSColors.navy)
                    .clipShape(Circle())
                    .shadow(color: HSColors.navy.opacity(0.25), radius: 12, x: 0, y: 6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Filter.allCases) { f in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                            filter = f
                        }
                    } label: {
                        let active = filter == f
                        Text(f.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(active ? .white : HSColors.gray700)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(active ? HSColors.navy : Color.white)
                            .overlay(
                                Capsule().stroke(
                                    active ? Color.clear : HSColors.gray200, lineWidth: 1)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 8)
    }

    private var composerPrompt: some View {
        Button { showComposer = true } label: {
            HStack(spacing: 12) {
                if let profile = auth.profile {
                    HSAvatar(profile: profile, size: 36)
                } else {
                    HSAvatar(uid: "guest", initials: "?", size: 36)
                }
                Text("What's on your mind\(firstName.map { ", \($0)" } ?? "")?")
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray500)
                Spacer()
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HSColors.navy)
                    .frame(width: 30, height: 30)
                    .background(HSColors.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(14)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    private var userResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PLAYERS")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            if userResults.isEmpty && !searchQuery.isEmpty {
                Text("No players match \"\(searchQuery)\".")
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray500)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(userResults.enumerated()), id: \.element.id) { idx, user in
                        NavigationLink(value: user) {
                            playerRow(user, isLast: idx == userResults.count - 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(HSColors.gray200, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
            }
        }
    }

    private func playerRow(_ user: HSUserProfile, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HSAvatar(profile: user, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(user.name)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text(user.handle.isEmpty ? user.skill : user.handle)
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(12)
            .contentShape(Rectangle())
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }

    private var firstName: String? {
        auth.profile?.name.split(separator: " ").first.map(String.init)
    }

    // MARK: - Actions

    private func toggleLike(_ id: String) {
        if liked.contains(id) {
            liked.remove(id)
            applyLikeDelta(-1, to: id)
        } else {
            liked.insert(id)
            applyLikeDelta(+1, to: id)
        }
    }

    private func applyLikeDelta(_ delta: Int, to id: String) {
        if let idx = livePosts.firstIndex(where: { $0.id == id }) {
            livePosts[idx].likes = max(0, livePosts[idx].likes + delta)
        } else if let idx = legacyPosts.firstIndex(where: { $0.id == id }) {
            legacyPosts[idx].likes = max(0, legacyPosts[idx].likes + delta)
        }
        // Mock posts are read-only — no session bump.
    }

    private func runUserSearch(_ query: String) {
        userSearchTask?.cancel()
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty {
            withAnimation(.easeOut(duration: 0.2)) {
                isSearching = false
                userResults = []
            }
            return
        }
        withAnimation(.easeIn(duration: 0.15)) { isSearching = true }
        guard q.count >= 2 else { return }
        userSearchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            guard !Task.isCancelled else { return }
            let matches = (try? await UserRepository.shared.search(
                query: q, excluding: auth.profile?.id)) ?? []
            let blockedIds = blocks.blockedIds
            let filtered = matches.filter { profile in
                guard let id = profile.id else { return true }
                return !blockedIds.contains(id)
            }
            if !Task.isCancelled {
                self.userResults = filtered
            }
        }
    }
}

#Preview {
    FeedView()
        .environmentObject(AuthService())
}
