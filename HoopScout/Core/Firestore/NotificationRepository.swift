//
//  NotificationRepository.swift
//  HoopScout
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class NotificationRepository: ObservableObject {
    static let shared = NotificationRepository()

    @Published private(set) var items: [HSNotificationDoc] = []
    @Published private(set) var unreadCount: Int = 0

    private var listener: ListenerRegistration?
    private var observingUid: String?

    private var db: Firestore { Firestore.firestore() }

    private init() {}

    func start(forUid uid: String?) {
        guard let uid else {
            listener?.remove()
            listener = nil
            observingUid = nil
            items = []
            unreadCount = 0
            return
        }
        if observingUid == uid, listener != nil { return }
        listener?.remove()
        observingUid = uid

        listener = db.collection("users").document(uid)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self else { return }
                let docs: [HSNotificationDoc] = snap?.documents.compactMap {
                    try? $0.data(as: HSNotificationDoc.self)
                } ?? []
                Task { @MainActor in
                    self.items = docs
                    self.unreadCount = docs.filter { $0.isUnread }.count
                }
            }
    }

    func stop() {
        listener?.remove()
        listener = nil
        observingUid = nil
        items = []
        unreadCount = 0
    }

    // MARK: - Writes

    func add(_ payload: NotificationPayload) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        var data: [String: Any] = [
            "type": payload.type,
            "title": payload.title,
            "body": payload.body,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let courtId = payload.courtId { data["courtId"] = courtId }
        if let courtName = payload.courtName { data["courtName"] = courtName }
        if let userUid = payload.userUid { data["userUid"] = userUid }
        if let userName = payload.userName { data["userName"] = userName }
        if let initials = payload.userInitials { data["userInitials"] = initials }

        try? await db.collection("users").document(uid)
            .collection("notifications").addDocument(data: data)
    }

    func markRead(_ id: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid)
            .collection("notifications").document(id)
            .setData(["readAt": FieldValue.serverTimestamp()], merge: true)
    }

    func markAllRead() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let unread = items.filter { $0.isUnread }
        for item in unread {
            guard let id = item.id else { continue }
            try? await db.collection("users").document(uid)
                .collection("notifications").document(id)
                .setData(["readAt": FieldValue.serverTimestamp()], merge: true)
        }
    }

    func delete(_ id: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("users").document(uid)
            .collection("notifications").document(id).delete()
    }
}

struct NotificationPayload {
    let type: String
    let title: String
    let body: String
    var courtId: String? = nil
    var courtName: String? = nil
    var userUid: String? = nil
    var userName: String? = nil
    var userInitials: String? = nil
}
