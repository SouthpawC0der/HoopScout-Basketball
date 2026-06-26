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

    private let manager = CLLocationManager()

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
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in self.location = loc }
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
