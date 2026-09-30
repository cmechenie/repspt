import Foundation
import Observation
import StoreKit

// =====================================================================
// EntitlementManager
//
// Single source of truth for whether the user has an active Pro
// subscription.  Injected into the SwiftUI environment at the root
// so any view can read `entitlements.isPro` and react to changes.
//
// Product IDs must match App Store Connect (and RepsPT.storekit for
// local simulator testing).
// =====================================================================

@Observable
@MainActor
final class EntitlementManager {

    // MARK: - Singleton

    static let shared = EntitlementManager()

    // MARK: - Public state (observed by SwiftUI views)

    private(set) var isPro: Bool = false
    private(set) var proProduct: Product?

    // MARK: - Constants

    static let proProductID = "com.cristian.repspt.pro.annual"

    // MARK: - Private

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await loadProduct()
            await refresh()
        }
    }

    // MARK: - Public API

    /// Buy the Pro subscription.  Throws on payment failure; returns silently
    /// on user-cancel or pending state.
    func purchase() async throws {
        guard let product = proProduct else { return }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            if case .verified(let tx) = verification {
                await tx.finish()
                await refresh()
            }
        case .userCancelled, .pending:
            break
        @unknown default:
            break
        }
    }

    /// Restore transactions (e.g. after reinstall / new device).
    func restore() async throws {
        try await AppStore.sync()
        await refresh()
    }

    // MARK: - Internal

    /// Re-checks all current entitlements and updates `isPro`.
    func refresh() async {
        var active = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == Self.proProductID,
               tx.revocationDate == nil {
                active = true
            }
        }
        isPro = active
    }

    private func loadProduct() async {
        proProduct = try? await Product.products(for: [Self.proProductID]).first
    }

    /// Background loop — wakes whenever a transaction arrives (purchase,
    /// refund, renewal) and refreshes entitlement state.
    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let tx) = result {
                await tx.finish()
                await refresh()
            }
        }
    }
}
