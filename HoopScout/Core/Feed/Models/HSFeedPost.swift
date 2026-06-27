//
//  HSFeedPost.swift
//  HoopScout
//

import SwiftUI

struct HSFeedPost: Identifiable, Hashable {
    let id: String
    let authorId: String
    let time: String
    let kind: Kind
    let body: String
    let mood: Mood
    var likes: Int
    var comments: Int
    var attachment: Attachment?
    /// Absolute timestamp used for the 180-day retention filter. Optional so
    /// existing mock posts (which only carry the human-readable `time`)
    /// remain valid.
    var createdAt: Date?
    /// Display name + initials captured from the author's profile at post
    /// time. Populated for Firestore-backed posts so the feed can show the
    /// poster's name to users who aren't in the mock friends graph.
    var authorName: String?
    var authorInitials: String?
    /// Reverse-geocoded "City, ST" stored alongside the post so the feed
    /// can scope to a local area.
    var cityLabel: String?
    /// Author's `isPrivate` flag captured at post time. Used to gate
    /// visibility to followers + the author. Nil/false means public.
    var authorIsPrivate: Bool?
    /// True for sponsored posts authored by gym/business accounts. Renders
    /// an "AD" badge in the post card. Only gym accounts can set this.
    var isAd: Bool?

    init(id: String,
         authorId: String,
         time: String,
         kind: Kind,
         body: String,
         mood: Mood,
         likes: Int,
         comments: Int,
         attachment: Attachment? = nil,
         createdAt: Date? = nil,
         authorName: String? = nil,
         authorInitials: String? = nil,
         cityLabel: String? = nil,
         authorIsPrivate: Bool? = nil,
         isAd: Bool? = nil) {
        self.id = id
        self.authorId = authorId
        self.time = time
        self.kind = kind
        self.body = body
        self.mood = mood
        self.likes = likes
        self.comments = comments
        self.attachment = attachment
        self.createdAt = createdAt
        self.authorName = authorName
        self.authorInitials = authorInitials
        self.cityLabel = cityLabel
        self.authorIsPrivate = authorIsPrivate
        self.isAd = isAd
    }

    /// Posts older than 180 days are filtered out before display.
    static let retentionInterval: TimeInterval = 180 * 24 * 60 * 60

    var isWithinRetention: Bool {
        guard let createdAt else { return true } // legacy/mock posts
        return Date().timeIntervalSince(createdAt) < Self.retentionInterval
    }

    enum Kind: String, Hashable {
        case text, game, court
    }

    struct Mood: Hashable {
        let label: String
        let color: Color
    }

    enum Attachment: Hashable {
        case stat(label: String, rows: [StatRow])
        case court(courtId: String, variant: HSCourtImageVariant)
    }

    struct StatRow: Hashable {
        let label: String
        let value: String
    }
}

struct HSFeedComment: Identifiable, Hashable {
    let id: String
    let postId: String
    let authorId: String
    let time: String
    var body: String
    var likes: Int
    /// Top-level comments have nil; replies point to their parent's id.
    let parentId: String?
}

