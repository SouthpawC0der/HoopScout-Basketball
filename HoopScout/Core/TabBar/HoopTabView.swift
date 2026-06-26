//
//  HoopTabView.swift
//  HoopScout
//

import SwiftUI

struct HoopTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            CourtsView()
                .tabItem {
                    Label("Courts", systemImage: selectedTab == 0 ? "basketball.fill" : "basketball")
                }
                .tag(0)

            MessagesView()
                .tabItem {
                    Label("Messages", systemImage: selectedTab == 1 ? "message.fill" : "message")
                }
                .badge(3)
                .tag(1)

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: selectedTab == 2 ? "person.fill" : "person")
                }
                .tag(2)
        }
        .tint(HSColors.navy)
    }
}

#Preview {
    HoopTabView()
}
