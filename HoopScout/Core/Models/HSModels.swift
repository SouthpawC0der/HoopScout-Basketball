//
//  HSModels.swift
//  HoopScout
//

import SwiftUI

struct HSUser {
    var name: String
    var handle: String
    var location: String
    var initials: String
    var avatarColors: [Color]
    var skill: String
    var bio: String
    var runs: Int
    var following: Int
    var followers: Int
}

struct HSFriend: Identifiable, Hashable {
    let id: String
    let name: String
    var initials: String
    var skill: String
    var avatarColors: [Color]
}

struct HSCourt: Identifiable, Hashable {
    let id: String
    var name: String
    var subtitle: String?
    var distance: Double
    var rating: Double
    var reviews: Int
    var playing: Int
    var maxCap: Int
    var skill: String
    var type: String
    var address: String
    var tags: [String]
    var friendsHere: [String]
    var hasGame: Bool
    var gameInfo: String?
    var img: HSCourtImageVariant
}

enum HSCourtImageVariant: String, Hashable {
    case hero1, hero2, hero3, hero4, hero5, hero6, hero7
}

struct HSMessage: Identifiable, Hashable {
    let id = UUID()
    var me: Bool
    var text: String
    var time: String
}

struct HSThread: Identifiable, Hashable {
    let id: String
    let friendId: String
    var last: String
    var time: String
    var unread: Int
    var online: Bool
    var messages: [HSMessage]
}

enum HSProfileSelection: String, CaseIterable {
    case stats, followers, following
}
