//
//  HamburgerMenuScreens.swift
//  HoopScout
//
//  Scaffolded destination views reachable from the Feed hamburger menu.
//  These ship as placeholder UI until each feature is fully implemented.
//

import SwiftUI

// MARK: - Saved Highlights

struct SavedHighlightsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComingSoonScaffold(
            icon: "bookmark.fill",
            title: "Saved Highlights",
            blurb: "Bookmark highlights from the feed and revisit them here. You'll see your saved clips lined up in a grid."
        )
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
    }
}

// MARK: - Ad Payments

struct AdPaymentsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComingSoonScaffold(
            icon: "dollarsign.circle.fill",
            title: "Ad Payments",
            blurb: "Get paid when brands sponsor your highlights and posts. We'll roll this out alongside our creator program."
        )
        .navigationTitle("Ad Payments")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
    }
}

// MARK: - Account Privacy

struct AccountPrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthService
    @State private var isPrivate: Bool = false
    @State private var isSaving: Bool = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: privateBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Private Account")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                        Text(isPrivate ? "Only approved hoopers can see your runs and highlights."
                                       : "Anyone can see your runs and highlights.")
                            .font(.system(size: 12))
                            .foregroundColor(HSColors.gray500)
                    }
                }
                .tint(HSColors.navy)
                .disabled(isSaving || auth.profile?.id == nil)
            } header: {
                HStack {
                    Text("Privacy")
                    if isSaving {
                        Spacer()
                        ProgressView().scaleEffect(0.7)
                    }
                }
            } footer: {
                if let errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                } else if auth.profile?.id == nil {
                    Text("Sign in to change your privacy settings.")
                } else {
                    Text("Changes sync to your profile across all devices.")
                }
            }
        }
        .navigationTitle("Account Privacy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
        .onAppear { isPrivate = auth.profile?.isPrivate ?? false }
        .onChange(of: auth.profile?.isPrivate) { _, newValue in
            if !isSaving { isPrivate = newValue ?? false }
        }
    }

    private var privateBinding: Binding<Bool> {
        Binding(
            get: { isPrivate },
            set: { newValue in
                guard let uid = auth.profile?.id else { return }
                isPrivate = newValue
                save(newValue, uid: uid)
            }
        )
    }

    private func save(_ newValue: Bool, uid: String) {
        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await UserRepository.shared.setPrivacy(isPrivate: newValue, uid: uid)
                await MainActor.run { isSaving = false }
            } catch {
                await MainActor.run {
                    isSaving = false
                    isPrivate = !newValue
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Teams

struct TeamsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ComingSoonScaffold(
            icon: "person.3.fill",
            title: "Teams",
            blurb: "Pick your top 5 teammates — like top friends, but for hoopers. They'll show on your profile and get priority in your feed."
        )
        .navigationTitle("Teams")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
    }
}

// MARK: - Blocked

struct BlockedView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var blocks: BlockRepository

    var body: some View {
        Group {
            if blocks.blockedIds.isEmpty {
                ComingSoonScaffold(
                    icon: "nosign",
                    title: "No blocked hoopers",
                    blurb: "Hoopers you block won't be able to see your posts or message you. They'll appear here."
                )
            } else {
                List {
                    Section {
                        ForEach(Array(blocks.blockedIds), id: \.self) { uid in
                            HStack(spacing: 12) {
                                HSAvatar(uid: uid, initials: "·", size: 36)
                                Text(uid)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(HSColors.gray900)
                                    .lineLimit(1)
                                Spacer()
                            }
                        }
                    } footer: {
                        Text("Tap a hooper's profile to unblock them.")
                    }
                }
            }
        }
        .navigationTitle("Blocked")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
    }
}

// MARK: - Invite Hoopers

struct InviteHoopersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showShare = false

    private let inviteText = "Come hoop with me on HoopScout — find runs, rate courts, and post highlights. https://hoopscoutapp.com"

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "paperplane.fill")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(HSColors.navy)

            VStack(spacing: 8) {
                Text("Invite hoopers")
                    .font(.system(size: 22, weight: .heavy))
                    .foregroundColor(HSColors.gray900)
                Text("Pull more runs to your area. The more hoopers, the better the games.")
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray500)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                showShare = true
            } label: {
                Text("Share invite")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(HSColors.navy)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 32)

            Spacer()
        }
        .navigationTitle("Invite")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [inviteText])
        }
    }
}

// MARK: - About

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(version)
                        .foregroundColor(HSColors.gray500)
                }
            }

            Section("Legal") {
                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    Text("Privacy Policy")
                }
                NavigationLink {
                    TermsOfServiceView()
                } label: {
                    Text("Terms of Service")
                }
            }

            Section {
                Text("HoopScout helps you find runs, rate courts, share highlights, and connect with hoopers in your area.")
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray500)
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { closeButton(dismiss: dismiss) }
    }
}

// MARK: - Shared scaffolding

private struct ComingSoonScaffold: View {
    let icon: String
    let title: String
    let blurb: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 52, weight: .semibold))
                .foregroundColor(HSColors.navy)
            Text(title)
                .font(.system(size: 22, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(blurb)
                .font(.system(size: 14))
                .foregroundColor(HSColors.gray500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Text("Coming soon")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(HSColors.gray100)
                .clipShape(Capsule())
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HSColors.bg)
    }
}

@ToolbarContentBuilder
private func closeButton(dismiss: DismissAction) -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) {
        Button("Close") { dismiss() }
            .foregroundColor(HSColors.navy)
    }
}

// MARK: - Share sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
