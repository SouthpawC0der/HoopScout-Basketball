//
//  MessageThreadView.swift
//  HoopScout
//

import SwiftUI

struct MessageThreadView: View {
    let thread: HSThreadDoc
    @EnvironmentObject private var auth: AuthService

    @State private var messages: [HSMessageDoc] = []
    @State private var draft: String = ""
    @State private var observeTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss

    private var currentUid: String? { auth.profile?.id }
    private var threadId: String { thread.id ?? "" }
    private var otherUid: String { thread.otherUid(currentUid: currentUid ?? "") ?? "" }
    private var other: HSThreadDoc.ThreadParticipant? {
        thread.otherInfo(currentUid: currentUid ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            composer
        }
        .background(HSColors.bg)
        .task(id: threadId) {
            await subscribe()
            if let uid = currentUid {
                try? await MessageRepository.shared.markRead(threadId: threadId, uid: uid)
            }
        }
        .onDisappear { observeTask?.cancel() }
    }

    private func subscribe() async {
        observeTask?.cancel()
        guard !threadId.isEmpty else { return }
        observeTask = Task { @MainActor in
            for await msgs in MessageRepository.shared.observeMessages(threadId: threadId) {
                self.messages = msgs
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.navy)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.plain)

            HSAvatar(uid: otherUid, initials: other?.initials ?? "?", size: 38)
            VStack(alignment: .leading, spacing: 1) {
                Text(other?.name ?? "Unknown")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(HSColors.gray900)
                Text(presenceLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray500)
            }

            Spacer()

            Button {} label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.navy)
                    .frame(width: 36, height: 36)
                    .background(HSColors.gray100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 58).padding(.bottom, 12)
        .background(Color.white)
        .overlay(
            Rectangle().fill(HSColors.gray200).frame(height: 1),
            alignment: .bottom
        )
    }

    private var presenceLabel: String {
        guard let updated = thread.updatedAt else { return "Tap to send a message" }
        let interval = -updated.timeIntervalSinceNow
        if interval < 60 { return "Active now" }
        if interval < 3600 { return "Last active \(Int(interval/60))m ago" }
        if interval < 86400 { return "Last active \(Int(interval/3600))h ago" }
        return "Last active recently"
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(messages.enumerated()), id: \.element.id) { idx, m in
                        bubble(for: m, isFirst: idx == 0)
                            .id(m.id)
                    }
                }
                .padding(.horizontal, 16).padding(.top, 14)
            }
            .onChange(of: messages.count) {
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func bubble(for m: HSMessageDoc, isFirst: Bool) -> some View {
        let isMine = m.isMe(currentUid ?? "")
        return HStack(alignment: .bottom, spacing: 8) {
            if !isMine {
                if isFirst {
                    HSAvatar(uid: otherUid, initials: other?.initials ?? "?", size: 26)
                } else {
                    Color.clear.frame(width: 26, height: 26)
                }
            }
            if isMine { Spacer(minLength: 60) }
            Text(m.text)
                .font(.system(size: 14))
                .kerning(-0.1)
                .foregroundColor(isMine ? .white : HSColors.gray900)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(isMine ? AnyShapeStyle(HSColors.navy) : AnyShapeStyle(Color.white))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(isMine ? Color.clear : HSColors.gray200, lineWidth: 1)
                )
            if !isMine { Spacer(minLength: 60) }
        }
    }

    private var composer: some View {
        HStack(spacing: 8) {
            Button {} label: {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.navy)
                    .frame(width: 36, height: 36)
                    .background(HSColors.gray100)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 6) {
                TextField("Message…", text: $draft, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.system(size: 14))
                    .foregroundColor(HSColors.gray900)
                    .padding(.leading, 14)
                Button(action: send) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(draft.trimmingCharacters(in: .whitespaces).isEmpty ? HSColors.gray300 : HSColors.navy)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
                .padding(.trailing, 6)
            }
            .frame(minHeight: 38)
            .background(HSColors.gray100)
            .clipShape(RoundedRectangle(cornerRadius: 19, style: .continuous))
        }
        .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 34)
        .background(Color.white)
        .overlay(
            Rectangle().fill(HSColors.gray200).frame(height: 1),
            alignment: .top
        )
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty, let uid = currentUid, !threadId.isEmpty else { return }
        draft = ""
        Task {
            try? await MessageRepository.shared.send(
                text: text, threadId: threadId, senderId: uid)
        }
    }
}
