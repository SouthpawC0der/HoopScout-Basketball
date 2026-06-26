//
//  CourtLiveCountStore.swift
//  HoopScout
//
//  Live data for each visible court: who's currently checked in (active
//  check-ins, not the cached `playingCount` field — that goes stale when
//  users close the app without checking out), plus the live rating average
//  and rating count from the court doc itself.
//

import Foundation
import Combine
import FirebaseFirestore

struct CourtLiveRating: Equatable {
    let average: Double
    let count: Int
}

@MainActor
final class CourtLiveCountStore: ObservableObject {
    @Published private(set) var counts: [String: Int] = [:]
    @Published private(set) var ratings: [String: CourtLiveRating] = [:]

    private var checkInListeners: [String: ListenerRegistration] = [:]
    private var courtListeners: [String: ListenerRegistration] = [:]
    private let db = Firestore.firestore()

    func subscribe(courtIds: Set<String>) {
        // Detach listeners for courts no longer visible.
        for id in checkInListeners.keys where !courtIds.contains(id) {
            checkInListeners[id]?.remove()
            checkInListeners.removeValue(forKey: id)
            counts.removeValue(forKey: id)
        }
        for id in courtListeners.keys where !courtIds.contains(id) {
            courtListeners[id]?.remove()
            courtListeners.removeValue(forKey: id)
            ratings.removeValue(forKey: id)
        }

        // Attach listeners for newly-visible courts.
        for id in courtIds where checkInListeners[id] == nil {
            checkInListeners[id] = db.collection("courts").document(id)
                .collection("checkIns")
                .whereField("expiresAt", isGreaterThan: Timestamp(date: Date()))
                .addSnapshotListener { [weak self] snap, _ in
                    let count = snap?.documents.count ?? 0
                    Task { @MainActor in
                        guard let self else { return }
                        self.counts[id] = count
                    }
                }
        }
        for id in courtIds where courtListeners[id] == nil {
            courtListeners[id] = db.collection("courts").document(id)
                .addSnapshotListener { [weak self] snap, _ in
                    guard let data = snap?.data() else { return }
                    let average = (data["ratingAverage"] as? Double) ?? 0
                    let count = (data["ratingCount"] as? Int) ?? 0
                    Task { @MainActor in
                        guard let self else { return }
                        if count > 0 {
                            self.ratings[id] = CourtLiveRating(average: average, count: count)
                        }
                    }
                }
        }
    }

    func stopAll() {
        checkInListeners.values.forEach { $0.remove() }
        courtListeners.values.forEach { $0.remove() }
        checkInListeners.removeAll()
        courtListeners.removeAll()
        counts.removeAll()
        ratings.removeAll()
    }

    deinit {
        checkInListeners.values.forEach { $0.remove() }
        courtListeners.values.forEach { $0.remove() }
    }
}
