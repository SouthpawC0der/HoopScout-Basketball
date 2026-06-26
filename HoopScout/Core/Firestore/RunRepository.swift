//
//  RunRepository.swift
//  HoopScout
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class RunRepository: ObservableObject {
    static let shared = RunRepository()
    private init() {}

    private var db: Firestore { Firestore.firestore() }

    /// Records a completed run and bumps the user's `runs` counter.
    func add(uid: String, run: HSRunDoc) async throws {
        let runsRef = db.collection("users").document(uid).collection("runs")
        let userRef = db.collection("users").document(uid)

        let docRef = runsRef.document()
        var data: [String: Any] = [
            "courtId": run.courtId,
            "courtName": run.courtName,
            "durationMinutes": run.durationMinutes,
            "rated": run.rated,
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let started = run.startedAt { data["startedAt"] = Timestamp(date: started) }
        if let ended = run.endedAt { data["endedAt"] = Timestamp(date: ended) }
        data["coPlayers"] = run.coPlayers.map { [
            "uid": $0.uid, "name": $0.name, "initials": $0.initials
        ] }

        try await docRef.setData(data)
        try await userRef.setData(["runs": FieldValue.increment(Int64(1))], merge: true)
    }

    /// Live stream of the user's most recent runs.
    func observe(uid: String, limit: Int = 100) -> AsyncStream<[HSRunDoc]> {
        AsyncStream { continuation in
            let listener = db.collection("users").document(uid)
                .collection("runs")
                .order(by: "endedAt", descending: true)
                .limit(to: limit)
                .addSnapshotListener { snap, _ in
                    let docs: [HSRunDoc] = snap?.documents.compactMap {
                        try? $0.data(as: HSRunDoc.self)
                    } ?? []
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }
}
