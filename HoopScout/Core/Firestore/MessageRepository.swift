//
//  MessageRepository.swift
//  HoopScout
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class MessageRepository: ObservableObject {
    static let shared = MessageRepository()

    private var db: Firestore { Firestore.firestore() }
    private var threads: CollectionReference {
        db.collection("threads")
    }

    /// Deterministic thread ID — sorted UIDs joined.
    func threadId(_ uidA: String, _ uidB: String) -> String {
        [uidA, uidB].sorted().joined(separator: "_")
    }

    // MARK: - Create / fetch

    /// Idempotently creates (or refreshes) a 1:1 thread between two users.
    /// We use a local Timestamp instead of FieldValue.serverTimestamp() for
    /// updatedAt because the snapshot listener's `order(by: "updatedAt")`
    /// would otherwise hide the doc until the server resolves the sentinel —
    /// which is what caused the "new thread disappears" bug. The next
    /// `send()` will overwrite this with serverTimestamp() anyway.
    @discardableResult
    func createOrGetThread(current: HSUserProfile, other: HSUserProfile) async throws -> String {
        guard let currentId = current.id, let otherId = other.id else {
            throw NSError(domain: "MessageRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user id"])
        }
        let id = threadId(currentId, otherId)
        try await threads.document(id).setData([
            "participants": [currentId, otherId].sorted(),
            "participantsInfo": [
                currentId: ["name": current.name, "initials": current.initials],
                otherId: ["name": other.name, "initials": other.initials]
            ],
            "unread": [currentId: 0, otherId: 0],
            "updatedAt": Timestamp(date: Date())
        ], merge: true)
        return id
    }

    // MARK: - Observe

    func observeThreads(for uid: String) -> AsyncStream<[HSThreadDoc]> {
        AsyncStream { continuation in
            // Don't .order(by: "updatedAt") on the query — Firestore drops
            // docs where the field doesn't yet exist (which happens briefly
            // for newly-created threads using serverTimestamp). Sort client-
            // side instead so freshly created threads appear immediately.
            let listener = threads
                .whereField("participants", arrayContains: uid)
                .addSnapshotListener { snap, error in
                    if let error {
                        #if DEBUG
                        print("observeThreads error:", error.localizedDescription)
                        #endif
                        continuation.yield([])
                        return
                    }
                    let docs: [HSThreadDoc] = (snap?.documents.compactMap {
                        try? $0.data(as: HSThreadDoc.self)
                    } ?? []).sorted { lhs, rhs in
                        (lhs.updatedAt ?? .distantPast) > (rhs.updatedAt ?? .distantPast)
                    }
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    func observeMessages(threadId: String) -> AsyncStream<[HSMessageDoc]> {
        AsyncStream { continuation in
            let listener = threads.document(threadId).collection("messages")
                .order(by: "createdAt")
                .addSnapshotListener { snap, _ in
                    let docs: [HSMessageDoc] = snap?.documents.compactMap {
                        try? $0.data(as: HSMessageDoc.self)
                    } ?? []
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    // MARK: - Send / read

    func send(text: String, threadId: String, senderId: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let db = self.db
        let threadRef = threads.document(threadId)

        _ = try await db.runTransaction({ tx, errorPointer -> Any? in
            do {
                let snap = try tx.getDocument(threadRef)
                guard let participants = snap.data()?["participants"] as? [String] else {
                    return nil
                }
                let recipients = participants.filter { $0 != senderId }

                // Write message
                let messageRef = threadRef.collection("messages").document()
                tx.setData([
                    "senderId": senderId,
                    "text": trimmed,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: messageRef)

                // Update parent thread
                var update: [String: Any] = [
                    "lastMessage": [
                        "text": trimmed,
                        "senderId": senderId,
                        "timestamp": FieldValue.serverTimestamp()
                    ],
                    "updatedAt": FieldValue.serverTimestamp()
                ]
                for rid in recipients {
                    update["unread.\(rid)"] = FieldValue.increment(Int64(1))
                }
                tx.updateData(update, forDocument: threadRef)
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
            }
            return nil
        })
    }

    func markRead(threadId: String, uid: String) async throws {
        try await threads.document(threadId).updateData([
            "unread.\(uid)": 0
        ])
    }

    /// Deletes a thread and every message in its subcollection. Firestore
    /// doesn't recursively delete subcollections from the client, so we
    /// page through messages first.
    func deleteThread(threadId: String) async throws {
        let threadRef = threads.document(threadId)
        let messagesRef = threadRef.collection("messages")

        // Page through and delete in batches so we don't hit the
        // single-batch limit on very long conversations.
        while true {
            let snap = try await messagesRef.limit(to: 400).getDocuments()
            if snap.documents.isEmpty { break }
            let batch = db.batch()
            for doc in snap.documents {
                batch.deleteDocument(doc.reference)
            }
            try await batch.commit()
            if snap.documents.count < 400 { break }
        }
        try await threadRef.delete()
    }
}
