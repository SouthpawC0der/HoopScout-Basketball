//
//  MessagesView.swift
//  HoopScout
//

import SwiftUI

struct MessagesView: View {
    @EnvironmentObject private var auth: AuthService

    @State private var query: String = ""
    @State private var threads: [HSThreadDoc] = []
    @State private var showNewMessage = false
    @State private var path: [HSThreadDoc] = []
    @State private var observeTask: Task<Void, Never>?

    private var currentUid: String? { auth.profile?.id }

    private var filteredThreads: [HSThreadDoc] {
        guard !query.isEmpty else { return threads }
        return threads.filter { t in
            guard let uid = currentUid,
                  let other = t.otherInfo(currentUid: uid) else { return false }
            return other.name.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ZStack(alignment: .bottomTrailing) {
                HSColors.bg.ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 0) {
                        header
                        searchField
                        activeNowStrip
                        threadList
                    }
                    .padding(.bottom, 100)
                }

                floatingNewButton
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HSThreadDoc.self) { thread in
                MessageThreadView(thread: thread)
            }
            .navigationDestination(for: HSFriend.self) { friend in
                FriendProfileView(friend: friend)
            }
            .sheet(isPresented: $showNewMessage) {
                NewMessageView { other in
                    showNewMessage = false
                    Task { await openOrCreateThread(with: other) }
                }
            }
            .task(id: currentUid) {
                await observeThreads()
            }
        }
    }

    private func observeThreads() async {
        observeTask?.cancel()
        guard let uid = currentUid else {
            threads = []
            return
        }
        observeTask = Task { @MainActor in
            for await snapshot in MessageRepository.shared.observeThreads(for: uid) {
                self.threads = snapshot
            }
        }
    }

    private func openOrCreateThread(with other: HSUserProfile) async {
        guard let current = auth.profile else { return }
        do {
            let id = try await MessageRepository.shared
                .createOrGetThread(current: current, other: other)
            // Resolve the doc — try local first, fall back to a minimal one.
            if let existing = threads.first(where: { $0.id == id }) {
                path.append(existing)
            } else if let currentId = current.id, let otherId = other.id {
                let placeholder = HSThreadDoc(
                    id: id,
                    participants: [currentId, otherId].sorted(),
                    participantsInfo: [
                        currentId: .init(name: current.name, initials: current.initials),
                        otherId: .init(name: other.name, initials: other.initials)
                    ],
                    lastMessage: nil,
                    unread: [currentId: 0, otherId: 0],
                    updatedAt: Date()
                )
                path.append(placeholder)
            }
        } catch {
            #if DEBUG
            print("Open/create thread failed:", error)
            #endif
        }
    }

    private var header: some View {
        HStack {
            Text("Messages")
                .font(.system(size: 34, weight: .heavy))
                .kerning(-1.2)
                .foregroundColor(HSColors.gray900)
            Spacer()
        }
        .padding(.horizontal, 20).padding(.top, 16).padding(.bottom, 6)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(HSColors.gray500)
            TextField("Search hoopers", text: $query)
                .font(.system(size: 14))
                .foregroundColor(HSColors.gray900)
        }
        .padding(.horizontal, 12).frame(height: 40)
        .background(Color.white)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(HSColors.gray200, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 20).padding(.top, 12)
    }

    // Placeholder until friend graph + active-checkin query are wired up.
    private var activeNowStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RUNNIN' NOW")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(HSMockData.friends.prefix(5)) { f in
                        NavigationLink(value: f) {
                            VStack(spacing: 6) {
                                ZStack {
                                    HSAvatar(friend: f, size: 48, online: true)
                                    if ["f1","f2","f4"].contains(f.id) {
                                        Circle()
                                            .stroke(HSColors.court, lineWidth: 2)
                                            .frame(width: 56, height: 56)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                Text(f.name.split(separator: " ").first.map(String.init) ?? f.name)
                                    .font(.system(size: 11, weight: .semibold))
                                    .kerning(-0.1)
                                    .foregroundColor(HSColors.gray900)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 14)
    }

    private var threadList: some View {
        VStack(spacing: 0) {
            if filteredThreads.isEmpty {
                emptyState
            } else {
                ForEach(Array(filteredThreads.enumerated()), id: \.element.id) { idx, t in
                    NavigationLink(value: t) {
                        ThreadRow(thread: t,
                                  currentUid: currentUid ?? "",
                                  isLast: idx == filteredThreads.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(filteredThreads.isEmpty ? Color.clear : Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(filteredThreads.isEmpty ? Color.clear : HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16).padding(.top, 4)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 28))
                .foregroundColor(HSColors.gray300)
            Text("No conversations yet")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(HSColors.gray700)
            Text("Tap the new-message button to start one.")
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private var floatingNewButton: some View {
        Button { showNewMessage = true } label: {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(HSColors.navy)
                .clipShape(Circle())
                .shadow(color: HSColors.navy.opacity(0.4), radius: 16, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }
}

private struct ThreadRow: View {
    let thread: HSThreadDoc
    let currentUid: String
    let isLast: Bool

    private var otherUid: String { thread.otherUid(currentUid: currentUid) ?? "" }
    private var other: HSThreadDoc.ThreadParticipant? { thread.otherInfo(currentUid: currentUid) }
    private var unread: Int { thread.unreadCount(for: currentUid) }
    private var lastText: String { thread.lastMessage?.text ?? "Start a conversation" }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HSAvatar(uid: otherUid,
                         initials: other?.initials ?? "?",
                         size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(other?.name ?? "Unknown")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                        Spacer()
                        Text(timeLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(HSColors.gray500)
                    }
                    HStack {
                        Text(lastText)
                            .font(.system(size: 13,
                                          weight: unread > 0 ? .semibold : .regular))
                            .foregroundColor(unread > 0 ? HSColors.gray900 : HSColors.gray500)
                            .lineLimit(1)
                        Spacer()
                        if unread > 0 {
                            Text("\(unread)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .frame(minWidth: 18, idealHeight: 18)
                                .background(HSColors.navy)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(14)
            .contentShape(Rectangle())
            if !isLast {
                Divider().background(HSColors.gray100)
            }
        }
    }

    private var timeLabel: String {
        guard let date = thread.lastMessage?.timestamp ?? thread.updatedAt else { return "" }
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "now" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        if interval < 86400 { return "\(Int(interval / 3600))h" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }
}

#Preview {
    MessagesView().environmentObject(AuthService())
}
