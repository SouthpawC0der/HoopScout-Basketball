//
//  HSArticle.swift
//  HoopScout
//
//  Local articles published by gym accounts. Surfaced in the News tab of
//  the Feed alongside ESPN-sourced national headlines. Authored only by
//  accounts whose user doc has accountKind == "gym".
//

import Foundation

struct HSArticle: Identifiable, Hashable {
    let id: String
    let authorId: String
    let authorName: String
    let title: String
    let body: String
    let url: URL?
    let createdAt: Date

    init(id: String = UUID().uuidString,
         authorId: String,
         authorName: String,
         title: String,
         body: String,
         url: URL? = nil,
         createdAt: Date = Date()) {
        self.id = id
        self.authorId = authorId
        self.authorName = authorName
        self.title = title
        self.body = body
        self.url = url
        self.createdAt = createdAt
    }
}
