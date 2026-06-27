//
//  TabRouter.swift
//  HoopScout
//
//  Shared tab-bar selection so any view can ask the root tab view to switch
//  tabs (e.g. ProfileView's "Let's hoop" CTA jumps to Courts).
//

import Foundation
import Combine

@MainActor
final class TabRouter: ObservableObject {
    @Published var selectedTab: Int = 3

    static let highlights = 0
    static let courts = 1
    static let upload = 2
    static let feed = 3
    static let messages = 4
}
