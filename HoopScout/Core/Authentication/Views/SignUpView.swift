//
//  SignUpView.swift
//  HoopScout
//
//  Dedicated create-account screen. Collects first/last name, email +
//  email confirmation, on-court position, and a password (required by
//  Firebase Auth), then hands off to AuthService.signUp.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var confirmEmail = ""
    @State private var password = ""
    @State private var position: Position = .pointGuard
    @State private var showPositionPicker = false

    enum Position: String, CaseIterable, Identifiable {
        case pointGuard = "Point Guard"
        case shootingGuard = "Shooting Guard"
        case smallForward = "Small Forward"
        case powerForward = "Power Forward"
        case center = "Center"
        var id: String { rawValue }
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
                VStack(spacing: 24) {
                    header
                    fields
                    cta
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
        .confirmationDialog("Position", isPresented: $showPositionPicker, titleVisibility: .visible) {
            ForEach(Position.allCases) { p in
                Button(p.rawValue) { position = p }
            }
            Button("Cancel", role: .cancel) { }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            HSLogo(size: 56, light: true)
            Text("HoopScout")
                .font(.system(size: 13, weight: .semibold))
                .kerning(3)
                .textCase(.uppercase)
                .foregroundColor(.white.opacity(0.55))
            Text("Create your account")
                .font(.system(size: 26, weight: .heavy))
                .kerning(-0.6)
                .foregroundColor(.white)
                .padding(.top, 4)
        }
    }

    private var fields: some View {
        VStack(spacing: 10) {
            inputField("First name", text: $firstName)
                .textContentType(.givenName)
                .textInputAutocapitalization(.words)
            inputField("Last name", text: $lastName)
                .textContentType(.familyName)
                .textInputAutocapitalization(.words)
            inputField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            positionRow
            inputField("Confirm email address", text: $confirmEmail)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            secureField("Password", text: $password)
                .textContentType(.newPassword)
        }
    }

    private var positionRow: some View {
        Button {
            showPositionPicker = true
        } label: {
            HStack {
                Text(position.rawValue)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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

    private func secureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField("", text: text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.45)))
            .font(.system(size: 15))
            .foregroundColor(.white)
            .padding(.horizontal, 14).frame(height: 50)
            .background(Color.white.opacity(0.08))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.12), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cta: some View {
        Button {
            Task {
                await auth.signUp(
                    firstName: firstName,
                    lastName: lastName,
                    email: email,
                    confirmEmail: confirmEmail,
                    password: password,
                    position: position.rawValue
                )
            }
        } label: {
            HStack {
                if auth.isLoading {
                    ProgressView().tint(HSColors.navy)
                } else {
                    Text("Create Account")
                        .font(.system(size: 16, weight: .bold))
                        .kerning(-0.2)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 54)
            .background(Color.white)
            .foregroundColor(HSColors.navy)
            .clipShape(Capsule())
            .shadow(color: .white.opacity(0.18), radius: 18, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading || !canSubmit)
        .opacity(canSubmit ? 1 : 0.5)
    }

    private var canSubmit: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !lastName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && email.contains("@")
            && email.caseInsensitiveCompare(confirmEmail) == .orderedSame
            && password.count >= 6
    }
}

#Preview {
    NavigationStack {
        SignUpView().environmentObject(AuthService())
    }
}
