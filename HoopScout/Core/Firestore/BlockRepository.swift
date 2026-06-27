//
//  BlockRepository.swift
//  HoopScout
//
//  Per-user block list. Stored at users/{uid}/blocked/{blockedUid}. The live
//  set is exposed as a published `blockedIds` so UGC views can hide content
//  authored by blocked users without re-fetching for every render.
//
//  Required by App Store Guideline 1.2 for apps with user-to-user contact.
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class BlockRepository: ObservableObject {
    static let shared = BlockRepository()

    @Published private(set) var blockedIds: Set<String> = []

    private var listener: ListenerRegistration?
    private var observedUid: String?

    private init() {}

    // MARK: - Lifecycle

    /// Start observing the signed-in user's block list. Safe to call again
    /// when the auth state changes — the listener is re-bound to the new uid.
    func start(forUid uid: String) {
        guard observedUid != uid else { return }
        stop()
        observedUid = uid
        listener = Firestore.firestore()
            .collection("users").document(uid)
            .collection("blocked")
            .addSnapshotListener { [weak self] snap, _ in
                let ids = Set((snap?.documents ?? []).map { $0.documentID })
                Task { @MainActor in self?.blockedIds = ids }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        observedUid = nil
        blockedIds = []
    }

    // MARK: - Queries

    func isBlocked(_ uid: String) -> Bool {
        blockedIds.contains(uid)
    }

    // MARK: - Mutations

    func block(_ targetUid: String) async throws {
        guard let me = Auth.auth().currentUser?.uid, !targetUid.isEmpty, me != targetUid else {
            return
        }
        try await Firestore.firestore()
            .collection("users").document(me)
            .collection("blocked").document(targetUid)
            .setData([
                "blockedAt": FieldValue.serverTimestamp()
            ])
    }

    func unblock(_ targetUid: String) async throws {
        guard let me = Auth.auth().currentUser?.uid, !targetUid.isEmpty else { return }
        try await Firestore.firestore()
            .collection("users").document(me)
            .collection("blocked").document(targetUid)
            .delete()
    }
}
