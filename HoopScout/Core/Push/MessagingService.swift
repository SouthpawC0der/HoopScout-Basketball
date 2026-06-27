//
//  MessagingService.swift
//  HoopScout
//

import Foundation
import Combine
import UserNotifications
import FirebaseAuth
import FirebaseMessaging

@MainActor
final class MessagingService: NSObject, ObservableObject {
    static let shared = MessagingService()

    /// Set when a notification is tapped or arrives in-foreground with a threadId.
    /// Consumers (MessagesView, HoopTabView) observe and clear this after routing.
    @Published var pendingThreadId: String?

    private override init() {
        super.init()
    }

    func requestAuthorization() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            #if DEBUG
            print("Notification authorization granted:", granted)
            #endif
        } catch {
            #if DEBUG
            print("Notification authorization error:", error)
            #endif
        }
    }

    /// Push the current FCM token to the signed-in user's Firestore profile.
    /// Call this after the user signs in (the token may have arrived earlier
    /// while no user was signed in).
    func syncCurrentToken(uid: String) async {
        do {
            let token = try await Messaging.messaging().token()
            try await UserRepository.shared.setFCMToken(token, uid: uid)
            #if DEBUG
            print("FCM token synced for", uid)
            #endif
        } catch {
            #if DEBUG
            print("FCM token sync failed:", error)
            #endif
        }
    }

    fileprivate func handleNotificationPayload(_ userInfo: [AnyHashable: Any]) {
        if let threadId = userInfo["threadId"] as? String {
            pendingThreadId = threadId
        }
        if let type = userInfo["type"] as? String {
            switch type {
            case "rate_court":
                if let courtId = userInfo["courtId"] as? String {
                    let name = (userInfo["courtName"] as? String) ?? "this court"
                    CheckInService.shared.pendingRatingPrompt = .court(id: courtId, name: name)
                }
            case "rate_user":
                if let ratedUid = userInfo["ratedUid"] as? String {
                    let name = (userInfo["ratedName"] as? String) ?? "this hooper"
                    let initials = (userInfo["ratedInitials"] as? String) ?? "?"
                    let courtId = userInfo["courtId"] as? String
                    CheckInService.shared.pendingRatingPrompt = .user(
                        uid: ratedUid, name: name, initials: initials, courtId: courtId)
                }
            default:
                break
            }
        }
    }
}

// MARK: - MessagingDelegate (FCM)

extension MessagingService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        let uid = Auth.auth().currentUser?.uid
        Task { @MainActor in
            #if DEBUG
            print("FCM token:", token)
            #endif
            if let uid {
                try? await UserRepository.shared.setFCMToken(token, uid: uid)
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension MessagingService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification)
    async -> UNNotificationPresentationOptions {
        let userInfo = notification.request.content.userInfo
        await MainActor.run { Self.shared.handleNotificationPayload(userInfo) }
        return [.banner, .list, .sound, .badge]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        await MainActor.run { Self.shared.handleNotificationPayload(userInfo) }
    }
}
