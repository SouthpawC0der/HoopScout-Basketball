//
//  CourtsView.swift
//  HoopScout
//

import SwiftUI
import CoreLocation

struct CourtsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var courtSearch: CourtSearchService
    @EnvironmentObject private var checkIn: CheckInService
    @EnvironmentObject private var courtRepo: CourtRepository
    @EnvironmentObject private var notifications: NotificationRepository
    @StateObject private var liveCounts = CourtLiveCountStore()

    @State private var filter: String = "all"
    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var showFilterSheet = false
    @State private var selectedCourt: HSCourt?
    @State private var showMap = false
    @State private var showNotifications = false

    private var usingRealSearch: Bool {
        !courtSearch.courts.isEmpty || courtSearch.isLoading
    }

    private var displayedCourts: [HSCourt] {
        // Don't fall back to mock data while we wait on the user's location.
        // It would show NY courts to someone in Charlotte. Only show
        // results once we have a real server search underway.
        guard usingRealSearch else { return [] }
        return courtSearch.courts.filter { c in
            if filter != "all" && !c.tags.contains(filter) { return false }
            return true
        }
    }

    var body: some View {
        ZStack {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    header
                    checkInBanner
                    searchAndFilter
                    chips
                    countLine
                    if courtSearch.isLoading {
                        ProgressView()
                            .tint(HSColors.navy)
                            .padding(20)
                    }
                    if let err = courtSearch.errorMessage {
                        Text(err)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.8))
                            .padding(.horizontal, 16)
                    }
                    ForEach(displayedCourts) { c in
                        CourtCard(court: c,
                                  liveCount: liveCounts.counts[courtRepo.stableId(for: c)],
                                  liveRating: liveCounts.ratings[courtRepo.stableId(for: c)]) {
                            selectedCourt = c
                        }
                    }
                    if displayedCourts.isEmpty && !courtSearch.isLoading {
                        emptyStateText
                            .font(.system(size: 14))
                            .foregroundColor(HSColors.gray500)
                            .multilineTextAlignment(.center)
                            .padding(40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .refreshable {
                await refreshCourts()
            }
        }
        .sheet(isPresented: $showFilterSheet) {
            CourtsFilterSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $selectedCourt) { court in
            CourtDetailView(court: court)
        }
        .fullScreenCover(isPresented: $showMap) {
            CourtMapView(onClose: { showMap = false }) { court in
                showMap = false
                selectedCourt = court
            }
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .task {
            if !location.isAuthorized {
                location.requestPermission()
            } else {
                location.startUpdates()
            }
            // If a location fix already exists when the tab opens (common when
            // the user came from another tab), kick off an initial search so
            // the list isn't empty until they pull to refresh. Subsequent
            // refreshes still happen via pull-to-refresh.
            if courtSearch.courts.isEmpty, !courtSearch.isLoading,
               query.isEmpty,
               let coord = location.location?.coordinate {
                await courtSearch.search(near: coord)
            }
        }
        .onChange(of: location.location) { _, newLoc in
            guard let newLoc else { return }
            // Feed the dwell detector with every fresh fix.
            let allCourts = (courtSearch.courts.isEmpty ? HSMockData.courts : courtSearch.courts)
                + HSMockData.courts
            checkIn.handle(location: newLoc, courts: allCourts, profile: auth.profile)
            // First-fix search: if the tab opened before a location was
            // available, trigger one search when the first fix arrives so the
            // list isn't empty. After that, refreshes are pull-to-refresh.
            if query.isEmpty, courtSearch.courts.isEmpty, !courtSearch.isLoading {
                Task { await courtSearch.search(near: newLoc.coordinate) }
            }
        }
        .onChange(of: courtSearch.courts) { _, newCourts in
            // Snapshot the discovered courts so background CLVisit handling
            // can match a coordinate to a court without the foreground service running.
            CourtCache.shared.save(newCourts)
        }
        .onChange(of: displayedCourts.map { courtRepo.stableId(for: $0) }) { _, ids in
            liveCounts.subscribe(courtIds: Set(ids))
        }
        .onChange(of: liveCounts.counts) { _, newCounts in
            NearbyAlertService.shared.evaluate(
                courts: displayedCourts,
                liveCounts: newCounts,
                userLocation: location.location,
                courtRepo: courtRepo)
        }
        .onAppear {
            liveCounts.subscribe(courtIds: Set(displayedCourts.map { courtRepo.stableId(for: $0) }))
        }
        .onChange(of: query) { _, newValue in
            debounceTask?.cancel()
            let q = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard !Task.isCancelled else { return }

                if q.isEmpty {
                    if let coord = location.location?.coordinate {
                        await courtSearch.search(near: coord)
                    }
                    return
                }

                // If the query *looks like* a place identifier (ZIP or
                // "City, ST"), geocode it and search there. Otherwise treat
                // it as a court/park *name* and search near the user so we
                // don't end up showing parks in California for "park" typed
                // in Charlotte.
                if isExplicitLocation(q) {
                    await courtSearch.search(query: q)
                } else if let coord = location.location?.coordinate {
                    await courtSearch.searchNearby(query: q, near: coord)
                } else {
                    await courtSearch.search(query: q)
                }
            }
        }
    }

    /// Pull-to-refresh handler — re-runs the appropriate court search.
    private func refreshCourts() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            if let coord = location.location?.coordinate {
                await courtSearch.search(near: coord)
            }
        } else if isExplicitLocation(trimmed) {
            await courtSearch.search(query: trimmed)
        } else if let coord = location.location?.coordinate {
            await courtSearch.searchNearby(query: trimmed, near: coord)
        } else {
            await courtSearch.search(query: trimmed)
        }
    }

    private func isExplicitLocation(_ s: String) -> Bool {
        let zip = s.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
        // Match "City, ST" or "City, State" — comma + something on each side.
        let cityState = s.range(of: #"^[A-Za-z\.\- ]+,\s*[A-Za-z\.\- ]+$"#,
                                options: .regularExpression) != nil
        return zip || cityState
    }

    @ViewBuilder
    private var checkInBanner: some View {
        if let checkedIn = checkIn.checkedInCourt {
            HStack(spacing: 10) {
                HSLivePulse(size: 8)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Playing at \(checkedIn.name)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                    Text("You're counted in the live total.")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                Spacer()
                Button("Check out") {
                    Task { await checkIn.checkOut(uid: auth.profile?.id) }
                }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).frame(height: 30)
                    .background(Color.white.opacity(0.15))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                LinearGradient(colors: [HSColors.live, HSColors.live.opacity(0.85)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let suggestion = checkIn.suggestion {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(HSColors.court)
                    Text("LOOKS LIKE YOU'RE AT A COURT")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(.white.opacity(0.7))
                }
                Text("You at \(suggestion.name)?")
                    .font(.system(size: 16, weight: .heavy))
                    .kerning(-0.3)
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Button {
                        Task { await checkIn.confirmSuggestion(as: auth.profile) }
                    } label: {
                        Text("Yes — check me in")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(HSColors.navy)
                            .padding(.horizontal, 14).frame(height: 34)
                            .background(Color.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button { checkIn.dismissSuggestion() } label: {
                        Text("Not now")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14).frame(height: 34)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [HSColors.navy, HSColors.navyDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("COURTS NEAR")
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(1.5)
                        .foregroundColor(HSColors.gray500)
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 11))
                            .foregroundColor(HSColors.court)
                        Text(locationLabel)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(HSColors.navy)
                    }
                }
                Spacer()
                Button { showNotifications = true } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HSColors.navy)
                            .frame(width: 38, height: 38)
                            .background(Color.white)
                            .overlay(Circle().stroke(HSColors.gray200, lineWidth: 1))
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        if notifications.unreadCount > 0 {
                            Circle()
                                .fill(HSColors.court)
                                .frame(width: 10, height: 10)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                                .offset(x: -3, y: 3)
                        }
                    }
                }
                .buttonStyle(.plain)

                Button { showMap = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "map.fill")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Map").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 38)
                    .background(HSColors.navy)
                    .clipShape(Capsule())
                    .shadow(color: HSColors.navy.opacity(0.25), radius: 10, x: 0, y: 2)
                }
                .buttonStyle(.plain)
            }
            Text("Courts")
                .font(.system(size: 34, weight: .heavy))
                .kerning(-1.2)
                .foregroundColor(HSColors.gray900)
                .padding(.top, 16)
        }
        .padding(.top, 16)
    }

    private var emptyStateText: Text {
        if location.location == nil {
            switch location.authorizationStatus {
            case .denied, .restricted:
                return Text("Location is off. Enable it in iOS Settings so we can show courts in your area.")
            case .notDetermined:
                return Text("Tap the location button to find courts near you.")
            default:
                return Text("Finding your area…")
            }
        }
        if !query.isEmpty {
            return Text("No courts match \"\(query)\" within 15 miles. Try a different term.")
        }
        return Text("No courts found in your area yet.")
    }

    private var locationLabel: String {
        // Prefer the user's reverse-geocoded city so the header always
        // identifies *where the user is*, not a court or search term.
        if let city = location.cityLabel, !city.isEmpty { return city }
        if location.location != nil { return "Near you" }
        switch location.authorizationStatus {
        case .denied, .restricted: return "Location off"
        case .notDetermined: return "Tap to enable location"
        default: return "Locating…"
        }
    }

    private var searchAndFilter: some View {
        HStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(HSColors.gray500)
                TextField("ZIP, city, or court name", text: $query)
                    .font(.system(size: 15))
                    .foregroundColor(HSColors.gray900)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.words)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(HSColors.gray300)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).frame(height: 44)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button { showFilterSheet = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(HSColors.navy)
                        .frame(width: 44, height: 44)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Circle().fill(HSColors.court).frame(width: 7, height: 7)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .offset(x: -9, y: 9)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                HSChip("All", active: filter == "all") { filter = "all" }
                HSChip(title: "Local", active: filter == "local") {
                    Image(systemName: "mappin").font(.system(size: 11))
                } action: { filter = "local" }
                HSChip(title: "Popular", active: filter == "popular") {
                    Image(systemName: "star.fill").font(.system(size: 11))
                } action: { filter = "popular" }
                HSChip(title: "Gyms", active: filter == "gyms") {
                    Image(systemName: "dumbbell.fill").font(.system(size: 11))
                } action: { filter = "gyms" }
                HSChip("With friends", active: filter == "friends") { filter = "friends" }
            }
        }
        .padding(.vertical, 4)
    }

    private var countLine: some View {
        let totalLive = displayedCourts.reduce(0) { sum, c in
            sum + (liveCounts.counts[courtRepo.stableId(for: c)] ?? c.playing)
        }
        return HStack(spacing: 4) {
            Text("\(displayedCourts.count) courts within 15 mi · ")
                .foregroundColor(HSColors.gray500)
            Text("\(totalLive) hoopers playing now")
                .foregroundColor(HSColors.live)
                .fontWeight(.bold)
        }
        .font(.system(size: 13, weight: .medium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }
}

private struct CourtCard: View {
    let court: HSCourt
    let liveCount: Int?
    let liveRating: CourtLiveRating?
    var onOpen: () -> Void
    @State private var showNavSheet = false

    private var effectivePlaying: Int {
        liveCount ?? court.playing
    }

    private var effectiveRating: Double {
        liveRating?.average ?? court.rating
    }

    private var coord: CLLocationCoordinate2D? {
        guard let lat = court.latitude, let lon = court.longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    CourtSnapshotImage(coordinate: coord,
                                       height: 132, cornerRadius: 0,
                                       fallback: court.img)

                    VStack {
                        HStack(alignment: .top) {
                            distancePill
                            Spacer()
                            if effectivePlaying > 0 { livePill }
                        }
                        Spacer()
                        if court.hasGame, let info = court.gameInfo {
                            HStack {
                                gameRibbon(info)
                                Spacer()
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 132)

                cardBody
            }
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var distancePill: some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 9))
                .foregroundColor(HSColors.court)
            Text("\(court.distance, specifier: "%.1f") mi")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(HSColors.navy)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.white.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var livePill: some View {
        HStack(spacing: 6) {
            HSLivePulse(size: 6)
            Text("\(effectivePlaying) playing")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(Color.black.opacity(0.75))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func gameRibbon(_ text: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: "clock.fill").font(.system(size: 9))
            Text(text).font(.system(size: 11, weight: .bold))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 9).padding(.vertical, 5)
        .background(HSColors.court)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var cardBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(court.name)
                        .font(.system(size: 16, weight: .bold))
                        .kerning(-0.3)
                        .foregroundColor(HSColors.gray900)
                        .lineLimit(1)
                    Text(court.type + (court.subtitle.map { " · \($0)" } ?? ""))
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                        .lineLimit(1)
                }
                Spacer()
                HSStars(rating: effectiveRating)
            }

            HStack {
                friendsRow
                Spacer()
                Button {
                    showNavSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill").font(.system(size: 10))
                        Text("Play").font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).frame(height: 34)
                    .background(HSColors.navy)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .confirmationDialog("Navigate to \(court.name)?",
                                    isPresented: $showNavSheet,
                                    titleVisibility: .visible) {
                    ForEach(NavigationLauncher.installedApps()) { app in
                        Button("Open in \(app.rawValue)") {
                            NavigationLauncher.open(app, for: court)
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text(court.address.isEmpty ? court.name : court.address)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var friendsRow: some View {
        let friends = court.friendsHere.compactMap { HSMockData.friend(id: $0) }
        return Group {
            if friends.isEmpty {
                Text(effectivePlaying > 0
                     ? "\(effectivePlaying) hoopers playing now"
                     : (court.address.isEmpty ? "No one playing yet" : court.address))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(HSColors.gray500)
                    .lineLimit(1)
            } else {
                HStack(spacing: 10) {
                    HStack(spacing: -8) {
                        ForEach(friends.prefix(3)) { f in
                            HSAvatar(friend: f, size: 22)
                                .overlay(Circle().stroke(Color.white, lineWidth: 2))
                        }
                    }
                    Text(friendsLabel(friends))
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(-0.1)
                        .foregroundColor(HSColors.gray700)
                }
            }
        }
    }

    private func friendsLabel(_ friends: [HSFriend]) -> String {
        let first = friends[0].name.split(separator: " ").first.map(String.init) ?? friends[0].name
        let extra = friends.count > 1 ? " +\(friends.count - 1)" : ""
        return "\(first)\(extra) here"
    }

}

private struct CourtsFilterSheet: View {
    @State private var skill = "any"
    @State private var type = "any"
    @State private var radius: Double = 15

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Capsule().fill(HSColors.gray300).frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

            HStack {
                Text("Filters").font(.system(size: 18, weight: .heavy)).kerning(-0.5)
                Spacer()
                Button("Reset") {}
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.navy)
            }

            row("Skill level", options: ["Any", "Casual", "Competitive"], selection: $skill)
            row("Court type", options: ["Any", "Outdoor", "Indoor", "Full court", "Half court"], selection: $type)
            row("Hoopers playing now", options: ["Any", "1+", "5+", "10+", "20+"], selection: .constant("Any"))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Radius").font(.system(size: 13, weight: .semibold)).foregroundColor(HSColors.gray700)
                    Spacer()
                    Text("\(Int(radius)) mi").font(.system(size: 13, weight: .semibold)).foregroundColor(HSColors.gray700)
                }
                Slider(value: $radius, in: 1...15)
                    .tint(HSColors.navy)
            }
            .padding(.top, 4)

            Button {} label: {
                Text("Apply filters")
                    .frame(maxWidth: .infinity).frame(height: 52)
                    .background(HSColors.navy).foregroundColor(.white)
                    .font(.system(size: 15, weight: .bold))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 32)
    }

    @ViewBuilder
    private func row(_ label: String, options: [String], selection: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold))
                .kerning(0.8)
                .foregroundColor(HSColors.gray500)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { o in
                        HSChip(o, active: selection.wrappedValue.lowercased() == o.lowercased()) {
                            selection.wrappedValue = o.lowercased()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    CourtsView()
        .environmentObject(LocationManager())
        .environmentObject(CourtSearchService())
}
