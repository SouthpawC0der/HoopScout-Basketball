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
    var stars: Int
    var comment: String?
    var courtId: String?
    var createdAt: Date?
}
