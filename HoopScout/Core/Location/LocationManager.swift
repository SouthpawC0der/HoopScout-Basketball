//
//  LocationManager.swift
//  HoopScout
//

import Foundation
import Combine
import CoreLocation

@MainActor
final class LocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?
    @Published private(set) var lastError: Error?
    @Published private(set) var lastVisit: CLVisit?
    /// Reverse-geocoded "City, ST" of `location`. Updated as the user moves
    /// more than ~1 km from the last geocoded fix.
    @Published private(set) var cityLabel: String?

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodedLocation: CLLocation?

    static let autoDetectKey = "hs_auto_detect_enabled"

    override init() {
        self.authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50

        // Resume visit monitoring across launches if the user has opted in.
        if UserDefaults.standard.bool(forKey: Self.autoDetectKey) {
            manager.startMonitoringVisits()
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }

    func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    func startUpdates() {
        manager.startUpdatingLocation()
    }

    func stopUpdates() {
        manager.stopUpdatingLocation()
    }

    func enableVisitMonitoring() {
        UserDefaults.standard.set(true, forKey: Self.autoDetectKey)
        manager.startMonitoringVisits()
    }

    func disableVisitMonitoring() {
        UserDefaults.standard.set(false, forKey: Self.autoDetectKey)
        manager.stopMonitoringVisits()
    }

    fileprivate func updateCityLabelIfNeeded(for loc: CLLocation) {
        if let last = lastGeocodedLocation, loc.distance(from: last) < 1000 { return }
        lastGeocodedLocation = loc
        Task { [weak self] in
            guard let self else { return }
            if let placemark = try? await self.geocoder.reverseGeocodeLocation(loc).first {
                let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                let state = placemark.administrativeArea ?? ""
                let label: String
                if !city.isEmpty && !state.isEmpty {
                    label = "\(city), \(state)"
                } else if !city.isEmpty {
                    label = city
                } else {
                    label = state
                }
                if !label.isEmpty {
                    await MainActor.run { self.cityLabel = label }
                }
            }
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.location = loc
            self.updateCityLabelIfNeeded(for: loc)
            // Drive the dwell detector from here so auto-detect works on every
            // screen, not just CourtsView (which only feeds it while visible).
            CheckInService.shared.handleForegroundLocation(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in self.lastError = error }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.startUpdatingLocation()
            }
            if status == .authorizedAlways,
               UserDefaults.standard.bool(forKey: Self.autoDetectKey) {
                manager.startMonitoringVisits()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        Task { @MainActor in
            self.lastVisit = visit
            CheckInService.shared.handleVisit(visit)
        }
    }
}
