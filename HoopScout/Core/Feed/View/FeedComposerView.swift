//
//  FeedComposerView.swift
//  HoopScout
//

import SwiftUI

struct FeedComposerView: View {
    var onPost: (HSFeedPost) -> Void

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var draft: String = ""
    @State private var mood: HSFeedPost.Mood?
    @State private var markAsAd: Bool = false
    @State private var showPaywall = false
    @FocusState private var focused: Bool

    private var isGym: Bool { auth.profile?.isGym == true }
    private var hasActiveSub: Bool { auth.profile?.hasActiveGymSubscription == true }

    private var canPost: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            handle
            toolbar
            authorRow
            textArea
            if isGym {
                adToggle
                    .padding(.top, 10)
            }
            sectionLabel("How you feeling?")
                .padding(.top, 8)
            moodChips
            attachmentRow
                .padding(.top, 14)
                .overlay(
                    Rectangle().fill(HSColors.gray100).frame(height: 1),
                    alignment: .top
                )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 28)
        .background(Color.white)
        .onAppear { focused = true }
        .sheet(isPresented: $showPaywall) {
            GymPaywallView()
        }
    }

    private var adToggle: some View {
        Toggle(isOn: Binding(
            get: { markAsAd },
            set: { newValue in
                if newValue && !hasActiveSub {
                    showPaywall = true
                    return
                }
                markAsAd = newValue
            }
        )) {
            HStack(spacing: 8) {
                Text("AD")
                    .font(.system(size: 9, weight: .heavy))
                    .kerning(0.8)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(HSColors.court)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mark as sponsored")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text(hasActiveSub
                         ? "Adds an AD badge to your post"
                         : "Membership required")
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                }
            }
        }
        .tint(HSColors.navy)
    }

    // MARK: - Sections

    private var handle: some View {
        Capsule().fill(HSColors.gray200)
            .frame(width: 36, height: 4)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)
    }

    private var toolbar: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HSColors.gray500)
            Spacer()
            Text("New post")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(HSColors.gray900)
            Spacer()
            Button {
                guard canPost else { return }
                let post = makePost()
                onPost(post)
            } label: {
                Text("Post")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(canPost ? .white : HSColors.gray500)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(canPost ? HSColors.navy : HSColors.gray200)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!canPost)
        }
        .padding(.bottom, 14)
    }

    private var authorRow: some View {
        HStack(spacing: 10) {
            if let profile = auth.profile {
                HSAvatar(profile: profile, size: 36)
            } else {
                HSAvatar(uid: "guest", initials: "?", size: 36)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(auth.profile?.name ?? "You")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HSColors.gray900)
                if let mood {
                    HStack(spacing: 6) {
                        Circle().fill(mood.color).frame(width: 6, height: 6)
                        Text("feeling \(mood.label.lowercased())")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundColor(HSColors.gray500)
                    }
                }
            }
            Spacer()
        }
    }

    private var textArea: some View {
        TextEditor(text: $draft)
            .focused($focused)
            .font(.system(size: 15))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .frame(minHeight: 120)
            .padding(.top, 8)
            .overlay(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("Share a thought, a game, a feeling…")
                        .font(.system(size: 15))
                        .foregroundColor(HSColors.gray500)
                        .padding(.top, 16)
                        .padding(.leading, 4)
                        .allowsHitTesting(false)
                }
            }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .bold))
            .kerning(1.2)
            .foregroundColor(HSColors.gray500)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var moodChips: some View {
        let columns = [
            GridItem(.adaptive(minimum: 110), spacing: 8)
        ]
        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(HSFeedMock.composerMoods, id: \.label) { m in
                let active = mood?.label == m.label
                Button { mood = active ? nil : m } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(active ? Color.white : m.color)
                            .frame(width: 6, height: 6)
                        Text(m.label)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(active ? .white : HSColors.gray700)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 7)
                    .background(active ? m.color : Color.white)
                    .overlay(
                        Capsule().stroke(active ? Color.clear : HSColors.gray200, lineWidth: 1)
                    )
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 8)
    }

    private var attachmentRow: some View {
        HStack(spacing: 10) {
            attachmentButton(label: "Court", systemImage: "mappin.and.ellipse")
            attachmentButton(label: "Game", systemImage: "list.bullet.rectangle")
            attachmentButton(label: "Photo", systemImage: "photo")
        }
        .padding(.top, 12)
    }

    private func attachmentButton(label: String, systemImage: String) -> some View {
        Button {} label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(HSColors.navy)
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(HSColors.gray700)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 10)
            .background(HSColors.gray50)
            .overlay(
                RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray100, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    private func makePost() -> HSFeedPost {
        HSFeedPost(
            id: UUID().uuidString,
            authorId: auth.profile?.id ?? "me",
            time: "now",
            kind: .text,
            body: draft.trimmingCharacters(in: .whitespacesAndNewlines),
            mood: mood ?? HSFeedMock.composerMoods[0],
            likes: 0,
            comments: 0,
            attachment: nil,
            createdAt: Date(),
            isAd: (isGym && markAsAd) ? true : nil
        )
    }
}
