//
//  GymSignUpView.swift
//  HoopScout
//
//  Business-account signup for indoor courts and rec centers. Collects
//  legal/business identity (name, EIN, address, business email, manager
//  name) and authenticates via Sign in with Apple. The collected form
//  data is stashed on AuthService so the post-Apple completion handler
//  can write a gym-flavored HSUserProfile (accountKind == "gym").
//

import SwiftUI
import AuthenticationServices

struct GymSignUpView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var businessName = ""
    @State private var ein = ""
    @State private var businessAddress = ""
    @State private var businessEmail = ""
    @State private var managerFirstName = ""
    @State private var managerLastName = ""
    @State private var courtSize: CourtSize = .small

    enum CourtSize: String, CaseIterable, Identifiable {
        case small, large
        var id: String { rawValue }
        var title: String {
            switch self {
            case .small: return "Small facility"
            case .large: return "Large facility"
            }
        }
        var subtitle: String {
            switch self {
            case .small: return "Around high school court size"
            case .large: return "College size courts or bigger"
            }
        }
        var priceLabel: String {
            switch self {
            case .small: return "$49/yr"
            case .large: return "$99/yr"
            }
        }
        var icon: String {
            switch self {
            case .small: return "building"
            case .large: return "building.2.fill"
            }
        }
    }

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

            ScrollView {
                VStack(spacing: 20) {
                    header
                    fields
                    appleSignIn
                    blurb
                    if let err = auth.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    auth.errorMessage = nil
                    auth.setPendingGymRegistration(nil)
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 44, weight: .semibold))
                .foregroundColor(.white)
            Text("HoopScout")
                .font(.system(size: 13, weight: .semibold))
                .kerning(3)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.55))
            Text("Gym Account")
                .font(.system(size: 26, weight: .heavy))
                .kerning(-0.6)
                .foregroundColor(.white)
            Text("For indoor courts and rec centers")
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var fields: some View {
        VStack(spacing: 10) {
            inputField("Legal business / gym name", text: $businessName)
                .textInputAutocapitalization(.words)
            inputField("EIN number", text: $ein)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
            inputField("Gym address", text: $businessAddress)
                .textContentType(.fullStreetAddress)
                .textInputAutocapitalization(.words)
            inputField("Business email address", text: $businessEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            HStack(spacing: 10) {
                inputField("Manager first name", text: $managerFirstName)
                    .textContentType(.givenName)
                    .textInputAutocapitalization(.words)
                inputField("Manager last name", text: $managerLastName)
                    .textContentType(.familyName)
                    .textInputAutocapitalization(.words)
            }
            courtSizePicker
        }
    }

    private var courtSizePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COURT SIZE")
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundColor(.white.opacity(0.55))
                .padding(.top, 6)
                .padding(.leading, 2)

            ForEach(CourtSize.allCases) { size in
                Button {
                    courtSize = size
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: size.icon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(size.title)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                            Text(size.subtitle)
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        Spacer()
                        Text(size.priceLabel)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        Image(systemName: courtSize == size ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(courtSize == size ? HSColors.court : .white.opacity(0.4))
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(courtSize == size ? HSColors.court : Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func inputField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.45)))
            .font(.system(size: 15))
            .foregroundColor(.white)
            .padding(.horizontal, 14).frame(height: 50)
            .background(Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var canSubmit: Bool {
        !trimmed(businessName).isEmpty
            && !trimmed(ein).isEmpty
            && !trimmed(businessAddress).isEmpty
            && trimmed(businessEmail).contains("@")
            && !trimmed(managerFirstName).isEmpty
            && !trimmed(managerLastName).isEmpty
    }

    private var appleSignIn: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(
                onRequest: { request in
                    guard canSubmit else {
                        auth.errorMessage = "Fill in all gym details before signing in with Apple."
                        return
                    }
                    auth.errorMessage = nil
                    auth.setPendingGymRegistration(
                        AuthService.PendingGymRegistration(
                            businessName: trimmed(businessName),
                            ein: trimmed(ein),
                            businessAddress: trimmed(businessAddress),
                            businessEmail: trimmed(businessEmail).lowercased(),
                            managerFirstName: trimmed(managerFirstName),
                            managerLastName: trimmed(managerLastName),
                            courtSize: courtSize.rawValue
                        )
                    )
                    let nonce = auth.prepareAppleNonce()
                    request.requestedScopes = [.fullName, .email]
                    request.nonce = nonce
                },
                onCompletion: { result in
                    switch result {
                    case .success(let authResult):
                        if let credential = authResult.credential as? ASAuthorizationAppleIDCredential {
                            Task { await auth.completeSignInWithApple(credential: credential) }
                        }
                    case .failure(let error):
                        auth.setPendingGymRegistration(nil)
                        auth.failSignInWithApple(error)
                    }
                }
            )
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .opacity(canSubmit ? 1 : 0.5)
            .disabled(!canSubmit || auth.isLoading)
        }
    }

    private var blurb: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("7-DAY FREE TRIAL")
                    .font(.system(size: 10, weight: .heavy))
                    .kerning(1.2)
                    .foregroundColor(HSColors.navy)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(HSColors.court)
                    .clipShape(Capsule())
                Text("Then \(courtSize.priceLabel)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 2)

            Text("WHAT YOU CAN DO")
                .font(.system(size: 10, weight: .bold))
                .kerning(1.2)
                .foregroundColor(.white.opacity(0.55))
            bulletRow("Run ads on the Backboard feed")
            bulletRow("Post local articles in News")
            bulletRow("Cancel before day 7 to avoid being charged")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.06))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 8)
    }

    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(HSColors.court)
            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    private func trimmed(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

#Preview {
    NavigationStack {
        GymSignUpView().environmentObject(AuthService())
    }
}
