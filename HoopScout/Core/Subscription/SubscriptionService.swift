//
//  SubscriptionService.swift
//  HoopScout
//
//  StoreKit 2 wrapper for the gym account subscription tiers. Loads the
//  two auto-renewable products from the App Store, runs purchases, and
//  listens for `Transaction.updates` so the Firestore user doc stays in
//  sync when the App Store renews, refunds, or revokes the subscription.
//
//  Setup needed in App Store Connect (NOT done in code):
//    • Create two auto-renewable subscriptions in a "GymAccess" group
//      with the IDs listed in `ProductID`.
//    • Attach a 7-day free intro offer to each.
//    • Add a StoreKit configuration file in the Xcode scheme for local
//      testing until the products are approved.
//

import Foundation
import Combine
import StoreKit

@MainActor
final class SubscriptionService: ObservableObject {
    static let shared = SubscriptionService()

    enum ProductID {
        /// Around high school court size — $49/yr.
        static let small = "com.hoopscout.gym.small.yearly"
        /// College size courts or bigger — $99/yr.
        static let large = "com.hoopscout.gym.large.yearly"
        static let all: [String] = [small, large]
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var observedUid: String?

    private init() {}

    // MARK: - Lifecycle

    /// Begin listening for transaction updates and syncing entitlement to
    /// the signed-in user's Firestore doc. Safe to re-call across auth
    /// transitions; rebinds to the new uid.
    func start(forUid uid: String) {
        guard observedUid != uid else { return }
        stop()
        observedUid = uid

        Task { await loadProducts() }
        Task { await refreshEntitlement(forUid: uid) }

        updatesTask = Task.detached { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(transactionResult: update)
            }
        }
    }

    func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        observedUid = nil
        purchasedProductIDs = []
    }

    // MARK: - Products

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched = try await Product.products(for: ProductID.all)
            products = fetched.sorted { $0.price < $1.price }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func product(for id: String) -> Product? {
        products.first(where: { $0.id == id })
    }

    func productID(for courtSize: String?) -> String {
        courtSize == "large" ? ProductID.large : ProductID.small
    }

    // MARK: - Purchase

    /// Launch the App Store purchase flow for the given tier. Returns
    /// `true` when the purchase verified successfully.
    @discardableResult
    func purchase(productID: String) async -> Bool {
        guard let product = product(for: productID) else {
            errorMessage = "Subscription isn't available right now."
            return false
        }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try verifiedTransaction(verification)
                await applyEntitled(verification)
                await transaction.finish()
                return true
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            if let uid = observedUid {
                await refreshEntitlement(forUid: uid)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Entitlement

    /// Walks `Transaction.currentEntitlements` and submits the signed JWS
    /// for each owned subscription to the server. The Cloud Function
    /// (`validateAppStoreTransaction`) verifies the signature and writes
    /// the canonical entitlement. We don't trust the client-decoded
    /// transaction fields beyond UI hints.
    private func refreshEntitlement(forUid uid: String) async {
        var owned = Set<String>()
        for await result in Transaction.currentEntitlements {
            guard let transaction = try? verifiedTransaction(result) else { continue }
            guard ProductID.all.contains(transaction.productID) else { continue }
            if transaction.revocationDate == nil {
                owned.insert(transaction.productID)
                await submitToServer(result)
            }
        }
        purchasedProductIDs = owned
    }

    private func applyEntitled(_ result: VerificationResult<Transaction>) async {
        guard let transaction = try? verifiedTransaction(result) else { return }
        purchasedProductIDs.insert(transaction.productID)
        await submitToServer(result)
    }

    private func handle(transactionResult: VerificationResult<Transaction>) async {
        guard let transaction = try? verifiedTransaction(transactionResult) else { return }
        if transaction.revocationDate != nil {
            purchasedProductIDs.remove(transaction.productID)
        }
        // Always forward the signed payload so the server can record the
        // current state (active, revoked, expired) authoritatively.
        await submitToServer(transactionResult)
        await transaction.finish()
    }

    /// Submit the JWS-signed transaction blob to the validation function.
    /// Failures are non-fatal — the App Store Server Notifications V2
    /// webhook is the authoritative path for eventual consistency.
    private func submitToServer(_ result: VerificationResult<Transaction>) async {
        let jws = result.jwsRepresentation
        do {
            try await UserRepository.shared.submitAppStoreTransaction(
                signedTransactionInfo: jws
            )
        } catch {
            #if DEBUG
            print("SubscriptionService: server submit failed:", error.localizedDescription)
            #endif
        }
    }

    private func verifiedTransaction(_ result: VerificationResult<Transaction>) throws -> Transaction {
        switch result {
        case .verified(let transaction):
            return transaction
        case .unverified(_, let error):
            throw error
        }
    }
}
