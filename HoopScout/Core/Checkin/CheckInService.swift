//
//  CheckInService.swift
//  HoopScout
//

import Foundation
import Combine
import CoreLocation
import UserNotifications
import FirebaseAuth

@MainActor
final class CheckInService: ObservableObject {
    static let shared = CheckInService()

    @Published private(set) var suggestion: HSCourt?
    @Published private(set) var checkedInCourt: HSCourt?
    @Published var lastError: String?

    /// Set when a rating notification (court or user) is tapped so the UI can
    /// surface the rating sheet. Consumers clear after presenting.
    @Published var pendingRatingPrompt: RatingPrompt?

    var proximityMeters: CLLocationDistance = 80
    var dwellSeconds: TimeInterval = 5 * 60
    var exitMeters: CLLocationDistance = 200
    var visitProximityMeters: CLLocationDistance = 150

    private let courtRepo: CourtRepository
    private var firstSeenAt: [String: Date] = [:]
    private var dismissedCourtIds: Set<String> = []
    private var visitTaskInFlight: Bool = false

    /// Snapshot of unique co-players (uid → display info) seen during the
    /// current check-in, used at checkout to prompt for ratings.
    private var coPlayers: [String: CoPlayer] = [:]
    private var coPlayersObserveTask: Task<Void, Never>?

    private init() {
        self.courtRepo = .shared
    }

    // MARK: - Foreground proximity (Path B)

    func handle(location: CLLocation, courts: [HSCourt]) {
        let candidates = courts.compactMap { court -> (HSCourt, CLLocationDistance)? in
            guard let lat = court.latitude, let lon = court.longitude else { return nil }
            let cl = CLLocation(latitude: lat, longitude: lon)
            return (court, location.distance(from: cl))
        }

        if let checkedIn = checkedInCourt,
           let pair = candidates.first(where: { $0.0.id == checkedIn.id }),
           pair.1 > exitMeters {
            Task { await self.autoCheckOut() }
        }

        guard let (nearest, distance) = candidates.min(by: { $0.1 < $1.1 }),
              distance <= proximityMeters else {
            firstSeenAt.removeAll()
            if suggestion != nil { suggestion = nil }
            return
        }

        if firstSeenAt[nearest.id] == nil {
            firstSeenAt = [nearest.id: Date()]
        }
        if checkedInCourt?.id == nearest.id { return }
        if dismissedCourtIds.contains(nearest.id) { return }

        if let arrived = firstSeenAt[nearest.id],
           Date().timeIntervalSince(arrived) >= dwellSeconds {
            if suggestion?.id != nearest.id { suggestion = nearest }
        }
    }

    // MARK: - Background visits (Path A)

    func handleVisit(_ visit: CLVisit) {
        // Opt-in only.
        guard UserDefaults.standard.bool(forKey: LocationManager.autoDetectKey) else { return }
        guard !visitTaskInFlight else { return }
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let visitLocation = CLLocation(latitude: visit.coordinate.latitude,
                                       longitude: visit.coordinate.longitude)
        let courts = CourtCache.shared.allKnownCourts()
        let candidates = courts.compactMap { court -> (HSCourt, CLLocationDistance)? in
            guard let lat = court.latitude, let lon = court.longitude else { return nil }
            return (court, visitLocation.distance(from:
                CLLocation(latitude: lat, longitude: lon)))
        }
        guard let (court, distance) = candidates.min(by: { $0.1 < $1.1 }),
              distance < visitProximityMeters else { return }

        // CLVisit sets departureDate to distantFuture during arrival;
        // a real timestamp on departure.
        let now = Date()
        let isArrival = visit.departureDate.timeIntervalSince(now) > 60 * 60 * 24 * 365

        visitTaskInFlight = true
        Task {
            defer { Task { @MainActor in self.visitTaskInFlight = false } }
            if isArrival {
                guard let profile = try? await UserRepository.shared.fetch(uid: uid) else { return }
                self.checkedInCourt = court
                self.startTrackingCoPlayers(at: court, selfUid: uid)
                try? await self.courtRepo.checkIn(profile: profile, at: court)
                await self.postArrivalNotification(for: court)
            } else if self.checkedInCourt?.id == court.id {
                let leaving = self.checkedInCourt
                let coPlayersAtExit = self.coPlayers
                self.checkedInCourt = nil
                self.stopTrackingCoPlayers()
                try? await self.courtRepo.checkOut(uid: uid)
                if let leaving {
                    await self.postDepartureNotifications(for: leaving, coPlayers: coPlayersAtExit)
                }
            }
        }
    }

