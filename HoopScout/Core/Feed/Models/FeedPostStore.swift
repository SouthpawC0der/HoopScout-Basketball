//
//  FeedPostStore.swift
//  HoopScout
//
//  Local persistence for user-composed Feed posts. Mock demo posts stay
//  session-local; only posts the signed-in user creates get saved here so
//  they survive app restarts.
//
//  Posts are kept on the feed for 180 days. Anything older gets pruned at
//  load time so storage doesn't grow unbounded.
//

import Foundation

/// Codable shadow of HSFeedPost — sidesteps the SwiftUI.Color in `Mood` and
/// the enum-with-associated-values `Attachment` by capturing only the
/// fields a text post needs. Composer-created posts are always text so we
/// don't lose anything material.
private struct PersistedPost: Codable {
    let id: String
    let authorId: String
    let body: String
    let moodLabel: String
    let likes: Int
    let comments: Int
    let createdAt: Date
}

@MainActor
final class FeedPostStore {
    static let shared = FeedPostStore()
    private init() {}

    private let key = "hs_feed_posts_v1"
    private let retention = HSFeedPost.retentionInterval

    /// Load the user's saved posts, pruning anything past the 180-day window.
    /// Sorted newest-first to match what FeedView expects when it prepends
    /// these to the demo feed.
    func load() -> [HSFeedPost] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        guard let raw = try? JSONDecoder().decode([PersistedPost].self, from: data) else {
            return []
        }
        let cutoff = Date().addingTimeInterval(-retention)
        let kept = raw.filter { $0.createdAt > cutoff }

        // Trim the store if we pruned anything.
        if kept.count != raw.count {
            save(kept)
        }

        return kept
            .sorted { $0.createdAt > $1.createdAt }
            .map { hydrate($0) }
    }

    /// Persist `post` if it's the right kind (text, has a real createdAt).
    /// Returns immediately if it's a mock/demo post.
    func append(_ post: HSFeedPost) {
        guard let createdAt = post.createdAt, post.kind == .text else { return }
        var current = (try? JSONDecoder().decode(
            [PersistedPost].self,
            from: UserDefaults.standard.data(forKey: key) ?? Data()
        )) ?? []
        current.append(PersistedPost(
            id: post.id,
            authorId: post.authorId,
            body: post.body,
            moodLabel: post.mood.label,
            likes: post.likes,
            comments: post.comments,
            createdAt: createdAt
        ))
        save(current)
    }

    private func save(_ posts: [PersistedPost]) {
        guard let data = try? JSONEncoder().encode(posts) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func hydrate(_ persisted: PersistedPost) -> HSFeedPost {
        let mood = HSFeedMock.composerMoods.first { $0.label == persisted.moodLabel }
            ?? HSFeedMock.composerMoods[0]
        return HSFeedPost(
            id: persisted.id,
            authorId: persisted.authorId,
            time: Self.relativeTime(persisted.createdAt),
            kind: .text,
            body: persisted.body,
            mood: mood,
            likes: persisted.likes,
            comments: persisted.comments,
            attachment: nil,
            createdAt: persisted.createdAt
        )
    }

    private static func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
