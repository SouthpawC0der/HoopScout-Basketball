//
//  HSNotificationDoc.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSNotificationDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var type: String       // "rate_court" | "rate_user" | "check_in" | "info"
    var title: String
    var body: String
    var createdAt: Date?
    var readAt: Date?
    /// Optional structured payload used for deep-linking.
    var courtId: String?
    var courtName: String?
    var userUid: String?
    var userName: String?
    var userInitials: String?

    var isUnread: Bool { readAt == nil }
}
