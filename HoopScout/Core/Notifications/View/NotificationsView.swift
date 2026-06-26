//
//  NotificationsView.swift
//  HoopScout
//

import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var notifications: NotificationRepository
    @EnvironmentObject private var checkIn: CheckInService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if notifications.items.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .background(HSColors.bg.ignoresSafeArea())
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(HSColors.navy)
                        .fontWeight(.bold)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if notifications.unreadCount > 0 {
                        Button("Mark all read") {
                            Task { await notifications.markAllRead() }
                        }
                        .foregroundColor(HSColors.navy)
                        .font(.system(size: 13, weight: .semibold))
                    }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(notifications.items) { item in
                NotificationRow(item: item)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .contentShape(Rectangle())
                    .onTapGesture { handleTap(item) }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let id = item.id {
                                Task { await notifications.delete(id) }
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bell.slash")
                .font(.system(size: 30))
                .foregroundColor(HSColors.gray300)
            Text("You're all caught up")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(HSColors.gray900)
            Text("Check-in updates, rating prompts, and replies will show up here.")
                .font(.system(size: 12))
                .foregroundColor(HSColors.gray500)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleTap(_ item: HSNotificationDoc) {
        if let id = item.id, item.isUnread {
            Task { await notifications.markRead(id) }
        }
        switch item.type {
        case "rate_court":
            if let courtId = item.courtId {
                let name = item.courtName ?? "this court"
                checkIn.pendingRatingPrompt = .court(id: courtId, name: name)
                dismiss()
            }
        case "rate_user":
            if let uid = item.userUid {
                let name = item.userName ?? "this hooper"
                let initials = item.userInitials ?? "?"
                checkIn.pendingRatingPrompt = .user(uid: uid, name: name,
                                                    initials: initials,
                                                    courtId: item.courtId)
                dismiss()
            }
        default:
            break
        }
    }
}

private struct NotificationRow: View {
    let item: HSNotificationDoc

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconBubble
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    if item.isUnread {
                        Circle().fill(HSColors.court).frame(width: 7, height: 7)
                    }
                    Spacer()
                    Text(relativeTime)
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                }
                Text(item.body)
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray700)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(HSColors.gray200, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var iconBubble: some View {
        let (symbol, color): (String, Color) = {
            switch item.type {
            case "rate_court": return ("basketball.fill", HSColors.court)
            case "rate_user": return ("person.fill", HSColors.navy)
            case "check_in": return ("mappin.and.ellipse", HSColors.live)
            default: return ("bell.fill", HSColors.gray500)
            }
        }()
        return Image(systemName: symbol)
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(.white)
            .frame(width: 32, height: 32)
            .background(color)
            .clipShape(Circle())
    }

    private var relativeTime: String {
        guard let createdAt = item.createdAt else { return "" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
