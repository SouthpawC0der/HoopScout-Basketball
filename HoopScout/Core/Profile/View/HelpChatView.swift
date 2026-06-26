//
//  HelpChatView.swift
//  HoopScout
//
//  Lightweight rule-based help bot. Matches the user's question against a
//  hand-curated FAQ; if nothing matches, offers to email support.
//

import SwiftUI

struct HelpChatView: View {
    @State private var messages: [ChatMessage] = [
        .bot("Hey 👋 I'm the HoopScout helper. Pick a question or type your own."),
        .suggestions([
            "How do I check in to a court?",
            "How do I rate a court?",
            "Auto-detect isn't working",
            "How do I message someone?",
            "How do I follow a hooper?",
            "How are runs counted?"
        ])
    ]
    @State private var draft: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(messages) { message in
                            row(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
                }
            }
            composer
        }
        .background(HSColors.bg.ignoresSafeArea())
        .navigationTitle("Help & support")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func row(for message: ChatMessage) -> some View {
        switch message.kind {
        case .bot(let text):
            HStack(alignment: .top, spacing: 8) {
                botBubble(text: text)
                Spacer(minLength: 50)
            }
        case .user(let text):
            HStack {
                Spacer(minLength: 50)
                userBubble(text: text)
            }
        case .suggestions(let items):
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    Button { handle(text: item) } label: {
                        HStack {
                            Text(item)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(HSColors.navy)
                                .multilineTextAlignment(.leading)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(HSColors.gray300)
                        }
                        .padding(.horizontal, 14).padding(.vertical, 10)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(HSColors.gray200, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        case .emailCTA:
            Button {
                if let url = URL(string: "mailto:support@hoopscoutapp.com?subject=HoopScout%20help") {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack {
                    Image(systemName: "envelope.fill")
                    Text("Email support@hoopscoutapp.com")
                        .font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity).frame(height: 46)
                .background(HSColors.navy)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func botBubble(text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 12))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(HSColors.navy)
                .clipShape(Circle())
            Text(text)
                .font(.system(size: 14))
                .kerning(-0.1)
                .foregroundColor(HSColors.gray900)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(HSColors.gray200, lineWidth: 1)
                )
        }
    }

    private func userBubble(text: String) -> some View {
        Text(text)
            .font(.system(size: 14))
            .kerning(-0.1)
            .foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(HSColors.navy)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var composer: some View {
        HStack(spacing: 8) {
            TextField("Ask a question…", text: $draft, axis: .vertical)
                .focused($focused)
                .lineLimit(1...4)
                .font(.system(size: 14))
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(HSColors.gray100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Button {
                let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                draft = ""
                handle(text: text)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(HSColors.navy)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Color.white)
        .overlay(Rectangle().fill(HSColors.gray200).frame(height: 1), alignment: .top)
    }

    private func handle(text: String) {
        messages.append(.user(text))
        let reply = Self.reply(for: text)
        messages.append(.bot(reply.body))
        if reply.includeEmailCTA {
            messages.append(.emailCTA)
        }
    }

    private struct Reply {
        var body: String
        var includeEmailCTA: Bool = false
    }

    private static func reply(for raw: String) -> Reply {
        let q = raw.lowercased()
        func has(_ words: [String]) -> Bool { words.allSatisfy { q.contains($0) } }
        func any(_ words: [String]) -> Bool { words.contains(where: { q.contains($0) }) }

        if any(["check in", "check-in", "checkin", "check me in", "im playing"]) {
            return Reply(body: "Open the Courts tab, tap a court, then \"I'm playing here\". If you have auto-detect on, just hang at a court for ~5 min and we'll check you in for you.")
        }
        if any(["rate", "review", "rating", "stars", "balls"]) && any(["court", "park"]) {
            return Reply(body: "After you check out (manually or when you walk away), we send a notification to rate the court 1–5 basketballs. You can also open any court and tap \"Rate this court\".")
        }
        if any(["rate", "review"]) && any(["user", "player", "hooper"]) {
            return Reply(body: "When you leave a court, we send a rating prompt for each app user who was hooping with you. You score them on Ball Handling, Basketball IQ, Team Play, and Toughness.")
        }
        if any(["auto-detect", "auto detect", "autodetect", "background"]) {
            return Reply(body: "Auto check-in needs \"Always\" location. Go to Profile → Settings → Location sharing and switch it to Always. Then turn on Auto check-in in Profile.")
        }
        if any(["message", "dm", "chat", "text"]) {
            return Reply(body: "Open the Messages tab → tap the pencil button (bottom right) → search a hooper → tap them → tap Message to start a thread.")
        }
        if any(["follow", "unfollow", "friend"]) {
            return Reply(body: "Open any user's profile and tap Follow. Their follower count updates instantly. You'll see who you follow on your Profile under \"Following\".")
        }
        if any(["run", "runs"]) && !q.contains("running") {
            return Reply(body: "A run is logged automatically when you check in at a court and stay 10+ minutes. View your run history on Profile → tap your Runs number.")
        }
        if any(["notification", "notifications", "bell"]) {
            return Reply(body: "Tap the bell next to the Map button on the Courts tab. You'll see check-in updates, rating prompts, and nearby-court alerts. Swipe left to delete.")
        }
        if any(["photo", "picture", "avatar"]) {
            return Reply(body: "Profile → Edit profile → Change photo. Pick from your library and tap Save.")
        }
        if any(["map", "directions", "drive", "navigate"]) {
            return Reply(body: "Tap Play on any court card to get directions. You can change your default map app under Profile → Settings → Map app.")
        }
        if any(["court", "park", "find", "search", "missing", "not showing"]) {
            return Reply(body: "We pull courts from Apple Maps (basketball POIs + parks + fitness centers) plus searches like \"YMCA\". If a spot is missing, try ZIP code or \"City, ST\" in the search bar.")
        }
        if any(["privacy", "data", "delete account"]) {
            return Reply(body: "Profile → Settings → Privacy for our policy. To delete your account, email support@hoopscoutapp.com.")
        }
        if any(["support", "help", "human", "agent", "contact"]) {
            return Reply(body: "Happy to connect you with the team — they reply within a day.", includeEmailCTA: true)
        }
        return Reply(body: "I'm not sure I caught that one. Want me to forward it to the team?", includeEmailCTA: true)
    }
}

private struct ChatMessage: Identifiable {
    let id = UUID()
    let kind: Kind

    enum Kind {
        case bot(String)
        case user(String)
        case suggestions([String])
        case emailCTA
    }

    static func bot(_ text: String) -> ChatMessage { ChatMessage(kind: .bot(text)) }
    static func user(_ text: String) -> ChatMessage { ChatMessage(kind: .user(text)) }
    static func suggestions(_ items: [String]) -> ChatMessage { ChatMessage(kind: .suggestions(items)) }
    static var emailCTA: ChatMessage { ChatMessage(kind: .emailCTA) }
}

#Preview {
    NavigationStack { HelpChatView() }
}
