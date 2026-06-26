//
//  BasketballNewsService.swift
//  HoopScout
//
//  Fetches live basketball headlines from ESPN's public RSS feeds (no API key)
//  and maps them into HSNewsItem values consumed by HomeView.
//

import Foundation
import SwiftUI

@MainActor
final class BasketballNewsService: ObservableObject {
    @Published private(set) var proNews: [HSNewsItem] = []
    @Published private(set) var womensNews: [HSNewsItem] = []
    @Published private(set) var isLoading: Bool = false
    @Published var errorMessage: String?

    private let nbaFeed = URL(string: "https://www.espn.com/espn/rss/nba/news")!
    private let wnbaFeed = URL(string: "https://www.espn.com/espn/rss/wnba/news")!

    private let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    func loadIfNeeded() async {
        if proNews.isEmpty && womensNews.isEmpty {
            await load()
        }
    }

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        async let nbaTask = Self.fetchRSS(from: nbaFeed)
        async let wnbaTask = Self.fetchRSS(from: wnbaFeed)

        let nbaItems = (try? await nbaTask) ?? []
        let wnbaItems = (try? await wnbaTask) ?? []

        proNews = nbaItems.prefix(8).map {
            mapItem($0, source: "ESPN NBA", icon: "basketball.fill", tint: HSColors.navy)
        }
        womensNews = wnbaItems.prefix(6).map {
            mapItem($0, source: "ESPN WNBA", icon: "star.fill", tint: HSColors.court)
        }

        if proNews.isEmpty && womensNews.isEmpty {
            errorMessage = "Couldn't load the latest hoops news."
        }
    }

    private func mapItem(_ item: RSSItem,
                         source: String,
                         icon: String,
                         tint: Color) -> HSNewsItem {
        let time: String
        if let date = item.pubDate {
            time = relativeFormatter.localizedString(for: date, relativeTo: Date())
        } else {
            time = ""
        }
        return HSNewsItem(
            id: item.link.absoluteString,
            source: source,
            title: item.title,
            summary: item.description,
            time: time,
            icon: icon,
            tint: tint,
            url: item.link
        )
    }

    // MARK: - RSS fetch

    private static func fetchRSS(from url: URL) async throws -> [RSSItem] {
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("HoopScout/1.0", forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)
        let parser = RSSParser()
        return parser.parse(data: data)
    }
}

// MARK: - RSS model

struct RSSItem {
    let title: String
    let link: URL
    let description: String
    let pubDate: Date?
}

// MARK: - RSS XML parser

private final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [RSSItem] = []

    private var currentElement = ""
    private var inItem = false
    private var currentTitle = ""
    private var currentLink = ""
    private var currentDescription = ""
    private var currentPubDate = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return f
    }()

    func parse(data: Data) -> [RSSItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(_ parser: XMLParser,
                didStartElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        if elementName == "item" {
            inItem = true
            currentTitle = ""
            currentLink = ""
            currentDescription = ""
            currentPubDate = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard inItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "description": currentDescription += string
        case "pubDate": currentPubDate += string
        default: break
        }
    }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        guard inItem, let text = String(data: CDATABlock, encoding: .utf8) else { return }
        switch currentElement {
        case "title": currentTitle += text
        case "link": currentLink += text
        case "description": currentDescription += text
        case "pubDate": currentPubDate += text
        default: break
        }
    }

    func parser(_ parser: XMLParser,
                didEndElement elementName: String,
                namespaceURI: String?,
                qualifiedName qName: String?) {
        if elementName == "item" {
            inItem = false
            let trimmedLink = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedTitle = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            if let url = URL(string: trimmedLink), !trimmedTitle.isEmpty {
                let desc = Self.stripHTML(currentDescription)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let date = Self.dateFormatter.date(
                    from: currentPubDate.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                items.append(RSSItem(title: trimmedTitle,
                                     link: url,
                                     description: desc,
                                     pubDate: date))
            }
        }
        currentElement = ""
    }

    private static func stripHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
