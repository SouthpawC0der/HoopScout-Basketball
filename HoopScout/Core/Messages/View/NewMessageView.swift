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
                                Button { onSelect(u) } label: {
                                    row(for: u, isLast: idx == filtered.count - 1)
                                }
                                .buttonStyle(.plain)
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
            .task { await loadUsers() }
        }
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
                HSAvatar(profile: u, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(u.name).font(.system(size: 15, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text(u.handle).font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(14)
            .contentShape(Rectangle())
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }
}

#Preview {
    NewMessageView { _ in }
        .environmentObject(AuthService())
}
