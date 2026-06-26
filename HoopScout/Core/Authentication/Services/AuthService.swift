//
//  AuthService.swift
//  HoopScout
//

import Foundation
import Combine
import CryptoKit
import AuthenticationServices
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var firebaseUser: User?
    @Published private(set) var profile: HSUserProfile?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var handle: AuthStateDidChangeListenerHandle?

    /// Nonce used during the in-flight Sign in with Apple request.
    fileprivate var currentNonce: String?

    var isSignedIn: Bool { firebaseUser != nil }

    init() {
        handle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.firebaseUser = user
                if let user {
                    await self?.loadProfile(uid: user.uid)
                } else {
                    self?.profile = nil
                }
            }
        }
    }

    deinit {
        if let handle { Auth.auth().removeStateDidChangeListener(handle) }
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

    func signUp(email: String, password: String, name: String) async {
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !cleanName.isEmpty, cleanName.count <= 80 else {
            errorMessage = "Name must be 1–80 characters."
            return
        }
        guard cleanEmail.contains("@"), cleanEmail.count <= 254 else {
            errorMessage = "Enter a valid email."
            return
        }
        guard password.count >= 6, password.count <= 128 else {
            errorMessage = "Password must be 6–128 characters."
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
                createdAt: Date()
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func failSignInWithApple(_ error: Error) {
        let ns = error as NSError
        if ns.code == ASAuthorizationError.canceled.rawValue { return }
        errorMessage = error.localizedDescription
    }

    // MARK: - Internal

    private func defaultHandle(from email: String) -> String {
        let local = email.split(separator: "@").first.map(String.init) ?? "hooper"
        let cleaned = local.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" || $0 == "." }
        let trimmed = String(cleaned.prefix(24))
        return "@" + (trimmed.isEmpty ? "hooper" : trimmed)
    }

    private func loadProfile(uid: String) async {
        do {
            profile = try await UserRepository.shared.fetch(uid: uid)
            await MessagingService.shared.syncCurrentToken(uid: uid)
        } catch {
            #if DEBUG
            print("Profile load failed:", error)
            #endif
        }
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
