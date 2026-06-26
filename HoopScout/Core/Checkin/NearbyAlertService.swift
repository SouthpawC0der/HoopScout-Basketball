//
//  NearbyAlertService.swift
//  HoopScout
//
//  Watches live counts for courts within a small radius of the user and fires
//  a local notification when any such court has 2+ hoopers playing — once per
//  court per app session, so users don't get repeatedly pinged about the same
//  spot.
//

import Foundation
import CoreLocation
import UserNotifications

@MainActor
final class NearbyAlertService {
    static let shared = NearbyAlertService()

    private var notifiedCourtIds: Set<String> = []
    var thresholdHoopers: Int = 2
    var radiusMiles: Double = 5

    private init() {}

    /// Call when the visible court list + live counts update. The service
    /// figures out which nearby courts cross the threshold and notifies.
    func evaluate(courts: [HSCourt],
                  liveCounts: [String: Int],
                  userLocation: CLLocation?,
                  courtRepo: CourtRepository) {
        guard let userLocation else { return }
        for court in courts {
            guard let lat = court.latitude, let lon = court.longitude else { continue }
            let courtLoc = CLLocation(latitude: lat, longitude: lon)
            let miles = userLocation.distance(from: courtLoc) / 1609.34
            guard miles <= radiusMiles else { continue }

            let id = courtRepo.stableId(for: court)
            guard let count = liveCounts[id], count >= thresholdHoopers else { continue }
            guard !notifiedCourtIds.contains(id) else { continue }

            notifiedCourtIds.insert(id)
            Task { await self.fire(court: court, count: count, courtId: id) }
        }
    }

    func reset() {
        notifiedCourtIds.removeAll()
    }

    private func fire(court: HSCourt, count: Int, courtId: String) async {
        let content = UNMutableNotificationContent()
        content.title = "🏀 \(count) hoopers playing nearby"
        content.body = "\(court.name) has a run going. Pull up?"
        content.sound = .default
        content.userInfo = [
            "type": "nearby_court",
            "courtId": courtId,
            "courtName": court.name
        ]
        let req = UNNotificationRequest(
            identifier: "nearby-\(courtId)-\(Int(Date().timeIntervalSince1970))",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        try? await UNUserNotificationCenter.current().add(req)

        await NotificationRepository.shared.add(NotificationPayload(
            type: "nearby_court",
            title: "\(count) hoopers at \(court.name)",
            body: "There's an active run nearby. Tap to see the court.",
            courtId: courtId,
            courtName: court.name
        ))
    }
}
