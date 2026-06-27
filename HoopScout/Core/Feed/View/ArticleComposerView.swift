//
//  ArticleComposerView.swift
//  HoopScout
//
//  Gym-only composer for posting a local article that shows up in the
//  News tab of the feed.
//

import SwiftUI

struct ArticleComposerView: View {
    var onPost: (HSArticle) -> Void

    /// Reject anything that isn't an http/https URL with a non-empty host.
    /// Blocks `javascript:`, `data:`, `file:`, custom schemes, and links
    /// that parse but don't actually resolve.
    static func safeURL(from raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed) else { return nil }
        guard let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else { return nil }
        guard let host = url.host, !host.isEmpty else { return nil }
        return url
    }

    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var bodyText: String = ""
    @State private var link: String = ""
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    private var canPost: Bool {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !cleanTitle.isEmpty && !cleanBody.isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sectionLabel("HEADLINE")
                    titleField

                    sectionLabel("STORY")
                    bodyField

                    sectionLabel("LINK (OPTIONAL)")
                    linkField

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 13))
                            .foregroundColor(.red)
                            .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(HSColors.bg)
            .navigationTitle("Post Article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HSColors.gray500)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        post()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Post")
                                .fontWeight(.bold)
                                .foregroundColor(canPost ? HSColors.navy : HSColors.gray500)
                        }
                    }
                    .disabled(!canPost || isSaving)
                }
            }
            .onAppear { titleFocused = true }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .kerning(1.2)
            .foregroundColor(HSColors.gray500)
    }

    private var titleField: some View {
        TextField("Headline", text: $title, axis: .vertical)
            .focused($titleFocused)
            .font(.system(size: 18, weight: .heavy))
            .foregroundColor(HSColors.gray900)
            .lineLimit(1...3)
            .padding(14)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var bodyField: some View {
        TextEditor(text: $bodyText)
            .font(.system(size: 14.5))
            .foregroundColor(HSColors.gray900)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 220)
            .padding(10)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topLeading) {
                if bodyText.isEmpty {
                    Text("Tell hoopers what's happening at your gym…")
                        .font(.system(size: 14.5))
                        .foregroundColor(HSColors.gray500)
                        .padding(.top, 18)
                        .padding(.leading, 16)
                        .allowsHitTesting(false)
                }
            }
    }

    private var linkField: some View {
        TextField("https://", text: $link)
            .font(.system(size: 14))
            .foregroundColor(HSColors.gray900)
            .keyboardType(.URL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .padding(14)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func post() {
        guard let author = auth.profile, author.isGym, let authorId = author.id else {
            errorMessage = "Only gym accounts can post articles."
            return
        }
        guard author.hasActiveGymSubscription else {
            errorMessage = "Your gym membership has expired. Renew to post articles."
            return
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanBody = bodyText.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLink = link.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = Self.safeURL(from: cleanLink)
        if !cleanLink.isEmpty && url == nil {
            errorMessage = "Link must be a valid https:// or http:// URL."
            return
        }

        let article = HSArticle(
            authorId: authorId,
            authorName: author.businessName ?? author.name,
            title: cleanTitle,
            body: cleanBody,
            url: url
        )

        errorMessage = nil
        isSaving = true
        Task {
            do {
                try await ArticleRepository.shared.add(article: article, author: author)
                await MainActor.run {
                    isSaving = false
                    onPost(article)
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

#Preview {
    ArticleComposerView { _ in }
        .environmentObject(AuthService())
}