    private func postArrivalNotification(for court: HSCourt) async {
        let content = UNMutableNotificationContent()
        content.title = "Checked in at \(court.name)"
        content.body = "You're counted in the live total. Open the app to check out."
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "checkin-\(court.id)",
            content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Manual

    func confirmSuggestion(as profile: HSUserProfile?) async {
        guard let s = suggestion else { return }
        await checkIn(s, as: profile)
    }

    func manualCheckIn(_ court: HSCourt, as profile: HSUserProfile?) async {
        await checkIn(court, as: profile)
    }

    func dismissSuggestion() {
        if let s = suggestion { dismissedCourtIds.insert(s.id) }
        suggestion = nil
    }

    func checkOut(uid: String?) async {
        let previous = checkedInCourt
        let coPlayersAtExit = coPlayers
        checkedInCourt = nil
        stopTrackingCoPlayers()
        if let c = previous { firstSeenAt.removeValue(forKey: c.id) }

        guard let uid else { return }
        do {
            try await courtRepo.checkOut(uid: uid)
            if let previous {
                await postDepartureNotifications(for: previous, coPlayers: coPlayersAtExit)
            }
        } catch {
            checkedInCourt = previous
            lastError = error.localizedDescription
        }
    }

    // MARK: - Private

    private func checkIn(_ court: HSCourt, as profile: HSUserProfile?) async {
        let previous = checkedInCourt
        checkedInCourt = court
        suggestion = nil

        guard let profile, let selfUid = profile.id else { return }

        do {
            try await courtRepo.checkIn(profile: profile, at: court)
            startTrackingCoPlayers(at: court, selfUid: selfUid)
        } catch {
            checkedInCourt = previous
            lastError = error.localizedDescription
        }
    }

    private func autoCheckOut() async {
        let previous = checkedInCourt
        let coPlayersAtExit = coPlayers
        checkedInCourt = nil
        stopTrackingCoPlayers()
        if let c = previous { firstSeenAt.removeValue(forKey: c.id) }
        if let previous {
            await postDepartureNotifications(for: previous, coPlayers: coPlayersAtExit)
        }
    }

    // MARK: - Co-presence tracking

    private func startTrackingCoPlayers(at court: HSCourt, selfUid: String) {
        coPlayers = [:]
        coPlayersObserveTask?.cancel()
        let courtId = courtRepo.stableId(for: court)
        coPlayersObserveTask = Task { @MainActor [weak self] in
            for await docs in CourtRepository.shared.observeCheckIns(courtId: courtId) {
                guard let self else { return }
                for d in docs where d.uid != selfUid {
                    if self.coPlayers[d.uid] == nil {
                        self.coPlayers[d.uid] = CoPlayer(
                            uid: d.uid,
                            name: d.displayName,
                            initials: d.initials)
                    }
                }
            }
        }
    }

    private func stopTrackingCoPlayers() {
        coPlayersObserveTask?.cancel()
        coPlayersObserveTask = nil
        coPlayers = [:]
    }

    // MARK: - Departure notifications

    private func postDepartureNotifications(for court: HSCourt,
                                            coPlayers: [String: CoPlayer]) async {
        let center = UNUserNotificationCenter.current()
        let courtId = courtRepo.stableId(for: court)

        // 1. Court rating prompt
        let courtContent = UNMutableNotificationContent()
        courtContent.title = "How was \(court.name)?"
        courtContent.body = "Tap to rate this court."
        courtContent.sound = .default
        courtContent.categoryIdentifier = NotificationCategory.rateCourt
        courtContent.userInfo = [
            "type": "rate_court",
            "courtId": courtId,
            "courtName": court.name
        ]
        let courtReq = UNNotificationRequest(
            identifier: "rate-court-\(courtId)-\(Int(Date().timeIntervalSince1970))",
            content: courtContent,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
        try? await center.add(courtReq)

        // 2. Per-co-player prompts
        for (uid, player) in coPlayers {
            let content = UNMutableNotificationContent()
            content.title = "Rate \(player.name)"
            content.body = "How was hooping with them at \(court.name)?"
            content.sound = .default
            content.categoryIdentifier = NotificationCategory.rateUser
            content.userInfo = [
                "type": "rate_user",
                "ratedUid": uid,
                "ratedName": player.name,
                "ratedInitials": player.initials,
                "courtId": courtId
            ]
            let req = UNNotificationRequest(
                identifier: "rate-user-\(uid)-\(Int(Date().timeIntervalSince1970))",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false))
            try? await center.add(req)
        }
    }
}

// MARK: - Supporting types

extension CheckInService {
    struct CoPlayer: Hashable {
        let uid: String
        let name: String
        let initials: String
    }

    enum RatingPrompt: Equatable {
        case court(id: String, name: String)
        case user(uid: String, name: String, initials: String, courtId: String?)
    }
}

enum NotificationCategory {
    static let rateCourt = "RATE_COURT"
    static let rateUser = "RATE_USER"
}
