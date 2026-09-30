import SwiftUI
import StoreKit

// =====================================================================
// ProPaywallView
//
// Presented as a sheet whenever a free user taps a Pro-gated feature.
// Reads product price live from StoreKit so it reflects any regional
// pricing set in App Store Connect.
//
// Usage:
//   .sheet(isPresented: $showPaywall) { ProPaywallView() }
// =====================================================================

struct ProPaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(EntitlementManager.self) private var entitlements

    @State private var purchasing = false
    @State private var restoring  = false
    @State private var errorMessage: String?

    private let features: [(title: String, icon: String)] = [
        ("Unlimited history",        "clock.fill"),
        ("Workout planner",          "calendar"),
        ("AI-generated schedules",   "sparkles"),
        ("Progress charts & trends", "chart.line.uptrend.xyaxis"),
        ("Weekly summary card",      "chart.bar.doc.horizontal"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                featureList
                pricing
                errorBanner
                buyButton
                restoreButton
                legal
            }
        }
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        // Auto-dismiss when purchase completes (e.g. StoreKit sheet returns)
        .onChange(of: entitlements.isPro) { _, newValue in
            if newValue { dismiss() }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 46))
                    .foregroundStyle(.green)
            }
            .padding(.top, 48)

            Text("RepsPT Pro")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("Your AI personal trainer, fully unlocked")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 40)
    }

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 18) {
            ForEach(features, id: \.title) { feature in
                ProFeatureRow(title: feature.title, icon: feature.icon)
            }
        }
        .padding(.horizontal, 36)
        .padding(.bottom, 40)
    }

    private var pricing: some View {
        VStack(spacing: 6) {
            if let product = entitlements.proProduct {
                Text(product.displayPrice)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("per year · less than a single PT session")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.4))
            } else {
                ProgressView().tint(.white)
            }
        }
        .frame(minHeight: 64)
        .padding(.bottom, 28)
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let msg = errorMessage {
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red.opacity(0.85))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.bottom, 12)
        }
    }

    private var buyButton: some View {
        Button {
            Task { await buy() }
        } label: {
            Group {
                if purchasing {
                    ProgressView().tint(.black)
                } else {
                    Text(entitlements.proProduct != nil
                         ? "Start RepsPT Pro"
                         : "Loading…")
                }
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(purchasing || restoring || entitlements.proProduct == nil)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            Group {
                if restoring {
                    ProgressView().tint(.white).scaleEffect(0.75)
                } else {
                    Text("Restore purchase")
                }
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.4))
        }
        .disabled(purchasing || restoring)
        .padding(.bottom, 14)
    }

    private var legal: some View {
        Text("Subscription renews annually. Cancel any time in Settings → Subscriptions.")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.2))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            .padding(.bottom, 44)
    }

    // MARK: - Actions

    private func buy() async {
        purchasing = true
        errorMessage = nil
        do {
            try await entitlements.purchase()
            // `onChange(of: isPro)` handles dismiss on success
        } catch {
            errorMessage = "Purchase failed. Please try again."
        }
        purchasing = false
    }

    private func restore() async {
        restoring = true
        errorMessage = nil
        do {
            try await entitlements.restore()
            if !entitlements.isPro {
                errorMessage = "No active subscription found."
            }
        } catch {
            errorMessage = "Restore failed. Please try again."
        }
        restoring = false
    }
}

// =====================================================================
// ProFeatureRow — reusable in paywall and any "what's in Pro?" context
// =====================================================================

struct ProFeatureRow: View {
    let title: String
    let icon:  String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.green)
                .frame(width: 24)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.white)
            Spacer()
            Image(systemName: "checkmark")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.25))
        }
    }
}
