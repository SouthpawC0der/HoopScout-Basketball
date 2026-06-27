//
//  FeedCommentsView.swift
//  HoopScout
//
//  Shows all comments on a post with one level of replies. Users can like
//  a comment, reply to a comment, and post a new top-level comment.
//

import SwiftUI

struct FeedCommentsView: View {
    let post: HSFeedPost

    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var blocks: BlockRepository
    @Environment(\.dismiss) private var dismiss

    @State private var comments: [HSFeedComment] = []
    @State private var likedComments: Set<String> = []
    @State private var draft: String = ""
    @State private var replyingTo: HSFeedComment?
    @State private var reportingComment: HSFeedComment?
    @State private var reportSubmitted = false
    @State private var blockTarget: (uid: String, name: String)?
    @FocusState private var focused: Bool

    private var visibleComments: [HSFeedComment] {
        comments.filter { !blocks.isBlocked($0.authorId) }
    }

    private var topLevel: [HSFeedComment] {
        visibleComments.filter { $0.parentId == nil }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                postSummary
                Divider().background(HSColors.gray100)
                list
                composer
            }
            .background(HSColors.bg.ignoresSafeArea())
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(HSColors.navy)
                }
            }
            .navigationDestination(for: HSUserProfile.self) { profile in
                FriendProfileView(user: profile)
            }
            .sheet(item: $reportingComment) { comment in
                if let reporterUid = auth.profile?.id {
                    ReportSheet(
                        entity: .comment,
                        entityId: comment.id,
                        reportedUid: comment.authorId,
                        reporterUid: reporterUid,
                        subjectLabel: "comment",
                        onSubmitted: { reportSubmitted = true }
                    )
                }
            }
            .alert("Report submitted", isPresented: $reportSubmitted) {
                Button("OK") {}
            } message: {
                Text("Thanks — we'll review this within 24 hours.")
            }
            .confirmationDialog(
                blockTarget.map { "Block \($0.name)?" } ?? "Block?",
                isPresented: Binding(
                    get: { blockTarget != nil },
                    set: { if !$0 { blockTarget = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Block", role: .destructive) {
                    if let uid = blockTarget?.uid {
                        Task { try? await BlockRepository.shared.block(uid) }
                    }
                    blockTarget = nil
                }
                Button("Cancel", role: .cancel) { blockTarget = nil }
            } message: {
                Text("You won't see their posts, comments, or messages.")
            }
        }
        .onAppear {
            comments = HSFeedMock.comments.filter { $0.postId == post.id }
        }
    }

    // MARK: - Sections

    private var postSummary: some View {
        let author = HSMockData.friend(id: post.authorId)
        return HStack(alignment: .top, spacing: 10) {
            if let author {
                HSAvatar(friend: author, size: 36)
            } else {
                HSAvatar(uid: post.authorId, initials: "?", size: 36)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(author?.name ?? "Hooper")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text("· \(post.time)")
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                }
                Text(post.body)
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray700)
                    .lineLimit(3)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color.white)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if topLevel.isEmpty {
                    emptyState
                } else {
                    ForEach(topLevel) { comment in
                        commentTree(comment)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 14)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bubble.left")
                .font(.system(size: 24))
                .foregroundColor(HSColors.gray300)
            Text("No comments yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(HSColors.gray900)
            Text("Be the first to share a take.")
                .font(.system(size: 12))
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func commentTree(_ comment: HSFeedComment) -> some View {
        let replies = visibleComments.filter { $0.parentId == comment.id }
        return VStack(alignment: .leading, spacing: 10) {
            commentRow(comment)
            if !replies.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(replies) { reply in
                        commentRow(reply)
                    }
                }
                .padding(.leading, 44)
            }
        }
    }

    private func commentRow(_ comment: HSFeedComment) -> some View {
        let author = HSMockData.friend(id: comment.authorId)
        let isLiked = likedComments.contains(comment.id)
        return HStack(alignment: .top, spacing: 10) {
            if let author, let profile = HSMockData.userProfile(forFriendId: author.id) {
                NavigationLink(value: profile) {
                    HSAvatar(friend: author, size: 32)
                }
                .buttonStyle(.plain)
            } else {
                HSAvatar(uid: comment.authorId, initials: "?", size: 32)
            }
            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        if let author, let profile = HSMockData.userProfile(forFriendId: author.id) {
                            NavigationLink(value: profile) {
                                Text(author.name)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(HSColors.gray900)
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text(author?.name ?? "Hooper")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(HSColors.gray900)
                        }
                        Text("· \(comment.time)")
                            .font(.system(size: 11))
                            .foregroundColor(HSColors.gray500)
                    }
                    Text(comment.body)
                        .font(.system(size: 14))
                        .foregroundColor(HSColors.gray900)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 11).padding(.vertical, 9)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(HSColors.gray200, lineWidth: 1)
                )

                HStack(spacing: 14) {
                    Button {
                        toggleLike(comment.id)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: isLiked ? "heart.fill" : "heart")
                                .font(.system(size: 12, weight: .semibold))
                            Text("\(effectiveLikes(comment))")
                                .font(.system(size: 11.5, weight: .semibold))
                        }
                        .foregroundColor(isLiked ? HSColors.court : HSColors.gray500)
                    }
                    .buttonStyle(.plain)

                    if comment.parentId == nil {
                        Button { startReply(to: comment) } label: {
                            Text("Reply")
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundColor(HSColors.gray500)
                        }
                        .buttonStyle(.plain)
                    }

                    if comment.authorId != auth.profile?.id {
                        Menu {
                            Button(role: .destructive) {
                                reportingComment = comment
                            } label: {
                                Label("Report comment", systemImage: "flag")
                            }
                            Button(role: .destructive) {
                                blockTarget = (comment.authorId, author?.name ?? "this hooper")
                            } label: {
                                Label("Block \(author?.name ?? "user")", systemImage: "hand.raised")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(HSColors.gray500)
                        }
                    }
                }
                .padding(.leading, 4)
            }
            Spacer(minLength: 0)
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            if let replying = replyingTo {
                HStack(spacing: 6) {
                    Image(systemName: "arrowshape.turn.up.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Replying to \(HSMockData.friend(id: replying.authorId)?.name ?? "Hooper")")
                        .font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Button { replyingTo = nil } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(HSColors.gray300)
                    }
                    .buttonStyle(.plain)
                }
                .foregroundColor(HSColors.gray500)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(HSColors.gray100)
            }
            HStack(spacing: 8) {
                if let profile = auth.profile {
                    HSAvatar(profile: profile, size: 30)
                } else {
                    HSAvatar(uid: "guest", initials: "?", size: 30)
                }
                HStack(spacing: 6) {
                    TextField(replyingTo == nil ? "Add a comment…" : "Write a reply…",
                              text: $draft, axis: .vertical)
                        .lineLimit(1...4)
                        .focused($focused)
                        .font(.system(size: 14))
                        .padding(.leading, 12)
                    Button(action: submitComment) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(canPost ? HSColors.navy : HSColors.gray300)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canPost)
                    .padding(.trailing, 5)
                }
                .frame(minHeight: 38)
                .background(HSColors.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
            }
            .padding(.horizontal, 12).padding(.top, 8).padding(.bottom, 12)
            .background(Color.white)
            .overlay(Rectangle().fill(HSColors.gray200).frame(height: 1),
                     alignment: .top)
        }
    }

    // MARK: - Actions

    private var canPost: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func effectiveLikes(_ comment: HSFeedComment) -> Int {
        let bump = likedComments.contains(comment.id) ? 1 : 0
        return comment.likes + bump
    }

    private func toggleLike(_ id: String) {
        if likedComments.contains(id) { likedComments.remove(id) }
        else { likedComments.insert(id) }
    }

    private func startReply(to comment: HSFeedComment) {
        replyingTo = comment
        focused = true
    }

    private func submitComment() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newComment = HSFeedComment(
            id: UUID().uuidString,
            postId: post.id,
            authorId: auth.profile?.id ?? "me",
            time: "now",
            body: trimmed,
            likes: 0,
            parentId: replyingTo?.id
        )
        comments.append(newComment)
        draft = ""
        replyingTo = nil
    }
}
