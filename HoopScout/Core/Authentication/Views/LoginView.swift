//
//  LoginView.swift
//  HoopScout
//

import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @EnvironmentObject private var auth: AuthService

    enum Mode { case signIn, signUp }
    @State private var mode: Mode = .signIn
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""

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
                    VStack(spacing: 14) {
                        HSLogo(size: 56, light: true)
                        Text("HoopScout")
                            .font(.system(size: 13, weight: .semibold))
                            .kerning(3)
                            .textCase(.uppercase)
                            .foregroundColor(.white.opacity(0.55))
                    }
                    .padding(.top, 60)

                    Text(mode == .signIn ? "Welcome back" : "Create your account")
                        .font(.system(size: 26, weight: .heavy))
                        .kerning(-0.6)
                        .foregroundColor(.white)

                    fields
                    cta
                    orDivider
                    appleSignIn
                    googleSignIn
                    switcher
                    if mode == .signIn { forgotPassword }
                    if let err = auth.errorMessage {
                        Text(err).font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    Spacer(minLength: 30)
                }
                .padding(.horizontal, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var fields: some View {
        VStack(spacing: 10) {
            if mode == .signUp {
                inputField("Full name", text: $name)
                    .textContentType(.name)
            }
            inputField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            secureField("Password", text: $password)
                .textContentType(mode == .signIn ? .password : .newPassword)
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
                if mode == .signIn { await auth.signIn(email: email, password: password) }
                else { await auth.signUp(email: email, password: password, name: name) }
            }
        } label: {
            HStack {
                if auth.isLoading {
                    ProgressView().tint(HSColors.navy)
                } else {
                    Text(mode == .signIn ? "Sign in" : "Create account")
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
        !email.isEmpty && password.count >= 6 && (mode == .signIn || !name.isEmpty)
    }

    private var switcher: some View {
        HStack(spacing: 4) {
            Text(mode == .signIn ? "Don't have an account?" : "Already have one?")
                .foregroundColor(.white.opacity(0.5))
            Button(mode == .signIn ? "Sign up" : "Sign in") {
                withAnimation { mode = (mode == .signIn) ? .signUp : .signIn }
                auth.errorMessage = nil
            }
            .foregroundColor(.white)
            .fontWeight(.semibold)
        }
        .font(.system(size: 13))
    }

    private var forgotPassword: some View {
        Button("Forgot password?") {
            Task { await auth.sendPasswordReset(email: email) }
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.white.opacity(0.7))
    }

    private var orDivider: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
            Text("OR").font(.system(size: 11, weight: .bold)).kerning(1.5)
                .foregroundColor(.white.opacity(0.45))
            Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1)
        }
        .padding(.top, 6)
    }

    private var googleSignIn: some View {
        Button {
            Task { await auth.signInWithGoogle() }
        } label: {
            HStack(spacing: 10) {
                googleGlyph
                Text("Sign in with Google")
                    .font(.system(size: 16, weight: .semibold))
                    .kerning(-0.2)
                    .foregroundColor(Color(red: 0.137, green: 0.157, blue: 0.180))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.white)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Color.black.opacity(0.08), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(auth.isLoading)
        .opacity(auth.isLoading ? 0.6 : 1)
    }

    /// Multi-color Google "G" mark drawn with shapes (no asset needed).
    private var googleGlyph: some View {
        ZStack {
            Image(systemName: "g.circle.fill")
                .resizable()
                .frame(width: 20, height: 20)
                .foregroundStyle(
                    LinearGradient(colors: [
                        Color(red: 0.918, green: 0.263, blue: 0.208),
                        Color(red: 0.984, green: 0.737, blue: 0.020),
                        Color(red: 0.204, green: 0.659, blue: 0.325),
                        Color(red: 0.259, green: 0.522, blue: 0.957)
                    ], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
        }
    }

    private var appleSignIn: some View {
        SignInWithAppleButton(
            onRequest: { request in
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
                    auth.failSignInWithApple(error)
                }
            }
        )
        .signInWithAppleButtonStyle(.white)
        .frame(height: 54)
        .clipShape(Capsule())
    }
}

#Preview {
    LoginView().environmentObject(AuthService())
}