enum HSFeedMock {
    static let posts: [HSFeedPost] = [
        HSFeedPost(
            id: "p1", authorId: "f1", time: "12m", kind: .text,
            body: "Woke up sore as hell but already lacing up. Third day in a row at First Ward. This is the year I finally fix my left hand.",
            mood: .init(label: "Locked in", color: Color(red: 0.043, green: 0.118, blue: 0.247)),
            likes: 42, comments: 8, attachment: nil),

        HSFeedPost(
            id: "p2", authorId: "f4", time: "38m", kind: .game,
            body: "Ran 7 straight at the Yard today. Got put on the worst team 4 times and STILL went 6–1. They know.",
            mood: .init(label: "Cooking", color: Color(red: 0.780, green: 0.482, blue: 0.227)),
            likes: 127, comments: 24,
            attachment: .stat(label: "Today at First Ward", rows: [
                .init(label: "Runs", value: "7"),
                .init(label: "Record", value: "6–1"),
                .init(label: "Buckets", value: "28"),
            ])),

        HSFeedPost(
            id: "p3", authorId: "f2", time: "1h", kind: .text,
            body: "Unpopular opinion: a clean midrange is more useful than a deep three if you actually want to win pickup. Nobody's contesting 17-footers.",
            mood: .init(label: "Thinking", color: Color(red: 0.239, green: 0.263, blue: 0.294)),
            likes: 203, comments: 61, attachment: nil),

        HSFeedPost(
            id: "p4", authorId: "f6", time: "2h", kind: .court,
            body: "West Charlotte hits different at sunset. Full court, lights coming on, breeze rolling in off Beatties Ford. Everything clicks.",
            mood: .init(label: "Grateful", color: Color(red: 0.133, green: 0.627, blue: 0.420)),
            likes: 89, comments: 11,
            attachment: .court(courtId: "c5", variant: .hero5)),

        HSFeedPost(
            id: "p5", authorId: "f3", time: "3h", kind: .text,
            body: "Took an elbow to the jaw on the last possession. Stayed in. Hit the gamewinner. Ice pack and a smile.",
            mood: .init(label: "Battle tested", color: Color(red: 0.486, green: 0.176, blue: 0.071)),
            likes: 311, comments: 47, attachment: nil),

        HSFeedPost(
            id: "p6", authorId: "f5", time: "5h", kind: .text,
            body: "Does anybody else get in their head about shooting when there's a line waiting? Worst feeling. I'll drain 20 in warmups then brick my first open look.",
            mood: .init(label: "In my head", color: Color(red: 0.102, green: 0.227, blue: 0.431)),
            likes: 76, comments: 29, attachment: nil),

        HSFeedPost(
            id: "p7", authorId: "f1", time: "Yesterday", kind: .text,
            body: "Shoutout to the older guys at Freedom Park. They'll talk trash for 2 quarters then pull you aside and teach you how to actually use a screen. Real ones.",
            mood: .init(label: "Respect", color: Color(red: 0.043, green: 0.118, blue: 0.247)),
            likes: 154, comments: 19, attachment: nil),
    ]

    static let comments: [HSFeedComment] = [
        // p2 (Dre's game recap)
        .init(id: "c1", postId: "p2", authorId: "f1", time: "32m",
              body: "6–1 with the bottom of the barrel? That's the real flex.", likes: 14, parentId: nil),
        .init(id: "c2", postId: "p2", authorId: "f4", time: "30m",
              body: "they kept stacking me with the same dude who couldn't hit a layup 😭",
              likes: 8, parentId: "c1"),
        .init(id: "c3", postId: "p2", authorId: "f6", time: "20m",
              body: "Pull up to the cage tomorrow. I got next.", likes: 4, parentId: nil),

        // p3 (midrange take)
        .init(id: "c4", postId: "p3", authorId: "f5", time: "55m",
              body: "Absolutely. Defenders in pickup live under the line. Easy money.",
              likes: 22, parentId: nil),
        .init(id: "c5", postId: "p3", authorId: "f3", time: "48m",
              body: "Nah, threes still rule. Math is math.", likes: 7, parentId: nil),
        .init(id: "c6", postId: "p3", authorId: "f2", time: "40m",
              body: "Spacing matters more than range in a 5v5 half court.",
              likes: 5, parentId: "c5"),

        // p4 (court vibe)
        .init(id: "c7", postId: "p4", authorId: "f1", time: "1h",
              body: "West Charlotte at golden hour is sacred.", likes: 9, parentId: nil),

        // p5 (battle tested)
        .init(id: "c8", postId: "p5", authorId: "f6", time: "2h",
              body: "DOG.", likes: 32, parentId: nil),
        .init(id: "c9", postId: "p5", authorId: "f4", time: "2h",
              body: "Hope the jaw's good 🙏", likes: 11, parentId: nil),

        // p1 (left hand)
        .init(id: "c10", postId: "p1", authorId: "f2", time: "10m",
              body: "Left hand summer. Do 100 left-hand lay-ins before each run.",
              likes: 6, parentId: nil),
    ]

    static let composerMoods: [HSFeedPost.Mood] = [
        .init(label: "Locked in",  color: Color(red: 0.043, green: 0.118, blue: 0.247)),
        .init(label: "Cooking",    color: Color(red: 0.780, green: 0.482, blue: 0.227)),
        .init(label: "Grateful",   color: Color(red: 0.133, green: 0.627, blue: 0.420)),
        .init(label: "In my head", color: Color(red: 0.102, green: 0.227, blue: 0.431)),
        .init(label: "Tired",      color: Color(red: 0.420, green: 0.447, blue: 0.502)),
        .init(label: "Hyped",      color: Color(red: 0.753, green: 0.337, blue: 0.129)),
    ]
}
