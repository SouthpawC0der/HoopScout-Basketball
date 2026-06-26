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
    @StateObject private var newsService = BasketballNewsService()
    @State private var presentedURL: IdentifiableURL?

    private let player = HSHomeMock.playerOfTheWeek

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
                    await newsService.load()
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                await newsService.loadIfNeeded()
            }
            .sheet(item: $presentedURL) { wrapped in
                SafariView(url: wrapped.url)
                    .ignoresSafeArea()
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
            sectionTitle("PLAYER OF THE WEEK", subtitle: "Top hooper this week")
                .padding(.horizontal, 20)

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
                }

                Text(player.recap)
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray700)
                    .fixedSize(horizontal: false, vertical: true)
                    .lineSpacing(2)

                HStack(spacing: 0) {
                    statCell(value: player.runs, label: "RUNS")
                    statDivider
                    statCell(value: player.wins, label: "WINS")
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
            .padding(.horizontal, 16)
        }
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
        VStack(alignment: .leading, spacing: 12) {
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

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                    newsRow(item, isLast: idx == items.count - 1)
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

struct HSHomePlayerOfWeek {
    let uid: String
    let name: String
    let handle: String
    let initials: String
    let weekNumber: Int
    let recap: String
    let runs: String
    let wins: String
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
        wins: "12",
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
}
