//
//  NavigationLauncher.swift
//  HoopScout
//
//  Helpers for launching the user's preferred navigation app
//  (Apple Maps / Google Maps / Waze) with a destination.
//

import UIKit
import CoreLocation

enum NavigationApp: String, CaseIterable, Identifiable {
    case appleMaps  = "Apple Maps"
    case googleMaps = "Google Maps"
    case waze       = "Waze"

    var id: String { rawValue }

    /// Probe URL used with `canOpenURL` to detect if the app is installed.
    /// (Requires the scheme to be in `LSApplicationQueriesSchemes` in Info.plist.)
    var probeURL: URL? {
        switch self {
        case .appleMaps:  return URL(string: "maps://")
        case .googleMaps: return URL(string: "comgooglemaps://")
        case .waze:       return URL(string: "waze://")
        }
    }

    /// Build a "navigate to" URL for the chosen app.
    func directionsURL(daddr address: String,
                       coordinate: CLLocationCoordinate2D?) -> URL? {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""

        switch self {
        case .appleMaps:
            // Apple Maps universal link works whether or not the app is installed.
            if let coord = coordinate {
                return URL(string: "http://maps.apple.com/?daddr=\(coord.latitude),\(coord.longitude)&q=\(encoded)")
            }
            return URL(string: "http://maps.apple.com/?daddr=\(encoded)")
        case .googleMaps:
            if let coord = coordinate {
                return URL(string: "comgooglemaps://?daddr=\(coord.latitude),\(coord.longitude)&directionsmode=driving")
            }
            return URL(string: "comgooglemaps://?daddr=\(encoded)&directionsmode=driving")
        case .waze:
            if let coord = coordinate {
                return URL(string: "waze://?ll=\(coord.latitude),\(coord.longitude)&navigate=yes")
            }
            return URL(string: "waze://?q=\(encoded)&navigate=yes")
        }
    }
}

@MainActor
enum NavigationLauncher {
    /// Apps that can actually be opened on this device.
    /// Apple Maps is always considered available (universal link works regardless).
    static func installedApps() -> [NavigationApp] {
        NavigationApp.allCases.filter { app in
            if app == .appleMaps { return true }
            guard let url = app.probeURL else { return false }
            return UIApplication.shared.canOpenURL(url)
        }
    }

    static func open(_ app: NavigationApp, for court: HSCourt) {
        let coord: CLLocationCoordinate2D? = {
            if let lat = court.latitude, let lon = court.longitude {
                return CLLocationCoordinate2D(latitude: lat, longitude: lon)
            }
            return nil
        }()
        let address = court.address.isEmpty ? court.name : court.address
        guard let url = app.directionsURL(daddr: address, coordinate: coord) else { return }
        UIApplication.shared.open(url)
    }
}
