//
//  AuthService.swift
//  HoopScout
//

import Foundation
import Combine
import CryptoKit
import UIKit
import AuthenticationServices
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var firebaseUser: User?
    @Published private(set) var profile: HSUserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var handle: AuthStateDidChangeListenerHandle?
    private var profileObserveTask: Task<Void, Never>?

    /// Nonce used during the in-flight Sign in with Apple request.
    fileprivate var currentNonce: String?

    /// Form data captured from GymSignUpView before tapping Sign in with
    /// Apple. Consumed in completeSignInWithApple to write a gym-flavored
    /// HSUserProfile on first sign-in.
    fileprivate var pendingGymRegistration: PendingGymRegistration?

    struct PendingGymRegistration {
        var businessName: String
        var ein: String
        var businessAddress: String
        var businessEmail: String
        var managerFirstName: String
        var managerLastName: String
        /// "small" (≈high school size → $49/yr) or "large" (college+ → $99/yr).
        var courtSize: String
    }

    /// Length of the gym free trial in days.
    static let gymTrialDays: Int = 7

    func setPendingGymRegistration(_ pending: PendingGymRegistration?) {
        pendingGymRegistration = pending
    }

    var isSignedIn: Bool { firebaseUser != nil }

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.firebaseUser = user
                if let user {
                    await self?.loadProfile(uid: user.uid)
                    NotificationRepository.shared.start(forUid: user.uid)
                    BlockRepository.shared.start(forUid: user.uid)
                    FriendsRepository.shared.start(forUid: user.uid)
                    SubscriptionService.shared.start(forUid: user.uid)
                } else {
                    self?.profileObserveTask?.cancel()
                    self?.profile = nil
                    CheckInService.shared.setActiveProfile(nil)
                    NotificationRepository.shared.stop()
                    BlockRepository.shared.stop()
                    FriendsRepository.shared.stop()
                    SubscriptionService.shared.stop()
                }
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
        profileObserveTask?.cancel()
    }

    // MARK: - Email/password

    func signIn(email: String, password: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard cleanEmail.contains("@"), password.count >= 6 else {
            errorMessage = "Enter a valid email and a password of at least 6 characters."
            return
        }
        do {
            _ = try await Auth.auth().signIn(withEmail: cleanEmail, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signUp(firstName: String,
                lastName: String,
                email: String,
                confirmEmail: String,
                password: String,
                position: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        let cleanFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanConfirm = confirmEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let cleanPosition = position.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName = "\(cleanFirst) \(cleanLast)".trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanFirst.isEmpty, !cleanLast.isEmpty, cleanName.count <= 80 else {
            errorMessage = "Enter your first and last name."
            return
        }
        guard cleanEmail.contains("@"), cleanEmail.count <= 254 else {
            errorMessage = "Enter a valid email."
            return
        }
        guard cleanEmail == cleanConfirm else {
            errorMessage = "Emails don't match."
            return
        }
        guard password.count >= 6, password.count <= 128 else {
            errorMessage = "Password must be 6–128 characters."
            return
        }
        guard !cleanPosition.isEmpty, cleanPosition.count <= 40 else {
            errorMessage = "Pick a position."
            return
        }
        do {
            let result = try await Auth.auth().createUser(withEmail: cleanEmail, password: password)
            let profile = HSUserProfile(
                id: result.user.uid,
                name: cleanName,
                handle: defaultHandle(from: cleanEmail),
                location: "",
                bio: "",
                skill: "Casual",
                runs: 0,
                followers: 0,
                following: 0,
                createdAt: Date(),
                position: cleanPosition
            )
            try await UserRepository.shared.create(profile)
            self.profile = profile
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        do { try Auth.auth().signOut() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Account deletion (required by App Store Guideline 5.1.1(v))

    enum DeleteAccountResult {
        case success
        case requiresRecentLogin
        case failed(String)
    }

    /// Permanently deletes the signed-in account. Removes the Firestore user
    /// doc (best-effort — server-side Cloud Functions clean up the rest), then
    /// deletes the Firebase Auth user. If Firebase reports the user signed in
    /// too long ago, we surface `.requiresRecentLogin` so the UI can prompt
    /// re-authentication.
    func deleteAccount() async -> DeleteAccountResult {
        guard let user = Auth.auth().currentUser else {
            return .failed("You're not signed in.")
        }
        let uid = user.uid

        // Best-effort: tombstone the user doc so other clients stop showing
        // the profile, and so a server-side cleanup job can finish removing
        // subcollections (followers/following, blocks, reports, etc).
        let userRef = Firestore.firestore().collection("users").document(uid)
        try? await userRef.setData([
            "deletedAt": FieldValue.serverTimestamp(),
            "name": "Deleted user",
            "handle": "@deleted",
            "bio": "",
            "photoURL": NSNull()
        ], merge: true)
        // Sensitive PII (EIN, manager names, FCM token) lives in the private
        // subcollection — purge it explicitly so deletion is complete.
        try? await userRef.collection("private").document("profile").delete()

        do {
            try await user.delete()
            return .success
        } catch {
            let ns = error as NSError
            if ns.code == AuthErrorCode.requiresRecentLogin.rawValue {
                return .requiresRecentLogin
            }
            return .failed(error.localizedDescription)
        }
    }

    func sendPasswordReset(email: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            try await Auth.auth().sendPasswordReset(
                withEmail: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())
        } catch { errorMessage = error.localizedDescription }
    }

    // MARK: - Sign in with Apple

    /// Returns the SHA-256 of the nonce, to be set on `ASAuthorizationAppleIDRequest.nonce`.
    func prepareAppleNonce() -> String {
        let raw = randomNonceString()
        currentNonce = raw
        return sha256(raw)
    }

    func completeSignInWithApple(credential: ASAuthorizationAppleIDCredential) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        guard let nonce = currentNonce else {
            errorMessage = "Apple sign-in failed: missing nonce."
            return
        }
        guard let tokenData = credential.identityToken,
              let idTokenString = String(data: tokenData, encoding: .utf8) else {
            errorMessage = "Apple sign-in failed: missing identity token."
            return
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idTokenString,
            rawNonce: nonce,
            fullName: credential.fullName
        )

        do {
            let result = try await Auth.auth().signIn(with: firebaseCredential)
            currentNonce = nil
            // Create a profile if this is the user's first sign-in.
            let existing = try? await UserRepository.shared.fetch(uid: result.user.uid)
            if existing == nil {
                if let gym = pendingGymRegistration {
                    let email = !gym.businessEmail.isEmpty
                        ? gym.businessEmail
                        : (credential.email ?? result.user.email ?? "")
                    // Apple's stable sub claim — same value across re-signups
                    // with the same Apple ID. Used by `stampGymTrialOnCreate`
                    // to deny a fresh 7-day trial if this Apple ID already
                    // claimed one under a previous Firebase uid.
                    let appleUserId = credential.user
                    // Trial fields (subscriptionStatus / trialStartedAt /
                    // subscriptionExpiresAt) are intentionally NOT set here.
                    // The `stampGymTrialOnCreate` Cloud Function stamps them
                    // server-side so the trial clock can't be lied about.
                    // Rules reject client writes to those fields anyway.
                    let profile = HSUserProfile(
                        id: result.user.uid,
                        name: gym.businessName,
                        handle: email.isEmpty
                            ? "@gym_\(result.user.uid.prefix(6))"
                            : defaultHandle(from: email),
                        location: gym.businessAddress,
                        bio: "",
                        skill: "Gym",
                        runs: 0,
                        followers: 0,
                        following: 0,
                        createdAt: Date(),
                        accountKind: "gym",
                        businessName: gym.businessName,
                        ein: gym.ein,
                        businessAddress: gym.businessAddress,
                        managerFirstName: gym.managerFirstName,
                        managerLastName: gym.managerLastName,
                        appleUserIdentifier: appleUserId,
                        gymCourtSize: gym.courtSize
                    )
                    try await UserRepository.shared.create(profile)
                    self.profile = profile
                    pendingGymRegistration = nil
                } else {
                    let derivedName: String = {
                        if let comps = credential.fullName {
                            let parts = [comps.givenName, comps.familyName].compactMap { $0 }
                            let joined = parts.joined(separator: " ")
                            if !joined.isEmpty { return joined }
                        }
                        return result.user.displayName ?? "Hooper"
                    }()
                    let email = credential.email ?? result.user.email ?? ""
                    let profile = HSUserProfile(
                        id: result.user.uid,
                        name: derivedName,
                        handle: email.isEmpty
                            ? "@hooper_\(result.user.uid.prefix(6))"
                            : defaultHandle(from: email),
                        location: "",
                        bio: "",
                        skill: "Casual",
                        runs: 0,
                        followers: 0,
                        following: 0,
                        createdAt: Date()
                    )
                    try await UserRepository.shared.create(profile)
                    self.profile = profile
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func failSignInWithApple(_ error: Error) {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue { return }
        errorMessage = error.localizedDescription
    }

    // MARK: - Sign in with Google

    func signInWithGoogle() async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }

        guard let clientID = FirebaseApp.app()?.options.clientID else {
            errorMessage = "Firebase isn't configured for Google sign-in."
            return
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        guard let presenting = Self.topViewController() else {
            errorMessage = "Couldn't find a view controller to present Google sign-in."
            return
        }

        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenting)
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Google sign-in didn't return an ID token."
                return
            }
            let credential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: result.user.accessToken.tokenString
            )
            let authResult = try await Auth.auth().signIn(with: credential)

            // Create a profile on first sign-in.
            let existing = try? await UserRepository.shared.fetch(uid: authResult.user.uid)
            if existing == nil {
                let googleProfile = result.user.profile
                let name = googleProfile?.name
                    ?? authResult.user.displayName
                    ?? "Hooper"
                let email = googleProfile?.email
                    ?? authResult.user.email
                    ?? ""
                let profile = HSUserProfile(
                    id: authResult.user.uid,
                    name: name,
                    handle: email.isEmpty
                        ? "@hooper_\(authResult.user.uid.prefix(6))"
                        : defaultHandle(from: email),
                    location: "",
                    bio: "",
                    skill: "Casual",
                    runs: 0,
                    followers: 0,
                    following: 0,
                    createdAt: Date()
                )
                try await UserRepository.shared.create(profile)
                self.profile = profile
            }
        } catch {
            let ns = error as NSError
            if ns.domain == "com.google.GIDSignIn", ns.code == -5 { return } // user canceled
            errorMessage = error.localizedDescription
        }
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? scenes.first as? UIWindowScene
        guard let root = windowScene?.windows.first(where: { $0.isKeyWindow })?.rootViewController
                ?? windowScene?.windows.first?.rootViewController else {
            return nil
        }
        return Self.deepestPresented(root)
    }

    private static func deepestPresented(_ vc: UIViewController) -> UIViewController {
        if let presented = vc.presentedViewController { return deepestPresented(presented) }
        return vc
    }

    // MARK: - Internal

    private func defaultHandle(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "hooper"
        let cleaned = local.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        let trimmed = String(cleaned.prefix(24))
        return "@" + (trimmed.isEmpty ? "hooper" : trimmed)
    }

    /// Apply a locally-updated profile snapshot so views observing `profile`
    /// refresh immediately (e.g. after editing profile or uploading a photo).
    func applyLocalProfileUpdate(_ updated: HSUserProfile) {
        self.profile = updated
    }

    private func loadProfile(uid: String) async {
        // Snapshot-listen rather than one-shot fetch so server-side counter
        // bumps (followersCount when someone follows you, followingCount when
        // you follow someone) flow into the UI without manual refreshes.
        profileObserveTask?.cancel()
        profileObserveTask = Task { @MainActor [weak self] in
            for await fresh in UserRepository.shared.observe(uid: uid) {
                guard let self else { return }
                self.profile = fresh
                CheckInService.shared.setActiveProfile(fresh)
            }
        }
        await MessagingService.shared.syncCurrentToken(uid: uid)
    }
}

// MARK: - Nonce helpers (Apple-recommended)

private func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remaining = length
    while remaining > 0 {
        var random: UInt8 = 0
        let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
        guard status == errSecSuccess else { continue }
        if random < charset.count {
            result.append(charset[Int(random)])
            remaining -= 1
        }
    }
    return result
}

private func sha256(_ input: String) -> String {
    let data = Data(input.utf8)
    let hash = SHA256.hash(data: data)
    return hash.map { String(format: "%02x", $0) }.joined()
}
