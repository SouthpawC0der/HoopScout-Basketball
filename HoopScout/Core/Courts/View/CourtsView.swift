//
//  CourtsView.swift
//  HoopScout
//

import SwiftUI
import CoreLocation

struct CourtsView: View {
    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var courtSearch: CourtSearchService

    @State private var filter: String = "all"
    @State private var query: String = ""
    @State private var debounceTask: Task<Void, Never>?
    @State private var showFilterSheet = false
    @State private var selectedCourt: HSCourt?
    @State private var showMap = false

    private var usingRealSearch: Bool {
        !courtSearch.courts.isEmpty || courtSearch.isLoading
    }

    private var displayedCourts: [HSCourt] {
        let source = usingRealSearch ? courtSearch.courts : HSMockData.courts
        return source.filter { c in
            if filter != "all" && !c.tags.contains(filter) { return false }
            if !query.isEmpty,
               !c.name.localizedCaseInsensitiveContains(query),
               !c.address.localizedCaseInsensitiveContains(query) { return false }
            return true
        }
    }

    var body: some View {
        ZStack {
            HSColors.bg.ignoresSafeArea()

            ScrollView {
                LazyVStack(spacing: 14, pinnedViews: []) {
                    header
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
                        CourtCard(court: c) { selectedCourt = c }
                    }
                    if displayedCourts.isEmpty && !courtSearch.isLoading {
                        Text("No courts match that. Try clearing filters.")
                            .font(.system(size: 14))
                            .foregroundColor(HSColors.gray500)
                            .padding(40)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
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
        .task {
            if !location.isAuthorized {
                location.requestPermission()
            } else {
                location.startUpdates()
            }
        }
        .onChange(of: location.location) { _, newLoc in
            guard let newLoc, query.isEmpty else { return }
            Task { await courtSearch.search(near: newLoc.coordinate) }
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
                } else if shouldGeocode(q) {
                    await courtSearch.search(query: q)
                }
            }
        }
    }

    private func shouldGeocode(_ s: String) -> Bool {
        let zip = s.range(of: #"^\d{5}(-\d{4})?$"#, options: .regularExpression) != nil
        let hasComma = s.contains(",")
        let hasMultipleWords = s.split(separator: " ").count >= 1 && s.count >= 3
        return zip || hasComma || hasMultipleWords
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

    private var locationLabel: String {
        if let label = courtSearch.lastSearchLabel, !label.isEmpty { return label }
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
        HStack(spacing: 4) {
            Text("\(displayedCourts.count) courts within 15 mi · ")
                .foregroundColor(HSColors.gray500)
            Text("\(displayedCourts.reduce(0) { $0 + $1.playing }) hoopers playing now")
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
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    HSCourtImage(variant: court.img, height: 132, cornerRadius: 0)

                    VStack {
                        HStack(alignment: .top) {
                            distancePill
                            Spacer()
                            if court.playing > 0 { livePill }
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
            Text("\(court.playing) playing")
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
                HSStars(rating: court.rating)
            }

            HStack {
                friendsRow
                Spacer()
                Button {
                    openInMaps(court: court)
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
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    private var friendsRow: some View {
        let friends = court.friendsHere.compactMap { HSMockData.friend(id: $0) }
        return Group {
            if friends.isEmpty {
                Text(court.address.isEmpty ? "No friends here yet" : court.address)
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

    private func openInMaps(court: HSCourt) {
        let encoded = court.address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "http://maps.apple.com/?daddr=\(encoded)") {
            UIApplication.shared.open(url)
        }
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
