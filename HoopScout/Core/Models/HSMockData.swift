//
//  HSMockData.swift
//  HoopScout
//

import SwiftUI

enum HSMockData {
    static let user = HSUser(
        name: "Marcus Johnson",
        handle: "@marcus.j",
        location: "Brooklyn, NY",
        initials: "MJ",
        avatarColors: [
            Color(red: 0.102, green: 0.212, blue: 0.365),
            Color(red: 0.173, green: 0.325, blue: 0.510)
        ],
        skill: "Competitive",
        bio: "Point guard. Looking for runs after work. DM me for 5s.",
        runs: 87,
        following: 312,
        followers: 248
    )

    static let friends: [HSFriend] = [
        HSFriend(id: "f1", name: "Tyrese W.", initials: "TW", skill: "Competitive",
                 avatarColors: [Color(red: 0.753, green: 0.337, blue: 0.129), Color(red: 0.867, green: 0.420, blue: 0.125)]),
        HSFriend(id: "f2", name: "Jordan K.", initials: "JK", skill: "Casual",
                 avatarColors: [Color(red: 0.184, green: 0.522, blue: 0.353), Color(red: 0.220, green: 0.631, blue: 0.412)]),
        HSFriend(id: "f3", name: "Mike R.", initials: "MR", skill: "Competitive",
                 avatarColors: [Color(red: 0.455, green: 0.259, blue: 0.063), Color(red: 0.718, green: 0.475, blue: 0.122)]),
        HSFriend(id: "f4", name: "Dre S.", initials: "DS", skill: "Competitive",
                 avatarColors: [Color(red: 0.333, green: 0.235, blue: 0.604), Color(red: 0.502, green: 0.353, blue: 0.835)]),
        HSFriend(id: "f5", name: "Kev L.", initials: "KL", skill: "Casual",
                 avatarColors: [Color(red: 0.173, green: 0.325, blue: 0.510), Color(red: 0.192, green: 0.510, blue: 0.808)]),
        HSFriend(id: "f6", name: "Ant B.", initials: "AB", skill: "Competitive",
                 avatarColors: [Color(red: 0.439, green: 0.141, blue: 0.349), Color(red: 0.722, green: 0.196, blue: 0.502)])
    ]

    static let courts: [HSCourt] = [
        HSCourt(id: "c1", name: "West 4th Street Courts", subtitle: "The Cage",
                distance: 0.8, rating: 4.8, reviews: 1243, playing: 18, maxCap: 24,
                skill: "Competitive", type: "Outdoor · Full",
                address: "3 6th Ave, New York, NY", tags: ["local", "popular"],
                friendsHere: ["f1", "f4", "f6"], hasGame: true,
                gameInfo: "5v5 run · starts in 22 min", img: .hero1,
                latitude: 40.7311, longitude: -74.0007),
        HSCourt(id: "c2", name: "Rucker Park", subtitle: "Holcombe Rucker",
                distance: 2.4, rating: 4.9, reviews: 2871, playing: 32, maxCap: 40,
                skill: "Competitive", type: "Outdoor · 2 Full",
                address: "155th St & Frederick Douglass Blvd", tags: ["popular"],
                friendsHere: [], hasGame: false, gameInfo: nil, img: .hero2,
                latitude: 40.8295, longitude: -73.9407),
        HSCourt(id: "c3", name: "Chelsea Piers Fieldhouse", subtitle: "Indoor · $15 drop-in",
                distance: 3.1, rating: 4.6, reviews: 412, playing: 11, maxCap: 20,
                skill: "Casual", type: "Indoor · Full",
                address: "Pier 62, 23rd St", tags: ["gyms", "popular"],
                friendsHere: ["f2"], hasGame: true,
                gameInfo: "Open run · now", img: .hero3,
                latitude: 40.7466, longitude: -74.0091),
        HSCourt(id: "c4", name: "Tompkins Square Park", subtitle: nil,
                distance: 1.2, rating: 4.2, reviews: 189, playing: 6, maxCap: 16,
                skill: "Casual", type: "Outdoor · Half",
                address: "500 E 9th St", tags: ["local"],
                friendsHere: ["f5"], hasGame: false, gameInfo: nil, img: .hero4,
                latitude: 40.7264, longitude: -73.9819),
        HSCourt(id: "c5", name: "Dyckman Courts", subtitle: "Monsignor Kett",
                distance: 8.7, rating: 4.7, reviews: 934, playing: 24, maxCap: 32,
                skill: "Competitive", type: "Outdoor · Full",
                address: "204th St & Nagle Ave", tags: ["popular"],
                friendsHere: ["f3"], hasGame: true,
                gameInfo: "Tournament · 7 PM", img: .hero5,
                latitude: 40.8669, longitude: -73.9242),
        HSCourt(id: "c6", name: "Life Time Sky", subtitle: "Members + guest",
                distance: 4.3, rating: 4.4, reviews: 267, playing: 8, maxCap: 16,
                skill: "Casual", type: "Indoor · Full",
                address: "1 Water St", tags: ["gyms"],
                friendsHere: [], hasGame: false, gameInfo: nil, img: .hero6,
                latitude: 40.7041, longitude: -74.0079),
        HSCourt(id: "c7", name: "Pier 2 Courts", subtitle: "Brooklyn Bridge Park",
                distance: 2.9, rating: 4.5, reviews: 521, playing: 14, maxCap: 24,
                skill: "Casual", type: "Outdoor · 2 Full",
                address: "Furman St & Pier 2", tags: ["local", "popular"],
                friendsHere: ["f1", "f5"], hasGame: false, gameInfo: nil, img: .hero7,
                latitude: 40.7016, longitude: -73.9978)
    ]

