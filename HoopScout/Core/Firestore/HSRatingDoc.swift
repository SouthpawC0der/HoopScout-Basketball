//
//  HSRatingDoc.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSCourtRatingDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var courtId: String
    var raterUid: String
    var stars: Int
    var createdAt: Date?
}

struct HSUserRatingDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var ratedUid: String
    var raterUid: String
    var raterName: String?
    /// Overall (average of the four category scores), kept for sort/display.
    var stars: Int
    var ballHandling: Int?
    var basketballIQ: Int?
    var teamPlay: Int?
    var toughness: Int?
    var comment: String?
    var courtId: String?
    var createdAt: Date?
}
