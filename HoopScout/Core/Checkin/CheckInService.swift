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

    /// How long a court can be out-of-proximity before its dwell timer is
    /// considered abandoned. Tolerates GPS jitter around the proximity edge
    /// (kCLLocationAccuracyHundredMeters can briefly push the user outside the
    /// 80m circle while they're standing on the court).
    var dwellGapSeconds: TimeInterval = 90

    private let courtRepo: CourtRepository
    private var firstSeenAt: [String: Date] = [:]
    private var lastSeenAt: [String: Date] = [:]
    private var dismissedCourtIds: Set<String> = []
    private var visitTaskInFlight: Bool = false

    /// Latest signed-in profile snapshot. Pushed by AuthService whenever the
    /// user doc changes so the LocationManager-driven dwell detector can run
    /// from any screen (not just CourtsView).
    private var activeProfile: HSUserProfile?

    /// Snapshot of unique co-players (uid → display info) seen during the
    /// current check-in, used at checkout to prompt for ratings.
    private var coPlayers: [String: CoPlayer] = [:]
    private var coPlayersObserveTask: Task<Void, Never>?

    /// When the current check-in started — used to decide whether to write
    /// a Run record (10+ min) on departure.
    private var checkInStartedAt: Date?
    private let minimumRunMinutes = 10

    private init() {
        self.courtRepo = .shared
    }

    /// AuthService calls this whenever the signed-in profile changes so the
    /// foreground dwell detector can fire from anywhere in the app.
    func setActiveProfile(_ profile: HSUserProfile?) {
        self.activeProfile = profile
    }

    /// Feed a foreground location fix to the dwell detector using the cached
    /// court list and active profile. Used by LocationManager so auto-detect
    /// works on every screen, not only CourtsView.
    func handleForegroundLocation(_ location: CLLocation) {
        let courts = CourtCache.shared.allKnownCourts()
        guard !courts.isEmpty else { return }
        handle(location: location, courts: courts, profile: activeProfile)
    }

    // MARK: - Foreground proximity (Path B)

    func handle(location: CLLocation, courts: [HSCourt], profile: HSUserProfile? = nil) {
        let candidates = courts.compactMap { court -> (HSCourt, CLLocationDistance)? in
            guard let lat = court.latitude, let lon = court.longitude else { return nil }
            let cl = CLLocation(latitude: lat, longitude: lon)
            return (court, location.distance(from: cl))
        }

        // Walked away → check out (and write to Firestore).
        if let checkedIn = checkedInCourt,
           let pair = candidates.first(where: { $0.0.id == checkedIn.id }),
           pair.1 > exitMeters {
            Task { await self.autoCheckOut() }
        }

        let now = Date()

        // Refresh lastSeen for every court currently within proximity so a
        // single jittery GPS sample (or a closer court briefly winning the
        // "nearest" slot) doesn't reset an in-progress dwell timer.
        let inProximity = candidates.filter { $0.1 <= proximityMeters }
        for (court, _) in inProximity {
            lastSeenAt[court.id] = now
            if firstSeenAt[court.id] == nil {
                firstSeenAt[court.id] = now
            }
        }

        // Forget timers we haven't observed within proximity for a while.
        for (id, last) in lastSeenAt where now.timeIntervalSince(last) > dwellGapSeconds {
            firstSeenAt.removeValue(forKey: id)
            lastSeenAt.removeValue(forKey: id)
        }

        guard let (nearest, _) = inProximity.min(by: { $0.1 < $1.1 }) else {
            if suggestion != nil { suggestion = nil }
            return
        }

        if checkedInCourt?.id == nearest.id { return }
        if dismissedCourtIds.contains(nearest.id) { return }

        let autoDetectOn = UserDefaults.standard.bool(forKey: LocationManager.autoDetectKey)
        if let arrived = firstSeenAt[nearest.id],
           now.timeIntervalSince(arrived) >= dwellSeconds {
            if autoDetectOn, let profile, profile.id != nil {
                // Auto-detect ON → silently check in instead of just suggesting.
                Task { await self.checkIn(nearest, as: profile) }
            } else if suggestion?.id != nearest.id {
                suggestion = nearest
            }
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
                self.checkInStartedAt = Date()
                try? await self.courtRepo.checkIn(profile: profile, at: court)
                await self.postArrivalNotification(for: court)
            } else if self.checkedInCourt?.id == court.id {
                let leaving = self.checkedInCourt
                let coPlayersAtExit = self.coPlayers
                let startedAt = self.checkInStartedAt
                self.checkedInCourt = nil
                self.stopTrackingCoPlayers()
                self.checkInStartedAt = nil
                try? await self.courtRepo.checkOut(uid: uid)
                if let leaving {
                    await self.maybeWriteRun(uid: uid,
                                              court: leaving,
                                              startedAt: startedAt,
                                              coPlayers: coPlayersAtExit)
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

        await NotificationRepository.shared.add(NotificationPayload(
            type: "check_in",
            title: "Checked in at \(court.name)",
            body: "You're counted in the live total.",
            courtId: courtRepo.stableId(for: court),
            courtName: court.name
        ))
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
        let startedAt = checkInStartedAt
        checkedInCourt = nil
        stopTrackingCoPlayers()
        checkInStartedAt = nil
        if let c = previous {
            firstSeenAt.removeValue(forKey: c.id)
            lastSeenAt.removeValue(forKey: c.id)
        }

        guard let uid else { return }
        do {
            try await courtRepo.checkOut(uid: uid)
            if let previous {
                await maybeWriteRun(uid: uid,
                                    court: previous,
                                    startedAt: startedAt,
                                    coPlayers: coPlayersAtExit)
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
            checkInStartedAt = Date()
        } catch {
            checkedInCourt = previous
            lastError = error.localizedDescription
        }
    }

    private func autoCheckOut() async {
        let previous = checkedInCourt
        let coPlayersAtExit = coPlayers
        let startedAt = checkInStartedAt
        checkedInCourt = nil
        stopTrackingCoPlayers()
        checkInStartedAt = nil
        if let c = previous {
            firstSeenAt.removeValue(forKey: c.id)
            lastSeenAt.removeValue(forKey: c.id)
        }

        // Write checkout to Firestore so playingCount decrements
        // and other users stop seeing this user as present.
        let uid = Auth.auth().currentUser?.uid
        if let uid {
            do {
                try await courtRepo.checkOut(uid: uid)
            } catch {
                lastError = error.localizedDescription
            }
        }

        if let previous {
            if let uid {
                await maybeWriteRun(uid: uid,
                                    court: previous,
                                    startedAt: startedAt,
                                    coPlayers: coPlayersAtExit)
            }
            await postDepartureNotifications(for: previous, coPlayers: coPlayersAtExit)
        }
    }

    /// Persist a Run record when the user stayed at the court ≥ 10 minutes.
    private func maybeWriteRun(uid: String,
                               court: HSCourt,
                               startedAt: Date?,
                               coPlayers: [String: CoPlayer]) async {
        guard let startedAt else { return }
        let endedAt = Date()
        let minutes = Int(endedAt.timeIntervalSince(startedAt) / 60)
        guard minutes >= minimumRunMinutes else { return }

        let players = coPlayers.values.map {
            HSRunDoc.CoPlayer(uid: $0.uid, name: $0.name, initials: $0.initials)
        }
        let run = HSRunDoc(
            courtId: courtRepo.stableId(for: court),
            courtName: court.name,
            startedAt: startedAt,
            endedAt: endedAt,
            durationMinutes: minutes,
            coPlayers: players,
            rated: false
        )
        try? await RunRepository.shared.add(uid: uid, run: run)
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

        await NotificationRepository.shared.add(NotificationPayload(
            type: "rate_court",
            title: "Rate \(court.name)",
            body: "Tap to leave 1–5 balls for this court.",
            courtId: courtId,
            courtName: court.name
        ))

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

            await NotificationRepository.shared.add(NotificationPayload(
                type: "rate_user",
                title: "Rate \(player.name)",
                body: "You played at \(court.name). Leave them stars + a comment.",
                courtId: courtId,
                courtName: court.name,
                userUid: uid,
                userName: player.name,
                userInitials: player.initials
            ))
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
