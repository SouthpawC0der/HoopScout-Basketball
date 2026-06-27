//
//  HomeView.swift
//  HoopScout
//
//  Home tab: Player of the Week, women's hoops headlines, NBA headlines.
//  News rows are sourced live from ESPN's public RSS feeds and open the
//  underlying article in an in-app Safari sheet on tap.
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var location: LocationManager
    @StateObject private var newsService = BasketballNewsService()
    @StateObject private var potwService = PlayerOfWeekService()
    @State private var presentedURL: IdentifiableURL?
    @State private var potwProfileTarget: HSUserProfile?

    /// City/town used to scope the Player of the Week. Prefers what the user
    /// entered on their profile so it stays stable across permission changes,
    /// and falls back to the reverse-geocoded label when the profile is blank.
    private var viewerCity: String? {
        let profileLocation = auth.profile?.location
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let profileLocation, !profileLocation.isEmpty { return profileLocation }
        return location.cityLabel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                HSColors.bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 24) {
                        header
                        playerOfTheWeekSection
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
                    .padding(.bottom, 100)
                }
                .refreshable {
                    async let news: Void = newsService.load()
                    async let potw: Void = potwService.load(city: viewerCity)
                    _ = await (news, potw)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                async let news: Void = newsService.loadIfNeeded()
                async let potw: Void = potwService.loadIfNeeded(city: viewerCity)
                _ = await (news, potw)
            }
            .onChange(of: viewerCity) { _, newValue in
                Task { await potwService.loadIfNeeded(city: newValue) }
            }
            .sheet(item: $presentedURL) { wrapped in
                SafariView(url: wrapped.url)
                    .ignoresSafeArea()
            }
            .navigationDestination(for: HSUserProfile.self) { profile in
                FriendProfileView(user: profile)
            }
            .navigationDestination(item: $potwProfileTarget) { profile in
                FriendProfileView(user: profile)
            }
        }
    }

    // MARK: - Display helpers

    private func displayItems(real: [HSNewsItem],
                              placeholder: [HSNewsItem]) -> [HSNewsItem] {
        real.isEmpty ? placeholder : real
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HOME")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(1.4)
                    .foregroundColor(HSColors.gray500)
                Text(greeting)
                    .font(.system(size: 34, weight: .heavy))
                    .kerning(-1.2)
                    .foregroundColor(HSColors.gray900)
                    .lineSpacing(-4)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var greeting: String {
        if let name = auth.profile?.name.split(separator: " ").first {
            return "Hey \(String(name))"
        }
        return "What's good"
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

    // MARK: - News

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
                featuredCarousel(featured)
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

    private func featuredCarousel(_ items: [HSNewsItem]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    featuredCard(item)
                }
            }
            .padding(.horizontal, 16)
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

    // MARK: - Shared

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
}

// MARK: - Models

struct HSHomePlayerOfWeek: Hashable {
    let uid: String
    let name: String
    let handle: String
    let initials: String
    let weekNumber: Int
    let recap: String
    let runs: String
    let rating: String
    let courts: String
}

struct HSNewsItem: Identifiable {
    let id: String
    let source: String
    let title: String
    let summary: String
    let time: String
    let icon: String
    let tint: Color
    var url: URL? = nil
    var imageURL: URL? = nil
}

// MARK: - Mock content (placeholder until ESPN feed loads)

enum HSHomeMock {
    static let playerOfTheWeek = HSHomePlayerOfWeek(
        uid: "potw-tyrese",
        name: "Tyrese Walker",
        handle: "@tyrese.w",
        initials: "TW",
        weekNumber: 24,
        recap: "Stacked 9 runs across 4 courts, including a 12-game streak at The Cage. Hoopers tagged him in 31 game recaps this week.",
        runs: "9",
        rating: "4.8",
        courts: "4"
    )

    static let localNews: [HSNewsItem] = [
        HSNewsItem(
            id: "wnba-placeholder-1",
            source: "ESPN WNBA",
            title: "Loading the latest WNBA headlines…",
            summary: "Pull to refresh if this doesn't update in a moment.",
            time: "",
            icon: "star.fill",
            tint: HSColors.court
        ),
        HSNewsItem(
            id: "wnba-placeholder-2",
            source: "ESPN WNBA",
            title: "Fetching scores, trades & player news",
            summary: "Powered by ESPN public feeds.",
            time: "",
            icon: "sparkles",
            tint: HSColors.navy
        )
    ]

    static let proNews: [HSNewsItem] = [
        HSNewsItem(
            id: "nba-placeholder-1",
            source: "ESPN NBA",
            title: "Loading the latest NBA headlines…",
            summary: "Pull to refresh if this doesn't update in a moment.",
            time: "",
            icon: "basketball.fill",
            tint: HSColors.navy
        ),
        HSNewsItem(
            id: "nba-placeholder-2",
            source: "ESPN NBA",
            title: "Fetching scores, trades & player news",
            summary: "Powered by ESPN public feeds.",
            time: "",
            icon: "flame.fill",
            tint: HSColors.live
        )
    ]
}

#Preview {
    HomeView()
        .environmentObject(AuthService())
        .environmentObject(LocationManager())
}
