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

    /// Submit (or update) the caller's rating for a court. Updates a rolling
    /// average on the court doc atomically with the rating doc.
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

    /// Submit a rating for another user, with an optional comment.
    func rateUser(ratedUid: String,
                  raterUid: String,
                  raterName: String?,
                  stars: Int,
                  comment: String?,
                  courtId: String?) async throws {
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
