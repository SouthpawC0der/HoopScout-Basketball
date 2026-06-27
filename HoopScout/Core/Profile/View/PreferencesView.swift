//
//  PreferencesView.swift
//  HoopScout
//

import SwiftUI

struct PreferencesView: View {
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var position: String = ""
    @State private var education: String = ""
    @State private var instagram: String = ""
    @State private var twitter: String = ""
    @State private var tiktok: String = ""
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var showSwitchAccountConfirm = false
    @State private var didLoad = false
    @State private var showDeleteConfirm = false
    @State private var showReauthRequired = false
    @State private var deleting = false

    private let positions = ["Point Guard", "Shooting Guard", "Small Forward",
                             "Power Forward", "Center"]
    private let educations = ["High School", "College"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    section("Position") {
                        Picker("Position", selection: $position) {
                            Text("Not set").tag("")
                            ForEach(positions, id: \.self) { p in
                                Text(p).tag(p)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(HSColors.navy)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12).frame(height: 44)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray200, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    section("Education") {
                        Picker("Education", selection: $education) {
                            Text("Not set").tag("")
                            ForEach(educations, id: \.self) { e in
                                Text(e).tag(e)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    section("Connect social media") {
                        socialField(icon: "camera.fill", label: "Instagram", placeholder: "@handle", text: $instagram)
                        socialField(icon: "bird.fill", label: "X / Twitter", placeholder: "@handle", text: $twitter)
                        socialField(icon: "music.note", label: "TikTok", placeholder: "@handle", text: $tiktok)
                    }

                    section("Account") {
                        Button {
                            showSwitchAccountConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .foregroundColor(HSColors.navy)
                                Text("Switch account")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(HSColors.gray900)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(HSColors.gray300)
                            }
                            .padding(.horizontal, 14).frame(height: 48)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray200, lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showDeleteConfirm = true
                        } label: {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text(deleting ? "Deleting…" : "Delete account")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                                Spacer()
                                if deleting {
                                    ProgressView().tint(.red)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(HSColors.gray300)
                                }
                            }
                            .padding(.horizontal, 14).frame(height: 48)
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.red.opacity(0.25), lineWidth: 1))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .disabled(deleting)

                        Text("Deletes your profile, posts, ratings, and check-ins. This can't be undone.")
                            .font(.system(size: 11))
                            .foregroundColor(HSColors.gray500)
                            .padding(.horizontal, 4)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.85))
                    }
                }
                .padding(20)
            }
            .background(HSColors.bg.ignoresSafeArea())
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HSColors.gray500)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(saving ? "Saving…" : "Save") {
                        Task { await save() }
                    }
                    .foregroundColor(HSColors.navy)
                    .fontWeight(.bold)
                    .disabled(saving)
                }
            }
            .onAppear { loadFromAuthIfNeeded() }
            .confirmationDialog("Sign out and switch?",
                                isPresented: $showSwitchAccountConfirm,
                                titleVisibility: .visible) {
                Button("Sign out", role: .destructive) {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll be returned to the sign-in screen.")
            }
            .alert("Delete your account?",
                   isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete forever", role: .destructive) {
                    Task { await performDelete() }
                }
            } message: {
                Text("This permanently removes your profile, posts, ratings, check-ins, and messages. This cannot be undone.")
            }
            .alert("Sign in again to delete",
                   isPresented: $showReauthRequired) {
                Button("Sign out and re-sign in") {
                    auth.signOut()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("For your security, Apple requires a recent sign-in before account deletion. Sign out, sign back in, then try again.")
            }
        }
    }

    private func performDelete() async {
        deleting = true
        defer { deleting = false }
        let result = await auth.deleteAccount()
        switch result {
        case .success:
            dismiss()
        case .requiresRecentLogin:
            showReauthRequired = true
        case .failed(let message):
            errorMessage = message
        }
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
                .padding(.leading, 4)
            VStack(spacing: 10) { content() }
        }
    }

    private func socialField(icon: String, label: String,
                             placeholder: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HSColors.navy)
                .frame(width: 30, height: 30)
                .background(HSColors.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11, weight: .bold)).foregroundColor(HSColors.gray500)
                TextField(placeholder, text: text)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
        }
        .padding(.horizontal, 12).frame(height: 56)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray200, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Actions

    private func loadFromAuthIfNeeded() {
        guard !didLoad, let p = auth.profile else { return }
        position = p.position ?? ""
        education = p.education ?? ""
        instagram = p.socials?["instagram"] ?? ""
        twitter = p.socials?["twitter"] ?? ""
        tiktok = p.socials?["tiktok"] ?? ""
        didLoad = true
    }

    private func save() async {
        guard var profile = auth.profile else {
            errorMessage = "Sign in required."
            return
        }
        saving = true
        defer { saving = false }
        profile.position = position.isEmpty ? nil : position
        profile.education = education.isEmpty ? nil : education
        var socials: [String: String] = [:]
        let ig = instagram.trimmingCharacters(in: .whitespacesAndNewlines)
        let tw = twitter.trimmingCharacters(in: .whitespacesAndNewlines)
        let tt = tiktok.trimmingCharacters(in: .whitespacesAndNewlines)
        if !ig.isEmpty { socials["instagram"] = ig }
        if !tw.isEmpty { socials["twitter"] = tw }
        if !tt.isEmpty { socials["tiktok"] = tt }
        profile.socials = socials.isEmpty ? nil : socials

        do {
            try await UserRepository.shared.update(profile)
            auth.applyLocalProfileUpdate(profile)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    PreferencesView().environmentObject(AuthService())
}
