//
//  HSCourtDoc.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSCourtDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var address: String
    var lat: Double
    var lon: Double
    var maxCap: Int
    var skill: String?
    var type: String?
    var playingCount: Int?
    var updatedAt: Date?
    var ratingAverage: Double?
    var ratingCount: Int?
    var photoURL: String?
    var photoUploaderUID: String?
    var photoUpdatedAt: Date?
}

struct HSCheckInDoc: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var uid: String
    var displayName: String
    var initials: String
    var checkedInAt: Date?
    var expiresAt: Date?

    var isActive: Bool {
        guard let expiresAt else { return true }
        return expiresAt > Date()
    }
}

struct HSActiveCheckIn: Codable, Hashable {
    var courtId: String
    var name: String
    var checkedInAt: Date?
    var expiresAt: Date?
}
