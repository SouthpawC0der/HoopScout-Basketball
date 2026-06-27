//
//  RatingRepository.swift
//  HoopScout
//

import Foundation
import FirebaseFirestore

@MainActor
final class RatingRepository {
    static let shared = RatingRepository()
    private init() {}

    private var db: Firestore { Firestore.firestore() }

    // MARK: - Courts

    /// Submit (or update) the caller's rating for a court. The court doc must
    /// exist before the transaction runs (otherwise setData(merge:true) would
    /// attempt to *create* it and fail the create rule). Pass a full HSCourt
    /// whenever possible so we can ensureCourt up front.
    func rateCourt(court: HSCourt, raterUid: String, stars: Int) async throws {
        try await CourtRepository.shared.ensureCourt(court)
        let courtId = CourtRepository.shared.stableId(for: court)
        try await rateCourt(courtId: courtId, raterUid: raterUid, stars: stars)
    }

    /// Lower-level path used when only the courtId is known (e.g. when a
    /// notification deep-links into the rating sheet after the check-in
    /// already ensured the court doc exists).
    func rateCourt(courtId: String, raterUid: String, stars: Int) async throws {
        let clamped = max(1, min(5, stars))
        let courtRef = db.collection("courts").document(courtId)
        let ratingRef = courtRef.collection("ratings").document(raterUid)

        _ = try await db.runTransaction({ tx, errorPointer -> Any? in
            do {
                let courtSnap = try tx.getDocument(courtRef)
                let prior = try? tx.getDocument(ratingRef)

                let oldAvg = (courtSnap.data()?["ratingAverage"] as? Double) ?? 0
                let oldCount = (courtSnap.data()?["ratingCount"] as? Int) ?? 0
                let priorStars = (prior?.data()?["stars"] as? Int)

                let newCount: Int
                let newAvg: Double
                if let priorStars {
                    newCount = oldCount
                    let total = oldAvg * Double(oldCount) - Double(priorStars) + Double(clamped)
                    newAvg = newCount > 0 ? total / Double(newCount) : 0
                } else {
                    newCount = oldCount + 1
                    let total = oldAvg * Double(oldCount) + Double(clamped)
                    newAvg = total / Double(newCount)
                }

                tx.setData([
                    "courtId": courtId,
                    "raterUid": raterUid,
                    "stars": clamped,
                    "createdAt": FieldValue.serverTimestamp()
                ], forDocument: ratingRef, merge: true)

                tx.setData([
                    "ratingAverage": newAvg,
                    "ratingCount": newCount,
                    "updatedAt": FieldValue.serverTimestamp()
                ], forDocument: courtRef, merge: true)
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
                return nil
            }
            return nil
        })
    }

    // MARK: - Users

    /// Submit a rating for another user across four categories. The overall
    /// `stars` value is the rounded average of the four. Optional comment +
    /// court reference are persisted as-is.
    func rateUser(ratedUid: String,
                  raterUid: String,
                  raterName: String?,
                  ballHandling: Int,
                  basketballIQ: Int,
                  teamPlay: Int,
                  toughness: Int,
                  comment: String?,
                  courtId: String?) async throws {
        let bh = max(1, min(5, ballHandling))
        let iq = max(1, min(5, basketballIQ))
        let tp = max(1, min(5, teamPlay))
        let tg = max(1, min(5, toughness))
        let stars = Int((Double(bh + iq + tp + tg) / 4.0).rounded())
        let clamped = max(1, min(5, stars))
        let userRef = db.collection("users").document(ratedUid)
        // One rating doc per rater, per rated user — repeat ratings overwrite.
        let ratingRef = userRef.collection("ratings").document(raterUid)

        _ = try await db.runTransaction({ tx, errorPointer -> Any? in
            do {
                let userSnap = try tx.getDocument(userRef)
                let prior = try? tx.getDocument(ratingRef)

                let oldAvg = (userSnap.data()?["ratingAverage"] as? Double) ?? 0
                let oldCount = (userSnap.data()?["ratingCount"] as? Int) ?? 0
                let priorStars = (prior?.data()?["stars"] as? Int)

                let newCount: Int
                let newAvg: Double
                if let priorStars {
                    newCount = oldCount
                    let total = oldAvg * Double(oldCount) - Double(priorStars) + Double(clamped)
                    newAvg = newCount > 0 ? total / Double(newCount) : 0
                } else {
                    newCount = oldCount + 1
                    let total = oldAvg * Double(oldCount) + Double(clamped)
                    newAvg = total / Double(newCount)
                }

                var data: [String: Any] = [
                    "ratedUid": ratedUid,
                    "raterUid": raterUid,
                    "stars": clamped,
                    "ballHandling": bh,
                    "basketballIQ": iq,
                    "teamPlay": tp,
                    "toughness": tg,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                if let raterName { data["raterName"] = raterName }
                if let comment, !comment.isEmpty { data["comment"] = comment }
                if let courtId { data["courtId"] = courtId }

                tx.setData(data, forDocument: ratingRef, merge: true)

                tx.setData([
                    "ratingAverage": newAvg,
                    "ratingCount": newCount
                ], forDocument: userRef, merge: true)
            } catch let nsError as NSError {
                errorPointer?.pointee = nsError
                return nil
            }
            return nil
        })
    }
}
