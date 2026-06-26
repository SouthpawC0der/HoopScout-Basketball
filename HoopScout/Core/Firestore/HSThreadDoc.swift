//
//  HSThreadDoc.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSThreadDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var participants: [String]
    var participantsInfo: [String: ThreadParticipant]
    var lastMessage: ThreadLastMessage?
    var unread: [String: Int]
    var updatedAt: Date?

    struct ThreadParticipant: Codable, Hashable {
        var name: String
        var initials: String
    }

    struct ThreadLastMessage: Codable, Hashable {
        var text: String
        var senderId: String
        var timestamp: Date?
    }

    /// The other participant's UID relative to the given user.
    func otherUid(currentUid: String) -> String? {
        participants.first(where: { $0 != currentUid })
    }

    func otherInfo(currentUid: String) -> ThreadParticipant? {
        guard let id = otherUid(currentUid: currentUid) else { return nil }
        return participantsInfo[id]
    }

    func unreadCount(for uid: String) -> Int {
        unread[uid] ?? 0
    }
}

struct HSMessageDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var senderId: String
    var text: String
    var createdAt: Date?

    func isMe(_ uid: String) -> Bool { senderId == uid }
}
