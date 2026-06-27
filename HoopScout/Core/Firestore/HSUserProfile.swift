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
    var activeCheckIn: HSActiveCheckIn?
    var followingCount: Int?
    var followersCount: Int?
    var photoURL: String?
    var ratingAverage: Double?
    var ratingCount: Int?
    var position: String?
    var education: String?
    var socials: [String: String]?
    /// Set when the user accepts the in-app Terms of Service. Nil means
    /// they haven't accepted yet and must do so before reaching the app.
    var tosAcceptedAt: Date?

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
         createdAt: Date? = nil,
         activeCheckIn: HSActiveCheckIn? = nil,
         followingCount: Int? = nil,
         followersCount: Int? = nil,
         photoURL: String? = nil,
         ratingAverage: Double? = nil,
         ratingCount: Int? = nil,
         position: String? = nil,
         education: String? = nil,
         socials: [String: String]? = nil,
         tosAcceptedAt: Date? = nil) {
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
        self.activeCheckIn = activeCheckIn
        self.followingCount = followingCount
        self.followersCount = followersCount
        self.photoURL = photoURL
        self.ratingAverage = ratingAverage
        self.ratingCount = ratingCount
        self.position = position
        self.education = education
        self.socials = socials
        self.tosAcceptedAt = tosAcceptedAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
