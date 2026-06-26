//
//  PlayerOfWeekService.swift
//  HoopScout
//
//  Computes the Home tab's "Player of the Week" from real Firestore data.
//
//  Scoped per-city: only runs/users that live in the viewer's city or town are
//  considered, so each area gets its own winner. The viewer's city comes from
//  their profile's `location` field, falling back to a reverse-geocoded label
//  from LocationManager when the profile location is empty.
//
//  Primary metric: a collection-group query over the last 7 days of `runs`,
//  filtered to candidate users in the same city. The user with the most
//  check-ins wins; ties are broken by distinct courts.
//
//  Fallback (when there are no recent runs in the city, or the collection-
//  group index is missing): the highest-rated user in the same city.
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class PlayerOfWeekService: ObservableObject {
    @Published private(set) var player: HSHomePlayerOfWeek?
    @Published private(set) var profile: HSUserProfile?
    @Published private(set) var isLoading: Bool = false
    /// Normalized city the current result was computed for. When the viewer
    /// moves to a new city we re-run the query.
    @Published private(set) var loadedCityKey: String?
    /// Pretty label of the city the result represents (e.g. "Brooklyn, NY").
    @Published private(set) var cityLabel: String?

    private var db: Firestore { Firestore.firestore() }

    func loadIfNeeded(city: String?) async {
        let key = Self.cityKey(from: city)
        if player != nil, loadedCityKey == key { return }
        await load(city: city)
    }

    func load(city: String?) async {
        isLoading = true
        defer { isLoading = false }

        let cityKey = Self.cityKey(from: city)
        loadedCityKey = cityKey
        cityLabel = (city?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap {
            $0.isEmpty ? nil : $0
        }

        guard let cityKey else {
            player = nil
            profile = nil
            return
        }

        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoff = Timestamp(date: weekAgo)

        // Cache user-profile lookups so we don't refetch the same doc once per
        // run document in the snapshot.
        var profileCache: [String: HSUserProfile?] = [:]
        func profileFor(uid: String) async -> HSUserProfile? {
            if let cached = profileCache[uid] { return cached }
            let fetched = try? await UserRepository.shared.fetch(uid: uid)
            profileCache[uid] = fetched
            return fetched
        }

        var topUid: String?
        var topRunCount = 0
        var topCourts: Set<String> = []

        if let snap = try? await db.collectionGroup("runs")
            .whereField("createdAt", isGreaterThan: cutoff)
            .getDocuments() {

            var perUser: [String: (count: Int, courts: Set<String>)] = [:]
            for doc in snap.documents {
                guard let uid = doc.reference.parent.parent?.documentID else { continue }
                let courtId = (doc.data()["courtId"] as? String) ?? ""
                var entry = perUser[uid] ?? (0, [])
                entry.count += 1
                if !courtId.isEmpty { entry.courts.insert(courtId) }
                perUser[uid] = entry
            }

            // Restrict to users whose profile location matches the viewer's city.
            var localCandidates: [(uid: String, count: Int, courts: Set<String>)] = []
            for (uid, value) in perUser {
                guard let p = await profileFor(uid: uid),
                      Self.cityKey(from: p.location) == cityKey else { continue }
                localCandidates.append((uid, value.count, value.courts))
            }

            if let top = localCandidates.max(by: { lhs, rhs in
                if lhs.count != rhs.count { return lhs.count < rhs.count }
                return lhs.courts.count < rhs.courts.count
            }) {
                topUid = top.uid
                topRunCount = top.count
                topCourts = top.courts
            }
        }

        var chosen: HSUserProfile?
        var recap: String

        if let uid = topUid, let p = await profileFor(uid: uid) {
            chosen = p
            let courtLabel = topCourts.count == 1 ? "court" : "courts"
            recap = "Logged \(topRunCount) run\(topRunCount == 1 ? "" : "s") across \(topCourts.count) \(courtLabel) in the last 7 days."
        } else {
            // Fallback: top-rated user in the same city. Firestore can't filter
            // by a normalized key, so we pull a page ordered by rating and
            // filter client-side.
            let snap = try? await db.collection("users")
                .order(by: "ratingAverage", descending: true)
                .limit(to: 50)
                .getDocuments()
            chosen = snap?.documents
                .compactMap { try? $0.data(as: HSUserProfile.self) }
                .first { Self.cityKey(from: $0.location) == cityKey }
            recap = "Highest-rated hooper in \(cityLabel ?? "your area") right now."
            topRunCount = chosen?.runs ?? 0
            topCourts = []
        }

        guard let p = chosen else {
            player = nil
            profile = nil
            return
        }

        let ratingLabel: String
        if let avg = p.ratingAverage, (p.ratingCount ?? 0) > 0 {
            ratingLabel = String(format: "%.1f", avg)
        } else {
            ratingLabel = "—"
        }

        let week = Calendar.current.component(.weekOfYear, from: Date())
        let displayHandle = p.handle.hasPrefix("@") ? p.handle : "@\(p.handle)"

        self.profile = p
        self.player = HSHomePlayerOfWeek(
            uid: p.id ?? "",
            name: p.name,
            handle: displayHandle,
            initials: p.initials,
            weekNumber: week,
            recap: recap,
            runs: "\(topRunCount)",
            rating: ratingLabel,
            courts: "\(topCourts.count)"
        )
    }

    /// Lowercased, trimmed city name (everything before the first comma) used
    /// to group users by area. Returns nil for empty / whitespace strings.
    static func cityKey(from raw: String?) -> String? {
        guard let raw else { return nil }
        let head = raw.split(separator: ",", maxSplits: 1).first.map(String.init) ?? raw
        let trimmed = head.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
