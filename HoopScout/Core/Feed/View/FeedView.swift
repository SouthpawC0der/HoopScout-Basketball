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
    @EnvironmentObject private var friends: FriendsRepository
    @State private var filter: Filter = .all
    @State private var section: FeedSection = .backboard
    @State private var livePosts: [HSFeedPost] = []
    @State private var legacyPosts: [HSFeedPost] = FeedPostStore.shared.load()
    @State private var liked: Set<String> = []
    @State private var showComposer = false
    @State private var feedObserveTask: Task<Void, Never>?
    @State private var showMenu = false
    @State private var presentedURL: IdentifiableURL?
    @State private var potwProfileTarget: HSUserProfile?
    @State private var showArticleComposer = false
    @State private var articles: [HSArticle] = []
    @State private var articleObserveTask: Task<Void, Never>?

    @StateObject private var newsService = BasketballNewsService()
    @StateObject private var potwService = PlayerOfWeekService()

    @State private var searchQuery: String = ""
    @State private var userResults: [HSUserProfile] = []
    @State private var userSearchTask: Task<Void, Never>?
    @State private var isSearching = false

    enum FeedSection: String, CaseIterable, Identifiable {
        case backboard, news
        var id: String { rawValue }
        var label: String {
            switch self {
            case .backboard: return "Backboard"
            case .news: return "News"
            }
        }
    }

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

    private var viewerCity: String? {
        let profileLocation = auth.profile?.location
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let profileLocation, !profileLocation.isEmpty { return profileLocation }
        return location.cityLabel
    }

    /// Merge Firestore-backed posts with any legacy local-only posts (from
    /// the on-device store), dedupe by id, and sort newest first. The hard-
    /// coded `HSFeedMock.posts` are intentionally *not* included — they
    /// were preview seed data that would have masked real activity from
    /// other hoopers. Empty state copy in `backboardContent` handles the
    /// zero-post case.
    private var posts: [HSFeedPost] {
        var seen = Set<String>()
        var merged: [HSFeedPost] = []
        for source in [livePosts, legacyPosts] {
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
        // The feed is nationwide — hoopers see posts from anywhere in the
        // country. We only enforce 180-day retention, blocks, and the
        // account-privacy gate; we no longer filter by the viewer's city.
        let kept = posts.filter { $0.isWithinRetention }
        let unblocked = kept.filter { !blocks.isBlocked($0.authorId) }
        let visible = unblocked.filter(canView)
        switch filter {
        case .all: return visible
        case .thoughts: return visible.filter { $0.kind == .text }
        case .games: return visible.filter { $0.kind == .game }
        case .courts: return visible.filter { $0.kind == .court }
        }
    }

    /// Hide posts authored by private accounts unless the post is mine or
    /// I follow the author. Posts with no `authorIsPrivate` flag (mocks and
    /// pre-privacy posts) are treated as public.
    private func canView(_ post: HSFeedPost) -> Bool {
        guard post.authorIsPrivate == true else { return true }
        if post.authorId == auth.profile?.id { return true }
        return friends.followingIds.contains(post.authorId)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .trailing) {
                HSColors.bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 12, pinnedViews: []) {
                        if isSearching {
                            userResultsSection
                        } else {
                            header
                            sectionPicker
                            if section == .backboard {
                                backboardContent
                            } else {
                                newsContent
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }

                if showMenu {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.25)) { showMenu = false }
                        }
                        .transition(.opacity)

                    HamburgerMenuView(isOpen: $showMenu)
                        .frame(width: UIScreen.main.bounds.width * 0.82)
                        .frame(maxHeight: .infinity)
                        .background(Color.white)
                        .transition(.move(edge: .trailing))
                        .zIndex(1)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
            .sheet(item: $presentedURL) { wrapped in
                SafariView(url: wrapped.url)
                    .ignoresSafeArea()
            }
            .navigationDestination(item: $potwProfileTarget) { profile in
                FriendProfileView(user: profile)
            }
            .task {
                await observeFeed()
                await observeArticles()
                async let news: Void = newsService.loadIfNeeded()
                async let potw: Void = potwService.loadIfNeeded(city: viewerCity)
                _ = await (news, potw)
            }
            .onChange(of: viewerCity) { _, newValue in
                Task { await potwService.loadIfNeeded(city: newValue) }
            }
            .onDisappear {
                feedObserveTask?.cancel()
                articleObserveTask?.cancel()
            }
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
        .sheet(isPresented: $showArticleComposer) {
            if auth.profile?.hasActiveGymSubscription == true {
                ArticleComposerView { _ in
                    // The Firestore listener picks up the new article.
                }
            } else {
                GymPaywallView()
            }
        }
    }

    private func observeArticles() async {
        articleObserveTask?.cancel()
        articleObserveTask = Task { @MainActor in
            for await snapshot in ArticleRepository.shared.observe() {
                self.articles = snapshot
            }
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
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("THE FEED")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(HSColors.gray500)
                Text("What hoopers are saying")
                    .font(.system(size: 18, weight: .heavy))
                    .kerning(-0.4)
                    .foregroundColor(HSColors.gray900)
            }
            Spacer()
            Button {
                withAnimation(.easeOut(duration: 0.25)) { showMenu = true }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(HSColors.gray900)
                    .frame(width: 40, height: 40)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(HSColors.gray200, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var sectionPicker: some View {
        HStack(spacing: 0) {
            ForEach(FeedSection.allCases) { s in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        section = s
                    }
                } label: {
                    let active = section == s
                    VStack(spacing: 6) {
                        Text(s.label)
                            .font(.system(size: 14, weight: active ? .heavy : .semibold))
                            .foregroundColor(active ? HSColors.gray900 : HSColors.gray500)
                        Rectangle()
                            .fill(active ? HSColors.navy : Color.clear)
                            .frame(height: 2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Backboard

    @ViewBuilder
    private var backboardContent: some View {
        playerOfTheWeekSection
        composerPrompt
        filters
        ForEach(displayed) { post in
            FeedPostCard(
                post: post,
                liked: liked.contains(post.id),
                onToggleLike: { toggleLike(post.id) }
            )
            .padding(.horizontal, 16)
        }
        if displayed.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 36, weight: .light))
                    .foregroundColor(HSColors.gray300)
                Text("The Backboard is quiet")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(HSColors.gray900)
                Text("Be the first hooper to post and start the conversation.")
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray500)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
    }

    // MARK: - News

    @ViewBuilder
    private var newsContent: some View {
        if auth.profile?.isGym == true {
            gymPostArticleCTA
        }
        if !articles.isEmpty {
            localArticlesSection
        }
        newsSection(
            title: "WOMEN'S HOOPS",
            subtitle: "WNBA around the league",
            items: displayItems(real: newsService.womensNews,
                                placeholder: HSHomeMock.localNews),
            isLoading: newsService.isLoading && newsService.womensNews.isEmpty
        )
        newsSection(
            title: "PRO NEWS",
            subtitle: "NBA headlines",
            items: displayItems(real: newsService.proNews,
                                placeholder: HSHomeMock.proNews),
            isLoading: newsService.isLoading && newsService.proNews.isEmpty
        )
    }

    private var gymPostArticleCTA: some View {
        Button {
            showArticleComposer = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(HSColors.navy)
                    .clipShape(Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Post a local article")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HSColors.gray900)
                    Text("Share what's happening at your gym")
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(HSColors.gray300)
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
    }

    private var localArticlesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("LOCAL", subtitle: "From gyms in your area")
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(articles.enumerated()), id: \.element.id) { idx, article in
                    articleRow(article, isLast: idx == articles.count - 1)
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

    private func articleRow(_ article: HSArticle, isLast: Bool) -> some View {
        Button {
            if let url = article.url {
                presentedURL = IdentifiableURL(url: url)
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(HSColors.navy.opacity(0.12))
                        Image(systemName: "building.2.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(HSColors.navy)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(article.authorName.uppercased())
                                .font(.system(size: 10, weight: .bold))
                                .kerning(0.8)
                                .foregroundColor(HSColors.navy)
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(HSColors.gray300)
                            Text(relativeTime(article.createdAt))
                                .font(.system(size: 10))
                                .foregroundColor(HSColors.gray500)
                        }
                        Text(article.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !article.body.isEmpty {
                            Text(article.body)
                                .font(.system(size: 12))
                                .foregroundColor(HSColors.gray500)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)

                    if article.url != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(HSColors.gray300)
                            .padding(.top, 6)
                    }
                }
                .padding(12)
                .contentShape(Rectangle())

                if !isLast {
                    Divider().background(HSColors.gray100).padding(.leading, 80)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(article.url == nil)
    }

    private func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }

    private func displayItems(real: [HSNewsItem],
                              placeholder: [HSNewsItem]) -> [HSNewsItem] {
        real.isEmpty ? placeholder : real
    }

    // MARK: - Player of the Week

    private var playerOfTheWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("PLAYER OF THE WEEK", subtitle: potwSubtitle)
                .padding(.horizontal, 20)

            Group {
                if viewerCity == nil {
                    potwLocationPrompt
                } else if let player = potwService.player, let profile = potwService.profile {
                    Button {
                        potwProfileTarget = profile
                    } label: {
                        playerOfTheWeekCard(player)
                            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)
                } else if potwService.isLoading {
                    potwLoadingCard
                } else {
                    potwEmptyCard
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var potwSubtitle: String {
        if let city = potwService.cityLabel, !city.isEmpty {
            return "Top hooper in \(city)"
        }
        return "Top hooper near you"
    }

    private var potwLocationPrompt: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Add your city")
                .font(.system(size: 15, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text("Set your location on your profile so we can crown your area's Player of the Week.")
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray500)
                .fixedSize(horizontal: false, vertical: true)
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

    private func playerOfTheWeekCard(_ player: HSHomePlayerOfWeek) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                HSAvatar(uid: player.uid,
                         initials: player.initials,
                         size: 64,
                         ring: true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "trophy.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(HSColors.court)
                        Text("WEEK \(player.weekNumber)")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1.2)
                            .foregroundColor(HSColors.court)
                    }
                    Text(player.name)
                        .font(.system(size: 20, weight: .heavy))
                        .kerning(-0.4)
                        .foregroundColor(HSColors.gray900)
                    Text(player.handle)
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HSColors.gray300)
            }

            Text(player.recap)
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray700)
                .fixedSize(horizontal: false, vertical: true)
                .lineSpacing(2)
                .multilineTextAlignment(.leading)

            HStack(spacing: 0) {
                statCell(value: player.runs, label: "RUNS")
                statDivider
                statCell(value: player.rating, label: "RATING")
                statDivider
                statCell(value: player.courts, label: "COURTS")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var potwLoadingCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(HSColors.gray100)
                .frame(width: 64, height: 64)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(HSColors.gray100)
                    .frame(width: 140, height: 14)
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(HSColors.gray100)
                    .frame(width: 90, height: 12)
            }
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
                .tint(HSColors.gray500)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var potwEmptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "trophy")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.gray300)
                Text("No winner yet")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(HSColors.gray900)
            }
            Text("Hoopers in \(potwService.cityLabel ?? "your area") are still logging runs. Check back at the end of the week to see who takes the crown.")
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray500)
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

    private func statCell(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 18, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(1.0)
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(HSColors.gray200)
            .frame(width: 1, height: 28)
    }

    // MARK: - News list helpers

    private func newsSection(title: String,
                             subtitle: String,
                             items: [HSNewsItem],
                             isLoading: Bool) -> some View {
        let featured = Array(items.prefix { $0.imageURL != nil }.prefix(3))
        let featuredIDs = Set(featured.map(\.id))
        let remaining = items.filter { !featuredIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle(title, subtitle: subtitle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(HSColors.gray500)
                }
            }
            .padding(.horizontal, 20)

            if !featured.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(featured) { item in
                            featuredCard(item)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            if !remaining.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(remaining.enumerated()), id: \.element.id) { idx, item in
                        newsRow(item, isLast: idx == remaining.count - 1)
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

    private func featuredCard(_ item: HSNewsItem) -> some View {
        Button {
            if let url = item.url {
                presentedURL = IdentifiableURL(url: url)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                ZStack {
                    Rectangle()
                        .fill(item.tint.opacity(0.12))
                    if let url = item.imageURL {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .scaledToFill()
                            case .failure:
                                Image(systemName: item.icon)
                                    .font(.system(size: 32, weight: .semibold))
                                    .foregroundColor(item.tint)
                            case .empty:
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(item.tint)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    }
                }
                .frame(width: 260, height: 150)
                .clipped()

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(item.source)
                            .font(.system(size: 10, weight: .bold))
                            .kerning(0.8)
                            .foregroundColor(HSColors.navy)
                        if !item.time.isEmpty {
                            Text("·")
                                .font(.system(size: 10))
                                .foregroundColor(HSColors.gray300)
                            Text(item.time)
                                .font(.system(size: 10))
                                .foregroundColor(HSColors.gray500)
                        }
                    }
                    Text(item.title)
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundColor(HSColors.gray900)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(12)
                .frame(width: 260, alignment: .leading)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(item.url == nil)
    }

    private func newsRow(_ item: HSNewsItem, isLast: Bool) -> some View {
        Button {
            if let url = item.url {
                presentedURL = IdentifiableURL(url: url)
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(item.tint.opacity(0.15))
                        Image(systemName: item.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(item.tint)
                    }
                    .frame(width: 56, height: 56)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(item.source)
                                .font(.system(size: 10, weight: .bold))
                                .kerning(0.8)
                                .foregroundColor(HSColors.navy)
                            if !item.time.isEmpty {
                                Text("·")
                                    .font(.system(size: 10))
                                    .foregroundColor(HSColors.gray300)
                                Text(item.time)
                                    .font(.system(size: 10))
                                    .foregroundColor(HSColors.gray500)
                            }
                        }
                        Text(item.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                            .fixedSize(horizontal: false, vertical: true)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        if !item.summary.isEmpty {
                            Text(item.summary)
                                .font(.system(size: 12))
                                .foregroundColor(HSColors.gray500)
                                .fixedSize(horizontal: false, vertical: true)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    Spacer(minLength: 0)

                    if item.url != nil {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(HSColors.gray300)
                            .padding(.top, 6)
                    }
                }
                .padding(12)
                .contentShape(Rectangle())

                if !isLast {
                    Divider().background(HSColors.gray100).padding(.leading, 80)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(item.url == nil)
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
            Text(subtitle)
                .font(.system(size: 18, weight: .heavy))
                .kerning(-0.4)
                .foregroundColor(HSColors.gray900)
        }
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
