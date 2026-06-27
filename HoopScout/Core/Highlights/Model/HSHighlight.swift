//
//  HSHighlight.swift
//  HoopScout
//
//  Created by Christopher Doyle on 6/26/26.
//

//
//  HSHighlight.swift
//  HoopScout
//
//  Model for user-uploaded basketball highlight videos.
//

import Foundation

struct HSHighlight: Identifiable, Hashable {
    let id: String
    let authorId: String
    let authorName: String
    let authorInitials: String
    let videoURL: URL?
    let thumbnailURL: URL?
    let caption: String
    let createdAt: Date
    var likes: Int
    var comments: Int
    var reposts: Int
    var views: Int
    /// Duration in seconds (max 90)
    let duration: TimeInterval
    /// Author's `isPrivate` flag captured at upload time. Used to gate
    /// visibility to followers + the author. Nil/false means public.
    var authorIsPrivate: Bool?
    
    init(id: String = UUID().uuidString,
         authorId: String,
         authorName: String,
         authorInitials: String,
         videoURL: URL? = nil,
         thumbnailURL: URL? = nil,
         caption: String,
         createdAt: Date = Date(),
         likes: Int = 0,
         comments: Int = 0,
         reposts: Int = 0,
         views: Int = 0,
         duration: TimeInterval,
         authorIsPrivate: Bool? = nil) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.authorInitials = authorInitials
        self.videoURL = videoURL
        self.thumbnailURL = thumbnailURL
        self.caption = caption
        self.createdAt = createdAt
        self.likes = likes
        self.comments = comments
        self.reposts = reposts
        self.views = views
        self.duration = min(duration, 90) // Enforce 90 second max
        self.authorIsPrivate = authorIsPrivate
    }
}

// MARK: - Mock Data

enum HSHighlightMock {
    static let highlights: [HSHighlight] = [
        HSHighlight(
            id: "h1",
            authorId: "f1",
            authorName: "Jordan Mitchell",
            authorInitials: "JM",
            caption: "Game winner at The Cage 🔥 They said I couldn't shoot left handed",
            likes: 1240,
            comments: 87,
            reposts: 45,
            views: 8420,
            duration: 15
        ),
        HSHighlight(
            id: "h2",
            authorId: "f4",
            authorName: "Andre \"Dre\" Washington",
            authorInitials: "AW",
            caption: "Breaking ankles all day at First Ward 😤",
            likes: 892,
            comments: 34,
            reposts: 21,
            views: 5230,
            duration: 23
        ),
        HSHighlight(
            id: "h3",
            authorId: "f2",
            authorName: "Maya Rodriguez",
            authorInitials: "MR",
            caption: "Crossover to pull-up three. Defense couldn't keep up 💯",
            likes: 2103,
            comments: 156,
            reposts: 89,
            views: 12450,
            duration: 18
        ),
        HSHighlight(
            id: "h4",
            authorId: "f6",
            authorName: "Kayla \"KJ\" Jackson",
            authorInitials: "KJ",
            caption: "Sunset sessions different. West Charlotte Park never misses 🌅",
            likes: 654,
            comments: 42,
            reposts: 18,
            views: 3890,
            duration: 30
        ),
        HSHighlight(
            id: "h5",
            authorId: "f3",
            authorName: "Marcus \"Tank\" Williams",
            authorInitials: "MW",
            caption: "Poster dunk in traffic! They had to feel that one 💪🏾",
            likes: 3421,
            comments: 289,
            reposts: 167,
            views: 18920,
            duration: 12
        ),
    ]
}
