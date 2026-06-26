//
//  UserRepository.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

final class UserRepository {
    static let shared = UserRepository()
    private init() {}

    private var collection: CollectionReference {
        Firestore.firestore().collection("users")
    }

    func create(_ profile: HSUserProfile) async throws {
        guard let id = profile.id else { throw NSError(domain: "UserRepository", code: 1) }
        try collection.document(id).setData(from: profile, merge: true)
    }

    func fetch(uid: String) async throws -> HSUserProfile? {
        let snap = try await collection.document(uid).getDocument()
        guard snap.exists else { return nil }
        return try snap.data(as: HSUserProfile.self)
    }

    func update(_ profile: HSUserProfile) async throws {
        guard let id = profile.id else { throw NSError(domain: "UserRepository", code: 1) }
        try collection.document(id).setData(from: profile, merge: true)
    }

    func setFCMToken(_ token: String, uid: String) async throws {
        try await collection.document(uid).setData(["fcmToken": token], merge: true)
    }
}
