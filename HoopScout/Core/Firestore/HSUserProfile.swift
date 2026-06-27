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
    /// When true, the user has marked their account private. Existing docs
    /// without this field are treated as public.
    var isPrivate: Bool?
    /// Distinguishes hooper accounts from gym/business accounts. "gym" for
    /// indoor courts / rec centers; nil or "hooper" for regular users.
    var accountKind: String?
    var businessName: String?
    var ein: String?
    var businessAddress: String?
    var managerFirstName: String?
    var managerLastName: String?
    /// Apple's stable user identifier (sub claim) captured at gym signup.
    /// Stored in the private subcollection by `UserRepository` so it can't
    /// leak to other users. Used server-side to prevent trial restart abuse.
    var appleUserIdentifier: String?
    /// "small" (≈high school court → $49/yr) or "large" (college+ → $99/yr).
    /// Captured at gym signup and used to derive the renewal price.
    var gymCourtSize: String?
    /// "trial", "active", or "expired". Nil for non-gym accounts.
    var subscriptionStatus: String?
    /// When the 7-day free trial began (set on first gym sign-in).
    var trialStartedAt: Date?
    /// When the current paid/trial period ends. For a fresh trial this is
    /// `trialStartedAt + 7 days`. Billing engine should refresh it on renewal.
    var subscriptionExpiresAt: Date?

    var isGym: Bool { accountKind == "gym" }

    /// Days remaining in the trial, clamped to [0, 7]. Returns nil when the
    /// account isn't in a trial.
    var trialDaysRemaining: Int? {
        guard subscriptionStatus == "trial", let started = trialStartedAt else { return nil }
        let elapsed = Date().timeIntervalSince(started)
        let remaining = max(0, 7 - Int(elapsed / 86_400))
        return min(remaining, 7)
    }

    /// True for a gym account whose trial or paid subscription hasn't
    /// expired yet. Gates ad posting and article uploads.
    var hasActiveGymSubscription: Bool {
        guard isGym else { return false }
        let status = subscriptionStatus ?? ""
        guard status == "trial" || status == "active" else { return false }
        if let expires = subscriptionExpiresAt {
            return expires > Date()
        }
        return status == "trial" // Trial without an explicit expiry — be lenient.
    }

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
         tosAcceptedAt: Date? = nil,
         isPrivate: Bool? = nil,
         accountKind: String? = nil,
         businessName: String? = nil,
         ein: String? = nil,
         businessAddress: String? = nil,
         managerFirstName: String? = nil,
         managerLastName: String? = nil,
         appleUserIdentifier: String? = nil,
         gymCourtSize: String? = nil,
         subscriptionStatus: String? = nil,
         trialStartedAt: Date? = nil,
         subscriptionExpiresAt: Date? = nil) {
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
        self.isPrivate = isPrivate
        self.accountKind = accountKind
        self.businessName = businessName
        self.ein = ein
        self.businessAddress = businessAddress
        self.managerFirstName = managerFirstName
        self.managerLastName = managerLastName
        self.appleUserIdentifier = appleUserIdentifier
        self.gymCourtSize = gymCourtSize
        self.subscriptionStatus = subscriptionStatus
        self.trialStartedAt = trialStartedAt
        self.subscriptionExpiresAt = subscriptionExpiresAt
    }

    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        return (first + last).uppercased()
    }
}
