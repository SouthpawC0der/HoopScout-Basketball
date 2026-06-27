//
//  GymPaywallView.swift
//  HoopScout
//
//  Renewal/upgrade paywall shown when a gym tries to use a paid feature
//  (ads, articles) without an active subscription, or directly from the
//  hamburger menu if we add a "Manage Subscription" row later.
//

import SwiftUI
import StoreKit

struct GymPaywallView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var subs: SubscriptionService
    @Environment(\.dismiss) private var dismiss

    @State private var purchasing: String?
    @State private var localError: String?

    private var defaultTier: String {
        SubscriptionService.shared.productID(for: auth.profile?.gymCourtSize)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    productCards
                    if let trialDays = auth.profile?.trialDaysRemaining, trialDays > 0 {
                        trialBanner(daysLeft: trialDays)
                    }
                    restoreButton
                    legal
                    if let err = localError ?? subs.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .background(HSColors.bg)
            .navigationTitle("Gym Membership")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(HSColors.navy)
                }
            }
            .task {
                await subs.loadProducts()
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundColor(HSColors.navy)
            Text("Keep your gym featured")
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(HSColors.gray900)
                .multilineTextAlignment(.center)
            Text("Run ads on the Backboard and publish local articles in the News tab. Pick the tier that matches your facility.")
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
        }
    }

    private var productCards: some View {
        VStack(spacing: 12) {
            tierCard(productID: SubscriptionService.ProductID.small,
                     title: "Small facility",
                     subtitle: "Around high school court size",
                     fallbackPrice: "$49 / year")
            tierCard(productID: SubscriptionService.ProductID.large,
                     title: "Large facility",
                     subtitle: "College size courts or bigger",
                     fallbackPrice: "$99 / year")
        }
    }

    private func tierCard(productID: String,
                          title: String,
                          subtitle: String,
                          fallbackPrice: String) -> some View {
        let product = subs.product(for: productID)
        let priceLabel = product?.displayPrice ?? fallbackPrice
        let isDefault = productID == defaultTier
        let isPurchasing = purchasing == productID

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 16, weight: .heavy))
                            .foregroundColor(HSColors.gray900)
                        if isDefault {
                            Text("YOUR TIER")
                                .font(.system(size: 9, weight: .heavy))
                                .kerning(0.8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(HSColors.court)
                                .clipShape(Capsule())
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Text(priceLabel)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(HSColors.navy)
            }

            Button {
                Task {
                    localError = nil
                    purchasing = productID
                    let ok = await subs.purchase(productID: productID)
                    purchasing = nil
                    if ok { dismiss() }
                }
            } label: {
                HStack {
                    if isPurchasing {
                        ProgressView().tint(.white)
                    } else {
                        Text(subs.purchasedProductIDs.contains(productID) ? "Current plan" : "Subscribe")
                            .font(.system(size: 14, weight: .bold))
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 44)
                .background(subs.purchasedProductIDs.contains(productID) ? HSColors.gray300 : HSColors.navy)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(isPurchasing
                      || product == nil
                      || subs.purchasedProductIDs.contains(productID))
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isDefault ? HSColors.court : HSColors.gray200,
                        lineWidth: isDefault ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func trialBanner(daysLeft: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(HSColors.navy)
            Text("\(daysLeft) day\(daysLeft == 1 ? "" : "s") left on your free trial")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(HSColors.gray900)
            Spacer()
        }
        .padding(12)
        .background(HSColors.court.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var restoreButton: some View {
        Button {
            Task { await subs.restorePurchases() }
        } label: {
            Text("Restore Purchases")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(HSColors.navy)
        }
    }

    private var legal: some View {
        Text("Auto-renews yearly. Cancel anytime in your Apple ID settings. Charges apply at the end of the 7-day free trial.")
            .font(.system(size: 11))
            .foregroundColor(HSColors.gray500)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 20)
    }
}

#Preview {
    GymPaywallView()
        .environmentObject(AuthService())
        .environmentObject(SubscriptionService.shared)
}
