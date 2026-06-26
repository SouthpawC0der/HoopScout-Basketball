//
//  HSUserProfile.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

struct HSUserProfile: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var name: String
    var handle: String
    var location: String
    var bio: String
    var skill: String
    var runs: Int
    var followers: Int
    var following: Int
    var fcmToken: String?
    var createdAt: Date?

    init(id: String? = nil,
         name: String,
         handle: String,
         location: String,
         bio: String,
         skill: String,
         runs: Int,
         followers: Int,
         following: Int,
         fcmToken: String? = nil,
         createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.handle = handle
        self.location = location
        self.bio = bio
        self.skill = skill
        self.runs = runs
        self.followers = followers
        self.following = following
        self.fcmToken = fcmToken
        self.createdAt = createdAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
