//
//  OnboardingView.swift
//  HoopScout
//

import SwiftUI

struct OnboardingView: View {
    var onComplete: () -> Void
    @State private var step: Int = 0

    var body: some View {
        ZStack {
            LinearGradient(colors: [HSColors.navy, HSColors.navyDeep],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            RadialGradient(colors: [HSColors.court.opacity(0.18), .clear],
                           center: .top, startRadius: 0, endRadius: 320)
                .frame(height: 340)
                .frame(maxHeight: .infinity, alignment: .top)
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                topBrand
                if step == 0 { splashContent } else { permissionContent }
                Spacer(minLength: 0)
                cta
            }
            .foregroundColor(.white)
        }
        .preferredColorScheme(.dark)
    }

    private var topBrand: some View {
        VStack(spacing: 16) {
            HSLogo(size: 56, light: true)
            Text("HoopScout")
                .font(.system(size: 13, weight: .semibold))
                .kerning(3)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.55))
        }
        .padding(.top, 60)
    }

    private var splashContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Find the run.\nBefore it runs out.")
                .font(.system(size: 38, weight: .heavy))
                .kerning(-1.2)
                .lineSpacing(2)

            Text("Live player counts at every court in 15 miles. See which hoopers are already there.")
                .font(.system(size: 16))
                .foregroundColor(.white.opacity(0.7))
                .lineSpacing(4)
                .frame(maxWidth: 300, alignment: .leading)

            previewCards
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 32)
        .padding(.top, 40)
    }

    private var previewCards: some View {
        ZStack(alignment: .top) {
            cardPreview(name: "West 4th Courts", meta: "0.8 mi · ★ 4.8", count: 18,
                        colors: [Color(red: 0.831, green: 0.647, blue: 0.455),
                                 Color(red: 0.545, green: 0.353, blue: 0.169)])
                .rotationEffect(.degrees(-2))
            cardPreview(name: "Rucker Park", meta: "2.4 mi · ★ 4.9", count: 32,
                        colors: [Color(red: 0.173, green: 0.325, blue: 0.510),
                                 Color(red: 0.102, green: 0.212, blue: 0.365)])
                .rotationEffect(.degrees(1.5))
                .offset(x: 20, y: 80)
        }
        .frame(height: 180)
    }

    private func cardPreview(name: String, meta: String, count: Int, colors: [Color]) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.system(size: 15, weight: .bold)).foregroundColor(HSColors.gray900)
                Text(meta).font(.system(size: 12)).foregroundColor(HSColors.gray500)
            }
            Spacer()
            HStack(spacing: 5) {
                HSLivePulse(size: 6)
                Text("\(count) playing").font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(HSColors.live)
            .padding(.horizontal, 9).padding(.vertical, 5)
            .background(HSColors.live.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 20)
    }

    private var permissionContent: some View {
        VStack(spacing: 0) {
            locationRing
                .padding(.top, 24)
                .padding(.bottom, 36)

            Text("Where you hooping?")
                .font(.system(size: 28, weight: .heavy))
                .kerning(-0.8)
                .multilineTextAlignment(.center)

            Text("Share your location so we can show live counts at courts near you — and you can count toward the count.")
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
                .padding(.top, 14)
                .lineSpacing(3)

            VStack(alignment: .leading, spacing: 10) {
                bulletRow("Your dot drops you into the count at your court")
                bulletRow("Friends see you're playing (you control this)")
                bulletRow("Only used while the app is open")
            }
            .font(.system(size: 13))
            .foregroundColor(.white.opacity(0.75))
            .padding(16)
            .background(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 32)
            .padding(.top, 32)
        }
    }

    private var locationRing: some View {
        ZStack {
            Circle().fill(HSColors.court.opacity(0.08)).frame(width: 160, height: 160)
            Circle().fill(HSColors.court.opacity(0.14)).frame(width: 120, height: 120)
            Circle().fill(HSColors.court).frame(width: 70, height: 70)
                .overlay(
                    Image(systemName: "location.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                )
                .shadow(color: HSColors.court.opacity(0.5), radius: 12, x: 0, y: 12)
        }
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("●").foregroundColor(HSColors.court)
            Text(text)
        }
    }

    private var cta: some View {
        VStack(spacing: 10) {
            if step == 0 {
                Button { withAnimation { step = 1 } } label: {
                    Text("Get started")
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .foregroundColor(HSColors.navy)
                        .font(.system(size: 16, weight: .bold))
                        .kerning(-0.2)
                        .clipShape(Capsule())
                        .shadow(color: .white.opacity(0.18), radius: 18, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                HStack(spacing: 4) {
                    Text("Already got a login?").foregroundColor(.white.opacity(0.5))
                    Text("Sign in").fontWeight(.semibold).foregroundColor(.white)
                }
                .font(.system(size: 13))
            } else {
                Button(action: onComplete) {
                    Text("Allow location")
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(Color.white)
                        .foregroundColor(HSColors.navy)
                        .font(.system(size: 16, weight: .bold))
                        .kerning(-0.2)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                Button(action: onComplete) {
                    Text("Use ZIP code instead")
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .foregroundColor(.white.opacity(0.55))
                        .font(.system(size: 15, weight: .semibold))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 50)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
