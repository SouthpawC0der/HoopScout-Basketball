//
//  CourtRepository.swift
//  HoopScout
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class CourtRepository: ObservableObject {
    static let shared = CourtRepository()

    private var db: Firestore { Firestore.firestore() }

    private var courts: CollectionReference {
        db.collection("courts")
    }

    // MARK: - IDs

    /// Stable Firestore doc ID derived from name + rounded lat/lon so different
    /// users who discover the same court hit the same document.
    func stableId(for court: HSCourt) -> String {
        if court.id.hasPrefix("c") && court.id.count <= 3 {
            return court.id // mock seed courts keep their original IDs
        }
        guard let lat = court.latitude, let lon = court.longitude else {
            return court.id
        }
        let slug = court.name.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        let latPart = Int((lat * 10000).rounded())
        let lonPart = Int((lon * 10000).rounded())
        return "\(slug)_\(latPart)_\(lonPart)"
    }

    // MARK: - Upsert

    func ensureCourt(_ court: HSCourt) async throws {
        guard let lat = court.latitude, let lon = court.longitude else { return }
        let id = stableId(for: court)
        try await courts.document(id).setData([
            "name": court.name,
            "address": court.address,
            "lat": lat,
            "lon": lon,
            "maxCap": court.maxCap,
            "skill": court.skill,
            "type": court.type
        ], merge: true)
    }

    // MARK: - Photo

    /// Writes a user-uploaded photo URL onto the court doc. Last write wins —
    /// abuse is handled by the report flow, not write contention.
    func setPhotoURL(courtId: String, url: String, uploaderUID: String) async throws {
        try await courts.document(courtId).setData([
            "photoURL": url,
            "photoUploaderUID": uploaderUID,
            "photoUpdatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Check-in / Check-out (atomic)

    func checkIn(profile: HSUserProfile, at court: HSCourt) async throws {
        try await ensureCourt(court)
        let courtId = stableId(for: court)
        guard let uid = profile.id else {
            throw NSError(domain: "CourtRepository", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Missing user id"])
        }
        let expiresAt = Date().addingTimeInterval(2 * 60 * 60) // 2h

        let db = self.db
        _ = try await db.runTransaction({ tx, errorPointer -> Any? in
            let userRef = db.collection("users").document(uid)

            // 1. If user already had a check-in elsewhere, decrement that court + remove subdoc.
            do {
                let userSnap = try tx.getDocument(userRef)
                if let existing = userSnap.data()?["activeCheckIn"] as? [String: Any],
                   let oldCourtId = existing["courtId"] as? String,
                   oldCourtId != courtId {
                    let oldCourtRef = db.collection("courts").document(oldCourtId)
                    tx.updateData([
                        "playingCount": FieldValue.increment(Int64(-1)),
                        "updatedAt": FieldValue.serverTimestamp()
                    ], forDocument: oldCourtRef)
                    let oldCheckInRef = oldCourtRef.collection("checkIns").document(uid)
                    tx.deleteDocument(oldCheckInRef)
                }
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
                return nil
            }

            // 2. Write new check-in doc.
            let courtRef = db.collection("courts").document(courtId)
            let checkInRef = courtRef.collection("checkIns").document(uid)
            tx.setData([
                "uid": uid,
                "displayName": profile.name,
                "initials": profile.initials,
                "checkedInAt": FieldValue.serverTimestamp(),
                "expiresAt": Timestamp(date: expiresAt)
            ], forDocument: checkInRef)

            // 3. Increment court playingCount.
            tx.setData([
                "playingCount": FieldValue.increment(Int64(1)),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: courtRef, merge: true)

            // 4. Mirror onto user doc.
            tx.setData([
                "activeCheckIn": [
                    "courtId": courtId,
                    "name": court.name,
                    "checkedInAt": FieldValue.serverTimestamp(),
                    "expiresAt": Timestamp(date: expiresAt)
                ]
            ], forDocument: userRef, merge: true)

            return nil
        })
    }

    func checkOut(uid: String) async throws {
        let db = self.db
        _ = try await db.runTransaction({ tx, errorPointer -> Any? in
            let userRef = db.collection("users").document(uid)
            do {
                let userSnap = try tx.getDocument(userRef)
                guard let checkIn = userSnap.data()?["activeCheckIn"] as? [String: Any],
                      let courtId = checkIn["courtId"] as? String else { return nil }

                let courtRef = db.collection("courts").document(courtId)
                let checkInRef = courtRef.collection("checkIns").document(uid)

                tx.deleteDocument(checkInRef)
                tx.updateData([
                    "playingCount": FieldValue.increment(Int64(-1)),
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: courtRef)
                tx.updateData(["activeCheckIn": FieldValue.delete()], forDocument: userRef)
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
            }
            return nil
        })
    }

    // MARK: - Observe

    /// Live snapshots of a single court doc.
    func observeCourt(id: String) -> AsyncStream<HSCourtDoc?> {
        AsyncStream { continuation in
            let listener = courts.document(id).addSnapshotListener { snap, _ in
                guard let snap, snap.exists else { continuation.yield(nil); return }
                let doc = try? snap.data(as: HSCourtDoc.self)
                continuation.yield(doc)
            }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// Live snapshots of a court's active check-ins.
    /// Bounded server-side by `expiresAt > now` and a hard cap on docs returned.
    func observeCheckIns(courtId: String, limit: Int = 100) -> AsyncStream<[HSCheckInDoc]> {
        AsyncStream { continuation in
            let listener = courts.document(courtId).collection("checkIns")
                .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
                .limit(to: limit)
                .addSnapshotListener { snap, _ in
                    guard let snap else { continuation.yield([]); return }
                    let docs: [HSCheckInDoc] = snap.documents.compactMap {
                        try? $0.data(as: HSCheckInDoc.self)
                    }.filter { $0.isActive }
                    continuation.yield(docs)
                }
            continuation.onTermination = { _ in listener.remove() }
        }
    }

    /// One-shot fetch of the playingCount field for many courts (best-effort).
    func fetchPlayingCounts(courtIds: [String]) async -> [String: Int] {
        var result: [String: Int] = [:]
        await withTaskGroup(of: (String, Int?).self) { group in
            for id in courtIds {
                group.addTask { [weak self] in
                    guard let self else { return (id, nil) }
                    let snap = try? await self.courts.document(id).getDocument()
                    let count = snap?.data()?["playingCount"] as? Int
                    return (id, count)
                }
            }
            for await (id, count) in group {
                if let count { result[id] = count }
            }
        }
        return result
    }
}