    static let threads: [HSThread] = [
        HSThread(id: "t1", friendId: "f1", last: "bet. ill pull up in 20",
                 time: "2m", unread: 2, online: true,
                 messages: [
                    HSMessage(me: false, text: "yo u at the cage later?", time: "3:42 PM"),
                    HSMessage(me: true, text: "ya prob after 5. u runnin?", time: "3:44 PM"),
                    HSMessage(me: false, text: "got next w/ jordan", time: "3:44 PM"),
                    HSMessage(me: false, text: "bet. ill pull up in 20", time: "3:45 PM")
                 ]),
        HSThread(id: "t2", friendId: "f2", last: "🔥🔥 see u there",
                 time: "14m", unread: 0, online: true,
                 messages: [
                    HSMessage(me: true, text: "chelsea piers at 7?", time: "3:28 PM"),
                    HSMessage(me: false, text: "🔥🔥 see u there", time: "3:31 PM")
                 ]),
        HSThread(id: "t3", friendId: "f3", last: "nah my knee still bad",
                 time: "1h", unread: 0, online: false,
                 messages: [
                    HSMessage(me: true, text: "dyckman tmrw?", time: "2:14 PM"),
                    HSMessage(me: false, text: "nah my knee still bad", time: "2:40 PM")
                 ]),
        HSThread(id: "t4", friendId: "f4", last: "who got winners",
                 time: "3h", unread: 1, online: false,
                 messages: [HSMessage(me: false, text: "who got winners", time: "12:45 PM")]),
        HSThread(id: "t5", friendId: "f6", last: "you owe me buckets fr",
                 time: "yesterday", unread: 0, online: false,
                 messages: [HSMessage(me: false, text: "you owe me buckets fr", time: "Yesterday")])
    ]

    static func friend(id: String) -> HSFriend? {
        friends.first { $0.id == id }
    }

    static func court(id: String) -> HSCourt? {
        courts.first { $0.id == id }
    }

    /// Builds a navigable HSUserProfile for a mock friend so the rest of the
    /// app can route to FriendProfileView. The Firestore refresh on appear
    /// will overwrite this with the real doc if one exists.
    static func userProfile(forFriendId id: String) -> HSUserProfile? {
        guard let f = friend(id: id) else { return nil }
        return HSUserProfile(
            id: f.id,
            name: f.name,
            handle: "",
            location: "",
            bio: "",
            skill: f.skill,
            runs: 0,
            followers: 0,
            following: 0
        )
    }
}
