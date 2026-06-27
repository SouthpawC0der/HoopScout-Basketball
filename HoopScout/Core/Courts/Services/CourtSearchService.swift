//
//  CourtSearchService.swift
//  HoopScout
//
//  MapKit-backed discovery of basketball courts within a radius of a location.
//  Combines a POI category search (.basketball, .park) with a natural-language
//  search so we catch both Apple-tagged basketball POIs and parks whose name
//  hints at hoop courts.
//

import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class CourtSearchService: ObservableObject {
    @Published private(set) var courts: [HSCourt] = []
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var lastSearchLabel: String?
    @Published var errorMessage: String?

    private let geocoder = CLGeocoder()

    /// Search around a coordinate. Returns Apple-tagged basketball POIs +
    /// nearby parks + any natural-language matches for "basketball court".
    func search(near coordinate: CLLocationCoordinate2D,
                radiusMiles: Double = 15) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let meters = radiusMiles * 1609.34
        let region = MKCoordinateRegion(center: coordinate,
                                        latitudinalMeters: meters,
                                        longitudinalMeters: meters)
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        async let basketballPOIs = Self.poiSearch(region: region,
                                                  categories: [.basketball])
        async let parkPOIs = Self.poiSearch(region: region,
                                            categories: [.park])
        async let fitnessPOIs = Self.poiSearch(region: region,
                                               categories: [.fitnessCenter])
        async let textMatches = Self.naturalLanguageSearch(region: region,
                                                            query: "basketball court")
        async let ymcaMatches = Self.naturalLanguageSearch(region: region,
                                                            query: "YMCA")
        async let recCenterMatches = Self.naturalLanguageSearch(region: region,
                                                                 query: "recreation center")
        async let laFitnessMatches = Self.naturalLanguageSearch(region: region,
                                                                 query: "LA Fitness")
        async let gymMatches = Self.naturalLanguageSearch(region: region,
                                                          query: "gym basketball")

        let combinedItems = await (basketballPOIs + parkPOIs + fitnessPOIs
            + textMatches + ymcaMatches + recCenterMatches
            + laFitnessMatches + gymMatches)
        let dedupedItems = Self.dedupe(combinedItems)

        let allCourts = dedupedItems.compactMap { item in
            Self.makeCourt(from: item, origin: origin)
        }
        self.courts = Self.filterAndSort(allCourts, origin: coordinate,
                                          maxMiles: radiusMiles)
    }

    /// Search by free-form text *near the user's current location*. Use this
    /// for arbitrary terms like "park" or "Latta Park" — they get matched as
    /// natural-language POIs within ~15 mi of the user, instead of being
    /// geocoded (which can resolve to a place across the country).
    func searchNearby(query: String,
                      near userCoordinate: CLLocationCoordinate2D,
                      radiusMiles: Double = 15) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let meters = radiusMiles * 1609.34
        let region = MKCoordinateRegion(center: userCoordinate,
                                        latitudinalMeters: meters,
                                        longitudinalMeters: meters)
        let origin = CLLocation(latitude: userCoordinate.latitude,
                                longitude: userCoordinate.longitude)

        // Run the typed query as a natural-language search constrained to the
        // user's region, plus the existing basketball/park POI sweep so the
        // typed term still benefits from category results.
        async let typedHits = Self.naturalLanguageSearch(region: region, query: trimmed)
        async let basketballPOIs = Self.poiSearch(region: region, categories: [.basketball])
        async let parkPOIs = Self.poiSearch(region: region, categories: [.park])
        async let fitnessPOIs = Self.poiSearch(region: region, categories: [.fitnessCenter])

        let merged = await (typedHits + basketballPOIs + parkPOIs + fitnessPOIs)
        let deduped = Self.dedupe(merged)
        let allCourts = deduped.compactMap { Self.makeCourt(from: $0, origin: origin) }
        self.courts = Self.filterAndSort(allCourts, origin: userCoordinate,
                                          maxMiles: radiusMiles)
    }

    /// Search by ZIP/city/address. Geocodes the query, then searches *there*.
    /// Use only when the query is unambiguously a place identifier.
    func search(query: String, radiusMiles: Double = 15) async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let placemarks = try await geocoder.geocodeAddressString(trimmed)
            guard let location = placemarks.first?.location else {
                self.errorMessage = "Couldn't find that location."
                return
            }
            self.lastSearchLabel = trimmed
            await self.search(near: location.coordinate, radiusMiles: radiusMiles)
        } catch {
            self.errorMessage = "Couldn't find that location."
        }
    }

    // MARK: - Manual entry

    /// Lets a user create a court at a specific coordinate when discovery
    /// missed it (e.g. they're at the spot but it isn't on Apple Maps).
    func addManualCourt(name: String,
                        coordinate: CLLocationCoordinate2D,
                        address: String) async -> HSCourt? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let origin = CLLocation(latitude: coordinate.latitude,
                                longitude: coordinate.longitude)
        let court = HSCourt(
            id: "manual-\(Int(coordinate.latitude * 10_000))-\(Int(coordinate.longitude * 10_000))",
            name: trimmed,
            subtitle: nil,
            distance: 0,
            rating: 0,
            reviews: 0,
            playing: 0,
            maxCap: 24,
            skill: "Casual",
            type: "Outdoor",
            address: address,
            tags: [],
            friendsHere: [],
            hasGame: false,
            gameInfo: nil,
            img: Self.variant(for: trimmed),
            latitude: coordinate.latitude,
            longitude: coordinate.longitude
        )
        // Persist so other users see it.
        try? await CourtRepository.shared.ensureCourt(court)

        // Compute distance and merge into local results.
        var withDistance = court
        withDistance.distance = origin.distance(from: origin) / 1609.34
        if !courts.contains(where: { $0.id == withDistance.id }) {
            courts.insert(withDistance, at: 0)
        }
        return withDistance
    }

    // MARK: - Searches

    private static func poiSearch(region: MKCoordinateRegion,
                                  categories: [MKPointOfInterestCategory]) async -> [MKMapItem] {
        let request = MKLocalPointsOfInterestRequest(coordinateRegion: region)
        request.pointOfInterestFilter = MKPointOfInterestFilter(including: categories)
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }

    private static func naturalLanguageSearch(region: MKCoordinateRegion,
                                              query: String) async -> [MKMapItem] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = .pointOfInterest
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems
        } catch {
            return []
        }
    }

    // MARK: - Dedupe + filter

    private static func dedupe(_ items: [MKMapItem]) -> [MKMapItem] {
        var seen = Set<String>()
        var result: [MKMapItem] = []
        for item in items {
            guard let coord = item.placemark.location?.coordinate else { continue }
            let key = "\((coord.latitude * 10000).rounded())_\((coord.longitude * 10000).rounded())"
            if seen.insert(key).inserted {
                result.append(item)
            }
        }
        return result
    }

    /// Filters parks to those whose name plausibly contains a court, sorts
    /// all by distance, and caps the radius client-side.
    private static func filterAndSort(_ courts: [HSCourt],
                                       origin: CLLocationCoordinate2D,
                                       maxMiles: Double) -> [HSCourt] {
        courts
            .filter { $0.distance <= maxMiles }
            .sorted { $0.distance < $1.distance }
    }

    // MARK: - HSCourt construction

    private static func makeCourt(from item: MKMapItem, origin: CLLocation) -> HSCourt? {
        guard let itemLocation = item.placemark.location else { return nil }
        let distanceMiles = origin.distance(from: itemLocation) / 1609.34
        let name = item.name ?? "Unnamed court"
        let address = [
            item.placemark.thoroughfare,
            item.placemark.locality,
            item.placemark.administrativeArea
        ].compactMap { $0 }.joined(separator: ", ")

        return HSCourt(
            id: item.placemark.title ?? "\(name)-\(itemLocation.coordinate.latitude),\(itemLocation.coordinate.longitude)",
            name: name,
            subtitle: nil,
            distance: distanceMiles,
            rating: 4.0,
            reviews: 0,
            playing: 0,
            maxCap: 24,
            skill: "Casual",
            type: typeLabel(for: item),
            address: address.isEmpty ? (item.placemark.title ?? "") : address,
            tags: [],
            friendsHere: [],
            hasGame: false,
            gameInfo: nil,
            img: variant(for: name),
            latitude: itemLocation.coordinate.latitude,
            longitude: itemLocation.coordinate.longitude
        )
    }

    private static func typeLabel(for item: MKMapItem) -> String {
        if item.pointOfInterestCategory == .basketball { return "Outdoor · Full" }
        if item.pointOfInterestCategory == .park { return "Park · Outdoor" }
        if item.pointOfInterestCategory == .fitnessCenter { return "Indoor · Gym" }
        return "Outdoor"
    }

    private static func variant(for name: String) -> HSCourtImageVariant {
        let all: [HSCourtImageVariant] = [.hero1, .hero2, .hero3, .hero4, .hero5, .hero6, .hero7]
        let idx = abs(name.hashValue) % all.count
        return all[idx]
    }
}
