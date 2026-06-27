//
//  HoopTabView.swift
//  HoopScout
//

import SwiftUI

struct HoopTabView: View {
    @EnvironmentObject private var messaging: MessagingService
    @EnvironmentObject private var checkIn: CheckInService
    @EnvironmentObject private var tabRouter: TabRouter
    @State private var ratingCourt: RatingCourtPayload?
    @State private var ratingUser: RatingUserPayload?
    @State private var showHighlightComposer = false

    private var tabSelection: Binding<Int> {
        Binding(
            get: { tabRouter.selectedTab },
            set: { newValue in
                if newValue == TabRouter.upload {
                    showHighlightComposer = true
                } else {
                    tabRouter.selectedTab = newValue
                }
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
            HighlightsView()
                .tabItem {
                    Label("Highlights", systemImage: tabRouter.selectedTab == TabRouter.highlights ? "film.fill" : "film")
                }
                .tag(TabRouter.highlights)

            CourtsView()
                .tabItem {
                    Label("Courts", systemImage: tabRouter.selectedTab == TabRouter.courts ? "basketball.fill" : "basketball")
                }
                .tag(TabRouter.courts)

            Color.clear
                .tabItem {
                    Label("Upload", systemImage: "plus.circle.fill")
                }
                .tag(TabRouter.upload)

            FeedView()
                .tabItem {
                    Label("Feed", systemImage: tabRouter.selectedTab == TabRouter.feed ? "text.bubble.fill" : "text.bubble")
                }
                .tag(TabRouter.feed)

            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: tabRouter.selectedTab == TabRouter.messages ? "message.fill" : "message")
                }
                .tag(TabRouter.messages)
        }
        .tint(HSColors.navy)
        .onChange(of: messaging.pendingThreadId) { _, newValue in
            if newValue != nil { tabRouter.selectedTab = TabRouter.messages }
        }
        .onChange(of: checkIn.pendingRatingPrompt) { _, prompt in
            switch prompt {
            case .court(let id, let name):
                ratingCourt = RatingCourtPayload(courtId: id, courtName: name)
            case .user(let uid, let name, let initials, let courtId):
                ratingUser = RatingUserPayload(uid: uid, name: name,
                                               initials: initials, courtId: courtId)
            case .none:
                break
            }
            checkIn.pendingRatingPrompt = nil
        }
        .sheet(item: $ratingCourt) { payload in
            RateCourtView(courtId: payload.courtId, courtName: payload.courtName)
                .presentationDetents([.medium])
        }
        .sheet(item: $ratingUser) { payload in
            RateUserView(ratedUid: payload.uid,
                         ratedName: payload.name,
                         ratedInitials: payload.initials,
                         courtId: payload.courtId)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showHighlightComposer) {
            HighlightComposerView { _ in
                showHighlightComposer = false
                tabRouter.selectedTab = TabRouter.highlights
            }
            .presentationDetents([.large])
        }
    }
}

private struct RatingCourtPayload: Identifiable {
    let courtId: String
    let courtName: String
    var id: String { courtId }
}

private struct RatingUserPayload: Identifiable {
    let uid: String
    let name: String
    let initials: String
    let courtId: String?
    var id: String { uid }
}

#Preview {
    HoopTabView()
}
