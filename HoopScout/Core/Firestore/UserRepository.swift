//
//  UserRepository.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

final class UserRepository {
    static let shared = UserRepository()
    private init() {}

    private var collection: CollectionReference {
        Firestore.firestore().collection("users")
    }

    func create(_ profile: HSUserProfile) async throws {
        guard let id = profile.id else { throw NSError(domain: "UserRepository", code: 1) }
        try collection.document(id).setData(from: profile, merge: true)
    }

    func fetch(uid: String) async throws -> HSUserProfile? {
        let snap = try await collection.document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: HSUserProfile.self)
    }

    /// Live snapshot stream of a user doc. Used by AuthService for the current
    /// user (so follower/following counters and other server-side updates flow
    /// into the UI without a manual refresh) and by FriendProfileView for the
    /// target user.
    func observe(uid: String) -> AsyncStream<HSUserProfile?> {
        AsyncStream { continuation in
            let listener = collection.document(uid).addSnapshotListener { snap, _ in
                guard let snap, snap.exists else { continuation.yield(nil); return }
                let profile = try? snap.data(as: HSUserProfile.self)
                continuation.yield(profile)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func update(_ profile: HSUserProfile) async throws {
        guard let id = profile.id else { throw NSError(domain: "UserRepository", code: 1) }
        try collection.document(id).setData(from: profile, merge: true)
    }

    func setFCMToken(_ token: String, uid: String) async throws {
        try await collection.document(uid).setData(["fcmToken": token], merge: true)
    }

    func setPhotoURL(_ url: String, uid: String) async throws {
        try await collection.document(uid).setData(["photoURL": url], merge: true)
    }

    func acceptTOS(uid: String) async throws {
        try await collection.document(uid).setData([
            "tosAcceptedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    /// Fetch a page of user profiles (used by NewMessageView until a real
    /// friends graph is wired up). Excludes the given uid.
    func fetchAll(excluding excludeUid: String? = nil, limit: Int = 100) async throws -> [HSUserProfile] {
        let snap = try await collection.limit(to: limit).getDocuments()
        return snap.documents
            .compactMap { try? $0.data(as: HSUserProfile.self) }
            .filter { $0.id != excludeUid }
    }

    /// Best-effort name search. Firestore doesn't support substring matching
    /// natively, so we fetch a page and filter client-side. Capped to 200 to
    /// keep the read budget bounded as the user base grows.
    func search(query: String, excluding excludeUid: String? = nil,
                limit: Int = 200) async throws -> [HSUserProfile] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        let snap = try await collection.limit(to: limit).getDocuments()
        return snap.documents
            .compactMap { try? $0.data(as: HSUserProfile.self) }
            .filter { profile in
                profile.id != excludeUid
                    && (profile.name.localizedCaseInsensitiveContains(trimmed)
                        || profile.handle.localizedCaseInsensitiveContains(trimmed))
            }
    }
}
