//
//  FeedPostCard.swift
//  HoopScout
//

import SwiftUI

struct FeedPostCard: View {
    let post: HSFeedPost
    let liked: Bool
    var onToggleLike: () -> Void

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var blocks: BlockRepository
    @State private var showComments = false
    @State private var showReport = false
    @State private var reportSubmitted = false
    @State private var showBlockConfirm = false

    private var author: HSFriend? {
        HSMockData.friend(id: post.authorId)
    }

    /// True when the signed-in user authored this post.
    private var isSelfAuthor: Bool {
        guard let myId = auth.profile?.id else { return false }
        return post.authorId == myId
    }

    /// What name to render in the header. Prefers the signed-in user's name
    /// when they wrote the post, then the name captured at post time by
    /// FeedRepository, then the mock-friend lookup, then a generic fallback.
    private var authorName: String {
        if isSelfAuthor, let me = auth.profile { return me.name }
        if let name = post.authorName, !name.isEmpty { return name }
        return author?.name ?? "Hooper"
    }

    private var authorInitialsFallback: String {
        if let initials = post.authorInitials, !initials.isEmpty { return initials }
        return "?"
    }

    private var likeCount: Int { post.likes }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            Text(post.body)
                .font(.system(size: 14.5))
                .foregroundColor(HSColors.gray900)
                .lineSpacing(3)
                .padding(.top, 12)

            if let attachment = post.attachment {
                attachmentView(attachment)
                    .padding(.top, 12)
            }

            actionsRow
                .padding(.top, 14)
                .padding(.top, 12)
                .overlay(
                    Rectangle().fill(HSColors.gray100).frame(height: 1),
                    alignment: .top
                )
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(HSColors.line, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .sheet(isPresented: $showComments) {
            FeedCommentsView(post: post)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showReport) {
            if let reporterUid = auth.profile?.id {
                ReportSheet(
                    entity: .post,
                    entityId: post.id,
                    reportedUid: post.authorId,
                    reporterUid: reporterUid,
                    subjectLabel: "post",
                    onSubmitted: { reportSubmitted = true }
                )
            }
        }
        .alert("Report submitted", isPresented: $reportSubmitted) {
            Button("OK") {}
        } message: {
            Text("Thanks — we'll review this within 24 hours.")
        }
        .confirmationDialog("Block \(authorName)?",
                            isPresented: $showBlockConfirm,
                            titleVisibility: .visible) {
            Button("Block", role: .destructive) {
                Task { try? await BlockRepository.shared.block(post.authorId) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You won't see their posts, comments, or messages.")
        }
    }

    // MARK: - Header

    private var authorProfile: HSUserProfile? {
        if isSelfAuthor { return auth.profile }
        return HSMockData.userProfile(forFriendId: post.authorId)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .center, spacing: 10) {
            authorLink {
                if isSelfAuthor, let me = auth.profile {
                    HSAvatar(profile: me, size: 40)
                } else if let author {
                    HSAvatar(friend: author, size: 40)
                } else {
                    HSAvatar(uid: post.authorId, initials: authorInitialsFallback, size: 40)
                }
            }
            authorLink {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(authorName)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                        if post.isAd == true {
                            Text("AD")
                                .font(.system(size: 9, weight: .heavy))
                                .kerning(0.8)
                                .foregroundColor(.white)
                                .padding(.horizontal, 5).padding(.vertical, 1.5)
                                .background(HSColors.court)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                        Circle().fill(HSColors.gray300).frame(width: 3, height: 3)
                        Text(post.time)
                            .font(.system(size: 12))
                            .foregroundColor(HSColors.gray500)
                    }
                    HStack(spacing: 6) {
                        if post.isAd == true {
                            Text("Sponsored")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(HSColors.gray500)
                        } else {
                            Circle().fill(post.mood.color).frame(width: 6, height: 6)
                            Text("feeling \(post.mood.label.lowercased())")
                                .font(.system(size: 11.5, weight: .semibold))
                                .kerning(0.2)
                                .foregroundColor(HSColors.gray500)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            Menu {
                if !isSelfAuthor {
                    Button(role: .destructive) { showReport = true } label: {
                        Label("Report post", systemImage: "flag")
                    }
                    Button(role: .destructive) { showBlockConfirm = true } label: {
                        Label("Block \(authorName)", systemImage: "hand.raised")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.gray500)
                    .padding(4)
            }
        }
    }

    @ViewBuilder
    private func authorLink<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if let profile = authorProfile {
            NavigationLink(value: profile) { content() }
                .buttonStyle(.plain)
        } else {
            content()
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    private func attachmentView(_ attachment: HSFeedPost.Attachment) -> some View {
        switch attachment {
        case .stat(let label, let rows):
            statCard(label: label, rows: rows)
        case .court(let courtId, let variant):
            courtCard(courtId: courtId, variant: variant)
        }
    }

    private func statCard(label: String, rows: [HSFeedPost.StatRow]) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Image(systemName: "circle.grid.cross")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            .background(Color.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 6) {
                Text(label.uppercased())
                    .font(.system(size: 10.5, weight: .bold))
                    .kerning(1.2)
                    .foregroundColor(Color.white.opacity(0.7))
                HStack(alignment: .top, spacing: 18) {
                    ForEach(rows, id: \.self) { row in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(row.value)
                                .font(.system(size: 18, weight: .heavy))
                                .kerning(-0.5)
                                .foregroundColor(.white)
                            Text(row.label.uppercased())
                                .font(.system(size: 10, weight: .semibold))
                                .kerning(0.4)
                                .foregroundColor(Color.white.opacity(0.6))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(HSColors.navy)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func courtCard(courtId: String, variant: HSCourtImageVariant) -> some View {
        let courtName = HSMockData.court(id: courtId)?.name ?? "Tagged court"
        return ZStack(alignment: .bottomLeading) {
            HSCourtImage(variant: variant, height: 150, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text("TAGGED COURT")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(0.8)
                    .foregroundColor(.white.opacity(0.75))
                Text(courtName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial.opacity(0.9))
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(12)
        }
    }

    // MARK: - Actions

    private var actionsRow: some View {
        HStack(spacing: 18) {
            Button(action: onToggleLike) {
                HStack(spacing: 6) {
                    Image(systemName: liked ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(liked ? HSColors.court : HSColors.gray700)
                    Text("\(likeCount)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(liked ? HSColors.court : HSColors.gray700)
                }
            }
            .buttonStyle(.plain)

            Button { showComments = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left")
                        .font(.system(size: 16, weight: .semibold))
                    Text("\(post.comments)")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(HSColors.gray700)
            }
            .buttonStyle(.plain)

            Spacer()

            Button {} label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(HSColors.gray700)
            }
            .buttonStyle(.plain)
        }
    }
}
