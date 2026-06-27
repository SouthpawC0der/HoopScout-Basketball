//
//  ProfileView.swift
//  HoopScout
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var locationManager: LocationManager
    @EnvironmentObject private var notifications: NotificationRepository
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var showNotifications = false
    @State private var showHelpChat = false
    @State private var runsPath: [String] = []
    @State private var tab: HSProfileSelection = .stats
    @State private var followingList: [HSFollowDoc] = []
    @State private var followersList: [HSFollowDoc] = []
    @State private var recentRuns: [HSRunDoc] = []
    @State private var observeFollowingTask: Task<Void, Never>?
    @State private var observeFollowersTask: Task<Void, Never>?
    @State private var observeRunsTask: Task<Void, Never>?
    @State private var showFindPeople = false
    @State private var showPreferences = false
    @State private var showSkillPicker = false
    @State private var showMapAppPicker = false
    @AppStorage(LocationManager.autoDetectKey) private var autoDetect: Bool = false
    @AppStorage("hs_default_map_app") private var defaultMapApp: String = "Apple Maps"
    @State private var showAlwaysDeniedAlert = false

    private var user: HSUserProfile {
        auth.profile ?? HSUserProfile(
            name: "—", handle: "@—", location: "", bio: "",
            skill: "Casual", runs: 0, followers: 0, following: 0
        )
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                HSColors.bg.ignoresSafeArea()

                LinearGradient(colors: [HSColors.navy, HSColors.navy2],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 320)
                    .ignoresSafeArea(edges: .top)

                ScrollView {
                    VStack(spacing: 0) {
                        header
                        statsCard.offset(y: -50).padding(.bottom, -50)
                        actionRow.padding(.top, 14)
                        Group {
                            switch tab {
                            case .stats: statsPanel
                            case .followers: followList(kind: .followers)
                            case .following: followList(kind: .following)
                            }
                        }
                        settings
                        footer
                    }
                    .padding(.bottom, 100)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: HSUserProfile.self) { profile in
                FriendProfileView(user: profile)
            }
            .navigationDestination(for: String.self) { token in
                switch token {
                case "runs": RunsView()
                case "help": HelpChatView()
                default: EmptyView()
                }
            }
            .task(id: auth.profile?.id) {
                observeFollows()
                observeRuns()
            }
            .sheet(isPresented: $showFindPeople) {
                FindPeopleView()
            }
            .sheet(isPresented: $showPreferences) {
                PreferencesView()
            }
            .sheet(isPresented: $showSkillPicker) {
                skillPickerSheet
                    .presentationDetents([.height(280)])
            }
            .sheet(isPresented: $showMapAppPicker) {
                mapAppPickerSheet
                    .presentationDetents([.height(320)])
            }
            .sheet(isPresented: $showNotifications) {
                NotificationsView()
            }
        }
    }

    private var skillPickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Default skill level")
                    .font(.system(size: 18, weight: .heavy))
                Spacer()
                Button("Done") { showSkillPicker = false }
                    .fontWeight(.bold).foregroundColor(HSColors.navy)
            }
            ForEach(["Casual", "Competitive"], id: \.self) { level in
                Button {
                    Task {
                        if var p = auth.profile { p.skill = level
                            try? await UserRepository.shared.update(p)
                            auth.applyLocalProfileUpdate(p)
                        }
                        showSkillPicker = false
                    }
                } label: {
                    HStack {
                        Text(level).font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HSColors.gray900)
                        Spacer()
                        if user.skill == level {
                            Image(systemName: "checkmark")
                                .foregroundColor(HSColors.navy)
                        }
                    }
                    .padding(.horizontal, 16).frame(height: 52)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presentationDragIndicator(.visible)
    }

    private var mapAppPickerSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Default map app")
                    .font(.system(size: 18, weight: .heavy))
                Spacer()
                Button("Done") { showMapAppPicker = false }
                    .fontWeight(.bold).foregroundColor(HSColors.navy)
            }
            ForEach(["Apple Maps", "Google Maps", "Waze"], id: \.self) { app in
                Button {
                    defaultMapApp = app
                    showMapAppPicker = false
                } label: {
                    HStack {
                        Text(app).font(.system(size: 15, weight: .semibold))
                            .foregroundColor(HSColors.gray900)
                        Spacer()
                        if defaultMapApp == app {
                            Image(systemName: "checkmark")
                                .foregroundColor(HSColors.navy)
                        }
                    }
                    .padding(.horizontal, 16).frame(height: 52)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .presentationDragIndicator(.visible)
    }

    private func observeRuns() {
        observeRunsTask?.cancel()
        guard let uid = auth.profile?.id else {
            recentRuns = []
            return
        }
        observeRunsTask = Task { @MainActor in
            for await runs in RunRepository.shared.observe(uid: uid, limit: 20) {
                self.recentRuns = runs
            }
        }
    }

    private func observeFollows() {
        observeFollowingTask?.cancel()
        observeFollowersTask?.cancel()
        guard let uid = auth.profile?.id else {
            followingList = []; followersList = []
            return
        }
        observeFollowingTask = Task { @MainActor in
            for await docs in FriendsRepository.shared.observeFollowing(for: uid) {
                self.followingList = docs
            }
        }
        observeFollowersTask = Task { @MainActor in
            for await docs in FriendsRepository.shared.observeFollowers(for: uid) {
                self.followersList = docs
            }
        }
    }

    private var header: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("PROFILE")
                        .font(.system(size: 12, weight: .bold))
                        .kerning(1.5)
                        .foregroundColor(.white.opacity(0.6))
                    Spacer()
                    Button { showFindPeople = true } label: {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { showPreferences = true } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 16) {
                    ZStack(alignment: .bottomTrailing) {
                        HSAvatar(profile: user, size: 80)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.3), lineWidth: 3)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 8)
                        Circle().fill(HSColors.live).frame(width: 22, height: 22)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(user.name)
                            .font(.system(size: 22, weight: .heavy))
                            .kerning(-0.5)
                            .foregroundColor(.white)
                        Text("\(user.handle) · \(user.location)")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.65))
                        HSSkillBadge(level: user.skill, dark: true)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20).padding(.top, 20)

                Text(user.bio)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineSpacing(3)
                    .padding(.horizontal, 20).padding(.top, 14)
            }
            .padding(.top, 54).padding(.bottom, 70)
        }
    }

    private var statsCard: some View {
        HStack(spacing: 0) {
            NavigationLink(value: "runs") {
                statTileLabel("Runs", value: "\(user.runs)", isSelected: false)
            }
            .buttonStyle(.plain)
            divider
            statTile("Followers", value: "\(user.followersCount ?? user.followers)", selection: .followers)
            divider
            statTile("Following", value: "\(user.followingCount ?? user.following)", selection: .following)
        }
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 24, x: 0, y: 8)
        .padding(.horizontal, 16)
    }

    private func statTileLabel(_ label: String, value: String, isSelected: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 22, weight: .heavy))
                .kerning(-0.5)
                .foregroundColor(HSColors.gray900)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.4)
                .foregroundColor(isSelected ? HSColors.navy : HSColors.gray500)
            Color.clear.frame(width: 20, height: 3)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 14)
    }

    private func statTile(_ label: String, value: String, selection: HSProfileSelection) -> some View {
        Button { withAnimation { tab = selection } } label: {
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 22, weight: .heavy))
                    .kerning(-0.5)
                    .foregroundColor(HSColors.gray900)
                Text(label.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.4)
                    .foregroundColor(tab == selection ? HSColors.navy : HSColors.gray500)
                if tab == selection {
                    Capsule().fill(HSColors.navy).frame(width: 20, height: 3)
                } else {
                    Color.clear.frame(width: 20, height: 3)
                }
            }
            .frame(maxWidth: .infinity).padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle().fill(HSColors.gray100).frame(width: 1).padding(.vertical, 12)
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            NavigationLink {
                EditProfileView()
            } label: {
                Text("Edit profile")
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(HSColors.navy).foregroundColor(.white)
                    .font(.system(size: 14, weight: .bold))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            ShareLink(item: shareText) {
                Text("Share profile")
                    .frame(maxWidth: .infinity).frame(height: 42)
                    .background(Color.white).foregroundColor(HSColors.navy)
                    .font(.system(size: 14, weight: .bold))
                    .overlay(Capsule().stroke(HSColors.gray200, lineWidth: 1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 16)
    }

    private var shareText: String {
        "Hoop with me on HoopScout — \(user.handle) (\(user.location))"
    }

    private var statsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                sectionLabel("Recent runs")
                Spacer()
                if !recentRuns.isEmpty {
                    NavigationLink(value: "runs") {
                        Text("See all")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(HSColors.navy)
                            .padding(.trailing, 20)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 18)

            VStack(spacing: 0) {
                if recentRuns.isEmpty {
                    emptyRunsState
                } else {
                    ForEach(Array(recentRuns.prefix(3).enumerated()), id: \.element.id) { idx, run in
                        recentRunRow(run, isLast: idx == min(2, recentRuns.count - 1))
                    }
                }
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func recentRunRow(_ run: HSRunDoc, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(HSColors.court)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.courtName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                        .lineLimit(1)
                    Text(runSubtitle(run))
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                if run.rated {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 13))
                        .foregroundColor(HSColors.live)
                }
            }
            .padding(12)
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }

    private func runSubtitle(_ run: HSRunDoc) -> String {
        let timeAgo = run.endedAt.map(relativeDay) ?? ""
        let duration = "\(run.durationMinutes) min"
        if timeAgo.isEmpty { return duration }
        return "\(timeAgo) · \(duration)"
    }

    private func relativeDay(_ date: Date) -> String {
        let interval = -date.timeIntervalSinceNow
        if interval < 60 { return "Just now" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        if interval < 86400 { return "Today" }
        if interval < 172800 { return "Yesterday" }
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: date)
    }

    private var emptyRunsState: some View {
        Button { tabRouter.selectedTab = TabRouter.courts } label: {
            VStack(spacing: 8) {
                Image(systemName: "basketball.fill")
                    .font(.system(size: 28))
                    .foregroundColor(HSColors.court)
                Text("Let's hoop")
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(HSColors.gray900)
                Text("Check in at a court to start logging runs.")
                    .font(.system(size: 12))
                    .foregroundColor(HSColors.gray500)
                    .multilineTextAlignment(.center)
                Text("Browse courts →")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(HSColors.navy)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .bold))
            .kerning(1.2)
            .foregroundColor(HSColors.gray500)
            .padding(.leading, 20)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private enum FollowKind { case followers, following }

    @ViewBuilder
    private func followList(kind: FollowKind) -> some View {
        let docs = (kind == .following) ? followingList : followersList
        let emptyText = (kind == .following)
            ? "You're not following anyone yet."
            : "No followers yet."
        if docs.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "person.2")
                    .font(.system(size: 24))
                    .foregroundColor(HSColors.gray300)
                Text(emptyText)
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray500)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(docs.enumerated()), id: \.element.id) { idx, doc in
                    NavigationLink(value: placeholder(for: doc)) {
                        followRow(doc: doc, isLast: idx == docs.count - 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 14)
        }
    }

    private func followRow(doc: HSFollowDoc, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                HSAvatar(uid: doc.id ?? doc.name, initials: doc.initials, size: 42)
                VStack(alignment: .leading, spacing: 1) {
                    Text(doc.name).font(.system(size: 14, weight: .bold))
                        .foregroundColor(HSColors.gray900)
                    Text(sinceLabel(doc.since))
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(12)
            .contentShape(Rectangle())
            if !isLast { Divider().background(HSColors.gray100) }
        }
    }

    private func sinceLabel(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return "Since \(f.string(from: date))"
    }

    private var autoCheckInRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text("📡")
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .background(HSColors.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto check-in")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(HSColors.gray900)
                    Text("Detects when you arrive at a court — uses Always location.")
                        .font(.system(size: 11))
                        .foregroundColor(HSColors.gray500)
                        .lineLimit(2)
                }
                Spacer()
                Toggle("", isOn: $autoDetect)
                    .labelsHidden()
                    .tint(HSColors.navy)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            Divider().background(HSColors.gray100)
        }
        .onChange(of: autoDetect) { _, isOn in
            if isOn {
                if locationManager.isAlwaysAuthorized {
                    locationManager.enableVisitMonitoring()
                } else {
                    locationManager.requestAlwaysAuthorization()
                    // The auth-status listener will start monitoring once Always is granted.
                }
            } else {
                locationManager.disableVisitMonitoring()
            }
        }
        .onChange(of: locationManager.authorizationStatus) { _, _ in
            // If user denied Always after we asked, flip the toggle back off.
            if autoDetect && !locationManager.isAlwaysAuthorized {
                autoDetect = false
                showAlwaysDeniedAlert = true
                locationManager.disableVisitMonitoring()
            }
        }
        .alert("Always location required",
               isPresented: $showAlwaysDeniedAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("To auto-check-in, allow HoopScout to use your location \"Always\" in iOS Settings.")
        }
    }

    /// Minimal HSUserProfile for navigation — FriendProfileView refreshes the
    /// full record from Firestore on appear.
    private func placeholder(for doc: HSFollowDoc) -> HSUserProfile {
        HSUserProfile(
            id: doc.id,
            name: doc.name,
            handle: "",
            location: "",
            bio: "",
            skill: "Casual",
            runs: 0,
            followers: 0,
            following: 0
        )
    }

    private var settings: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Settings").padding(.top, 16)
            VStack(spacing: 0) {
                autoCheckInRow
                Button { openSystemSettings() } label: {
                    settingsRow(icon: "📍", label: "Location sharing",
                                value: locationManager.isAlwaysAuthorized ? "Always" : "When in use",
                                last: false)
                }
                .buttonStyle(.plain)

                Button { showNotifications = true } label: {
                    settingsRow(icon: "🔔", label: "Notifications",
                                value: notifications.unreadCount > 0
                                    ? "\(notifications.unreadCount) unread"
                                    : "Open",
                                last: false)
                }
                .buttonStyle(.plain)

                Button { showSkillPicker = true } label: {
                    settingsRow(icon: "🏀", label: "Default skill level",
                                value: user.skill, last: false)
                }
                .buttonStyle(.plain)

                Button { showMapAppPicker = true } label: {
                    settingsRow(icon: "🗺️", label: "Map app",
                                value: defaultMapApp, last: false)
                }
                .buttonStyle(.plain)

                NavigationLink {
                    PrivacyPolicyView()
                } label: {
                    settingsRow(icon: "🔒", label: "Privacy", value: nil, last: false)
                }
                .buttonStyle(.plain)

                NavigationLink(value: "help") {
                    settingsRow(icon: "❓", label: "Help & support", value: nil, last: true)
                }
                .buttonStyle(.plain)
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal, 16).padding(.top, 8)
        }
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func settingsRow(icon: String, label: String, value: String?, last: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Text(icon)
                    .font(.system(size: 15))
                    .frame(width: 30, height: 30)
                    .background(HSColors.gray100)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(HSColors.gray900)
                Spacer()
                if let v = value {
                    Text(v).font(.system(size: 13)).foregroundColor(HSColors.gray500)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(HSColors.gray300)
            }
            .padding(.horizontal, 14).padding(.vertical, 12)
            if !last { Divider().background(HSColors.gray100) }
        }
        .contentShape(Rectangle())
    }

    private var footer: some View {
        HStack(spacing: 4) {
            Text("HoopScout v1.4.2 · ").foregroundColor(HSColors.gray500)
            Text("Sign out").foregroundColor(HSColors.navy).fontWeight(.semibold)
        }
        .font(.system(size: 12))
        .padding(.top, 20)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileView()
}
