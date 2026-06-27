//
//  NewMessageView.swift
//  HoopScout
//

import SwiftUI

struct NewMessageView: View {
    @EnvironmentObject private var auth: AuthService
    var onSelect: (HSUserProfile) -> Void

    @State private var query: String = ""
    @State private var users: [HSUserProfile] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var previewUser: HSUserProfile?
    @Environment(\.dismiss) private var dismiss

    private var filtered: [HSUserProfile] {
        guard !query.isEmpty else { return users }
        return users.filter {
            $0.name.localizedCaseInsensitiveContains(query)
            || $0.handle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchField
                ScrollView {
                    LazyVStack(spacing: 0) {
                        if isLoading {
                            ProgressView()
                                .tint(HSColors.navy)
                                .padding(40)
                        } else if filtered.isEmpty {
                            Text(error ?? "No users yet.")
                                .font(.system(size: 14))
                                .foregroundColor(HSColors.gray500)
                                .padding(40)
                        } else {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { idx, u in
                                row(for: u, isLast: idx == filtered.count - 1)
                            }
                        }
                    }
                    .background(filtered.isEmpty ? Color.clear : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(filtered.isEmpty ? Color.clear : HSColors.gray200, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
                .background(HSColors.bg)
            }
            .navigationTitle("New message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HSColors.navy)
                }
            }
            .navigationDestination(for: HSUserProfile.self) { user in
                FriendProfileView(user: user)
            }
            .task { await loadUsers() }
            .onChange(of: query) { _, newValue in
                Task { await searchIfNeeded(newValue) }
            }
        }
    }

    /// When typing a query, run a server search so we can find users outside
    /// the first 100-user `fetchAll` page.
    private func searchIfNeeded(_ q: String) async {
        let trimmed = q.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        let results = (try? await UserRepository.shared.search(
            query: trimmed, excluding: auth.profile?.id)) ?? []
        // Merge into users without duplicates.
        var merged = users
        for u in results where !merged.contains(where: { $0.id == u.id }) {
            merged.append(u)
        }
        users = merged
    }

    private func loadUsers() async {
        isLoading = true
        defer { isLoading = false }
        do {
            users = try await UserRepository.shared
                .fetchAll(excluding: auth.profile?.id)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundColor(HSColors.gray500)
            TextField("To: name or handle", text: $query)
                .font(.system(size: 14))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12).frame(height: 40)
        .background(HSColors.gray100)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.top, 10)
    }

    private func row(for u: HSUserProfile, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Tapping anywhere on this main area starts the chat
                // directly — matches the user's expectation that "click
                // the name to start a new message".
                Button { onSelect(u) } label: {
                    HStack(spacing: 12) {
                        HSAvatar(profile: u, size: 42)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(u.name).font(.system(size: 15, weight: .bold))
                                .foregroundColor(HSColors.gray900)
                            Text(u.handle.isEmpty ? "Tap to message" : u.handle)
                                .font(.system(size: 12))
                                .foregroundColor(HSColors.gray500)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Tucked-away "view profile" affordance for the few cases
                // where the user wants to look at someone's profile first.
                NavigationLink(value: u) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(HSColors.gray300)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14).padding(.vertical, 8)
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }
}

#Preview {
    NewMessageView { _ in }
        .environmentObject(AuthService())
}
