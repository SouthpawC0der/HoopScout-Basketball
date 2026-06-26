//
//  HSRunDoc.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSRunDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var courtId: String
    var courtName: String
    var startedAt: Date?
    var endedAt: Date?
    /// Total minutes spent at the court during the check-in.
    var durationMinutes: Int
    /// Snapshot of co-players (other check-ins observed during the session).
    var coPlayers: [CoPlayer]
    /// True if the rater has submitted a court rating for this run's court.
    var rated: Bool

    struct CoPlayer: Codable, Hashable {
        var uid: String
        var name: String
        var initials: String
    }
}
