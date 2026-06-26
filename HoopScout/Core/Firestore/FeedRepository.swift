//
//  FeedRepository.swift
//  HoopScout
//
//  Shared Firestore-backed store for Feed posts. Posts are persisted server-
//  side for 180 days and scoped to the poster's city so users see what
//  hoopers in their area are saying.
//

import Foundation
import CoreLocation
import FirebaseFirestore

@MainActor
final class FeedRepository {
    static let shared = FeedRepository()
    private init() {}

    private var db: Firestore { Firestore.firestore() }
    private var collection: CollectionReference { db.collection("feedPosts") }

    private static let retention: TimeInterval = 180 * 24 * 60 * 60

    // MARK: - Write

    /// Persist a composer-created post. Only text posts are supported here —
    /// attachment-bearing demo posts stay session-local.
    func add(post: HSFeedPost,
             author: HSUserProfile,
             location: CLLocation?,
             cityLabel: String?) async throws {
        guard post.kind == .text else { return }
        let createdAt = post.createdAt ?? Date()
        let expiresAt = createdAt.addingTimeInterval(Self.retention)

        var data: [String: Any] = [
            "authorId": post.authorId,
            "authorName": author.name,
            "authorInitials": author.initials,
            "body": post.body,
            "moodLabel": post.mood.label,
            "likes": post.likes,
            "comments": post.comments,
            "createdAt": Timestamp(date: createdAt),
            "expiresAt": Timestamp(date: expiresAt)
        ]
        if let cityLabel, !cityLabel.isEmpty {
            data["cityLabel"] = cityLabel
        }
        if let location {
            data["lat"] = location.coordinate.latitude
            data["lon"] = location.coordinate.longitude
        }

        try await collection.document(post.id).setData(data, merge: true)
    }

    // MARK: - Observe

    /// Live stream of posts within the 180-day retention window, newest
    /// first. Callers can scope by city client-side; we don't enforce a
    /// composite index here so the query stays cheap.
    func observe(limit: Int = 200) -> AsyncStream<[HSFeedPost]> {
        AsyncStream { continuation in
            let cutoff = Date().addingTimeInterval(-Self.retention)
            let listener = collection
                .whereField("createdAt", isGreaterThan: Timestamp(date: cutoff))
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .addSnapshotListener { snap, error in
                    if let error {
                        #if DEBUG
                        print("FeedRepository observe error:", error.localizedDescription)
                        #endif
                        continuation.yield([])
                        return
                    }
                    let posts: [HSFeedPost] = (snap?.documents ?? [])
                        .compactMap { Self.decode($0) }
                    continuation.yield(posts)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Decode

    private static func decode(_ doc: QueryDocumentSnapshot) -> HSFeedPost? {
        let data = doc.data()
        guard let authorId = data["authorId"] as? String,
              let body = data["body"] as? String else { return nil }

        let moodLabel = (data["moodLabel"] as? String) ?? HSFeedMock.composerMoods[0].label
        let mood = HSFeedMock.composerMoods.first { $0.label == moodLabel }
            ?? HSFeedMock.composerMoods[0]

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
        let likes = data["likes"] as? Int ?? 0
        let comments = data["comments"] as? Int ?? 0
        let authorName = data["authorName"] as? String
        let authorInitials = data["authorInitials"] as? String
        let cityLabel = data["cityLabel"] as? String

        return HSFeedPost(
            id: doc.documentID,
            authorId: authorId,
            time: createdAt.map(relativeTime) ?? "now",
            kind: .text,
            body: body,
            mood: mood,
            likes: likes,
            comments: comments,
            attachment: nil,
            createdAt: createdAt,
            authorName: authorName,
            authorInitials: authorInitials,
            cityLabel: cityLabel
        )
    }

    private static func relativeTime(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
