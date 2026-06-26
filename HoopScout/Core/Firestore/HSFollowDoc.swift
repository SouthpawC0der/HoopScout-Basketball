//
//  HSFollowDoc.swift
//  HoopScout
//
//  Denormalized entry in either users/{uid}/following/* or users/{uid}/followers/*.
//  The document ID is the OTHER user's uid (the followee or follower).
//

import Foundation
import FirebaseFirestore

struct HSFollowDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var initials: String
    var since: Date?
}
