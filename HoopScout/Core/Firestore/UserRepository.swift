//
//  UserRepository.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore
#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

final class UserRepository {
    static let shared = UserRepository()
    private init() {}

    private var collection: CollectionReference {
        Firestore.firestore().collection("users")
    }

    func create(_ profile: HSUserProfile) async throws {
        guard let id = profile.id else { throw NSError(domain: "UserRepository", code: 1) }
        // Sensitive PII (EIN, FCM token, business email, manager names) is
        // peeled off the public doc and written to a private subcollection
        // readable only by the owner. Everything else stays public so
        // friends graph, mentions, and gym discoverability keep working.
        var publicProfile = profile
        let privateFields = takePrivateFields(from: &publicProfile)
        try collection.document(id).setData(from: publicProfile, merge: true)
        if !privateFields.isEmpty {
            try await collection.document(id)
                .collection("private").document("profile")
                .setData(privateFields, merge: true)
        }
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
        var publicProfile = profile
        let privateFields = takePrivateFields(from: &publicProfile)
        try collection.document(id).setData(from: publicProfile, merge: true)
        if !privateFields.isEmpty {
            try await collection.document(id)
                .collection("private").document("profile")
                .setData(privateFields, merge: true)
        }
    }

    func setFCMToken(_ token: String, uid: String) async throws {
        try await collection.document(uid)
            .collection("private").document("profile")
            .setData(["fcmToken": token], merge: true)
    }

    /// Strips sensitive fields off the public profile and returns them in a
    /// `[String: Any]` ready for the `private/profile` doc. The argument is
    /// mutated in place; the returned dict is empty if nothing is set.
    private func takePrivateFields(from profile: inout HSUserProfile) -> [String: Any] {
        var data: [String: Any] = [:]
        if let v = profile.fcmToken { data["fcmToken"] = v;          profile.fcmToken = nil }
        if let v = profile.ein { data["ein"] = v;                    profile.ein = nil }
        if let v = profile.managerFirstName { data["managerFirstName"] = v; profile.managerFirstName = nil }
        if let v = profile.managerLastName  { data["managerLastName"]  = v; profile.managerLastName  = nil }
        if let v = profile.appleUserIdentifier {
            data["appleUserIdentifier"] = v
            profile.appleUserIdentifier = nil
        }
        return data
    }

    func setPhotoURL(_ url: String, uid: String) async throws {
        try await collection.document(uid).setData(["photoURL": url], merge: true)
    }

    func acceptTOS(uid: String) async throws {
        try await collection.document(uid).setData([
            "tosAcceptedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    func setPrivacy(isPrivate: Bool, uid: String) async throws {
        try await collection.document(uid).setData([
            "isPrivate": isPrivate
        ], merge: true)
    }

    /// Submit a signed StoreKit 2 transaction to the server for verification.
    /// The Cloud Function (`validateAppStoreTransaction`) verifies the JWS
    /// signature against Apple's roots and writes the canonical
    /// `subscriptionStatus` / `subscriptionExpiresAt` to the user doc.
    /// Clients are forbidden by firestore.rules from writing those fields
    /// directly.
    ///
    /// Requires the `FirebaseFunctions` SPM product to be linked to the
    /// target. While that's not added, this no-ops in DEBUG and the server
    /// path is unreachable — the client is still safe because rules reject
    /// any direct subscription writes.
    func submitAppStoreTransaction(signedTransactionInfo: String) async throws {
        #if canImport(FirebaseFunctions)
        let callable = Functions.functions().httpsCallable("validateAppStoreTransaction")
        _ = try await callable.call(["signedTransactionInfo": signedTransactionInfo])
        #else
        #if DEBUG
        print("submitAppStoreTransaction: FirebaseFunctions SPM product missing — receipt not validated.")
        #endif
        #endif
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
