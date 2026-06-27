//
//  ArticleRepository.swift
//  HoopScout
//
//  Firestore-backed store for gym-authored local articles. Surfaced in
//  the News tab of the feed.
//

import Foundation
import FirebaseFirestore

@MainActor
final class ArticleRepository {
    static let shared = ArticleRepository()
    private init() {}

    private var db: Firestore { Firestore.firestore() }
    private var collection: CollectionReference { db.collection("articles") }

    // MARK: - Write

    /// Persist an article authored by a gym account. Gym status is
    /// validated server-side via the firestore.rules `articles` rule;
    /// the client check here is a defense-in-depth guard.
    func add(article: HSArticle, author: HSUserProfile) async throws {
        guard author.isGym else { return }

        var data: [String: Any] = [
            "authorId": article.authorId,
            "authorName": author.businessName ?? author.name,
            "title": article.title,
            "body": article.body,
            "createdAt": Timestamp(date: article.createdAt)
        ]
        if let url = article.url {
            data["url"] = url.absoluteString
        }

        try await collection.document(article.id).setData(data, merge: true)
    }

    // MARK: - Observe

    /// Live stream of gym-authored articles, newest first.
    func observe(limit: Int = 100) -> AsyncStream<[HSArticle]> {
        AsyncStream { continuation in
            let listener = collection
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .addSnapshotListener { snap, error in
                    if let error {
                        #if DEBUG
                        print("ArticleRepository observe error:", error.localizedDescription)
                        #endif
                        continuation.yield([])
                        return
                    }
                    let articles: [HSArticle] = (snap?.documents ?? [])
                        .compactMap { Self.decode($0) }
                    continuation.yield(articles)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Decode

    private static func decode(_ doc: QueryDocumentSnapshot) -> HSArticle? {
        let data = doc.data()
        guard let authorId = data["authorId"] as? String,
              let authorName = data["authorName"] as? String,
              let title = data["title"] as? String,
              let body = data["body"] as? String else { return nil }

        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
        let url = (data["url"] as? String).flatMap(URL.init(string:))

        return HSArticle(
            id: doc.documentID,
            authorId: authorId,
            authorName: authorName,
            title: title,
            body: body,
            url: url,
            createdAt: createdAt
        )
    }
}
