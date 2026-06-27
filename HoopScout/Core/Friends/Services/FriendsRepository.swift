//
//  FriendsRepository.swift
//  HoopScout
//
//  Following/follower graph backed by Firestore subcollections under user docs.
//  We mirror writes client-side: the follower writes both their own
//  users/{me}/following/{them} doc AND a users/{them}/followers/{me} doc so
//  the target sees an immediate followers update without needing a Cloud
//  Function. Aggregate counters on both user docs are bumped in the same
//  batched write.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class FriendsRepository: ObservableObject {
    static let shared = FriendsRepository()

    private var db: Firestore { Firestore.firestore() }
    private func userRef(_ uid: String) -> DocumentReference {
        db.collection("users").document(uid)
    }

    // MARK: - Observe

    func observeFollowing(for uid: String, limit: Int = 200) -> AsyncStream<[HSFollowDoc]> {
        AsyncStream { continuation in
            // Don't .order(by: "since") on the query — Firestore drops
            // docs where the field doesn't yet exist, and `since` is
            // briefly null after a write that used serverTimestamp().
            // That caused a "follow appears, then disappears" flicker.
            // Sort client-side instead.
            let listener = userRef(uid).collection("following")
                .limit(to: limit)
                .addSnapshotListener { snap, error in
                    if let error {
                        #if DEBUG
                        print("observeFollowing error:", error.localizedDescription)
                        #endif
                        continuation.yield([])
                        return
                    }
                    let docs: [HSFollowDoc] = (snap?.documents.compactMap {
                        try? $0.data(as: HSFollowDoc.self)
                    } ?? []).sorted { lhs, rhs in
                        (lhs.since ?? .distantPast) > (rhs.since ?? .distantPast)
                    }
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observeFollowers(for uid: String, limit: Int = 200) -> AsyncStream<[HSFollowDoc]> {
        AsyncStream { continuation in
            let listener = userRef(uid).collection("followers")
                .limit(to: limit)
                .addSnapshotListener { snap, error in
                    if let error {
                        #if DEBUG
                        print("observeFollowers error:", error.localizedDescription)
                        #endif
                        continuation.yield([])
                        return
                    }
                    let docs: [HSFollowDoc] = (snap?.documents.compactMap {
                        try? $0.data(as: HSFollowDoc.self)
                    } ?? []).sorted { lhs, rhs in
                        (lhs.since ?? .distantPast) > (rhs.since ?? .distantPast)
                    }
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Live "am I following this user?" check.
    func observeIsFollowing(me: String, target: String) -> AsyncStream<Bool> {
        AsyncStream { continuation in
            let listener = userRef(me).collection("following").document(target)
                .addSnapshotListener { snap, _ in
                    continuation.yield(snap?.exists ?? false)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Write

    /// Follow `target` — writes my "following" entry, mirrors a "followers"
    /// entry on the target, and bumps both counters in a single batch.
    /// On success, drops a "new follower" notification into the target's
    /// inbox so they see it in the bell.
    func follow(target: HSUserProfile, as me: HSUserProfile) async throws {
        guard let myId = me.id, let targetId = target.id, myId != targetId else { return }
        let batch = db.batch()

        // Use Timestamp(date: Date()) instead of FieldValue.serverTimestamp()
        // for `since` because the snapshot listener was previously dropping
        // freshly-written docs whose serverTimestamp hadn't resolved yet.
        let now = Timestamp(date: Date())

        let myFollowing = userRef(myId).collection("following").document(targetId)
        batch.setData([
            "name": target.name,
            "initials": target.initials,
            "since": now
        ], forDocument: myFollowing)

        let theirFollowers = userRef(targetId).collection("followers").document(myId)
        batch.setData([
            "name": me.name,
            "initials": me.initials,
            "since": now
        ], forDocument: theirFollowers)

        batch.setData([
            "followingCount": FieldValue.increment(Int64(1))
        ], forDocument: userRef(myId), merge: true)

        batch.setData([
            "followersCount": FieldValue.increment(Int64(1))
        ], forDocument: userRef(targetId), merge: true)

        try await batch.commit()

        await NotificationRepository.shared.add(
            NotificationPayload(
                type: "new_follower",
                title: "\(me.name) followed you",
                body: "Tap to view their profile.",
                userUid: myId,
                userName: me.name,
                userInitials: me.initials
            ),
            forUid: targetId
        )
    }

    /// Unfollow — deletes both sides + decrements both counters.
    func unfollow(targetUid: String, asUid: String) async throws {
        guard asUid != targetUid else { return }
        let batch = db.batch()

        batch.deleteDocument(userRef(asUid).collection("following").document(targetUid))
        batch.deleteDocument(userRef(targetUid).collection("followers").document(asUid))

        batch.setData([
            "followingCount": FieldValue.increment(Int64(-1))
        ], forDocument: userRef(asUid), merge: true)

        batch.setData([
            "followersCount": FieldValue.increment(Int64(-1))
        ], forDocument: userRef(targetUid), merge: true)

        try await batch.commit()
    }
}
