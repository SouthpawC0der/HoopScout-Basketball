//
//  CourtCache.swift
//  HoopScout
//
//  UserDefaults snapshot of courts the user has seen, used so background
//  CLVisit callbacks can match a coordinate to a court without needing
//  the foreground search service to be alive.
//

import Foundation

@MainActor
final class CourtCache {
    static let shared = CourtCache()
    private let key = "hs_court_cache_v1"

    func save(_ courts: [HSCourt]) {
        let payload: [[String: Any]] = courts.compactMap { c in
            guard let lat = c.latitude, let lon = c.longitude else { return nil }
            return [
                "id": c.id,
                "name": c.name,
                "address": c.address,
                "lat": lat,
                "lon": lon,
                "maxCap": c.maxCap,
                "img": c.img.rawValue
            ]
        }
        UserDefaults.standard.set(payload, forKey: key)
    }

    func load() -> [HSCourt] {
        let raw = (UserDefaults.standard.array(forKey: key) as? [[String: Any]]) ?? []
        return raw.compactMap { dict in
            guard let id = dict["id"] as? String,
                  let name = dict["name"] as? String,
                  let lat = dict["lat"] as? Double,
                  let lon = dict["lon"] as? Double else { return nil }
            return HSCourt(
                id: id,
                name: name,
                subtitle: nil,
                distance: 0,
                rating: 0,
                reviews: 0,
                playing: 0,
                maxCap: (dict["maxCap"] as? Int) ?? 24,
                skill: "Casual",
                type: "",
                address: (dict["address"] as? String) ?? "",
                tags: [],
                friendsHere: [],
                hasGame: false,
                gameInfo: nil,
                img: HSCourtImageVariant(rawValue: (dict["img"] as? String) ?? "hero1") ?? .hero1,
                latitude: lat,
                longitude: lon
            )
        }
    }

    /// Mock seed courts merged with anything the user has discovered via search.
    func allKnownCourts() -> [HSCourt] {
        let mock = HSMockData.courts
        let cached = load()
        let mockIds = Set(mock.map { $0.id })
        return mock + cached.filter { !mockIds.contains($0.id) }
    }
}
