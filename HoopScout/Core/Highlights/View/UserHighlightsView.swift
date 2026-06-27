//
//  UserHighlightsView.swift
//  HoopScout
//
//  Created by Christopher Doyle on 6/26/26.
//

//
//  UserHighlightsView.swift
//  HoopScout
//
//  Instagram-style grid view of a user's uploaded highlights.
//

import SwiftUI

struct UserHighlightsView: View {
    let userId: String
    let userName: String
    
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var blocks: BlockRepository
    @State private var highlights: [HSHighlight] = []
    @State private var selectedHighlight: HSHighlight?
    @State private var showComposer = false
    
    private var isOwnProfile: Bool {
        userId == auth.profile?.id
    }
    
    private var displayed: [HSHighlight] {
        // Filter to only this user's highlights
        let userHighlights = HSHighlightMock.highlights.filter { $0.authorId == userId }
        return userHighlights + highlights
    }
    
    let columns = [
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2),
        GridItem(.flexible(), spacing: 2)
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Stats header
                statsHeader
                
                Divider()
                    .background(HSColors.gray200)
                    .padding(.vertical, 12)
                
                // Grid of highlights
                if displayed.isEmpty {
                    emptyState
                } else {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(displayed) { highlight in
                            Button {
                                selectedHighlight = highlight
                            } label: {
                                highlightThumbnail(highlight)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.bottom, 100)
        }
        .background(HSColors.bg)
        .navigationTitle("\(userName)'s Highlights")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwnProfile {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showComposer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(HSColors.navy)
                    }
                }
            }
        }
        .sheet(isPresented: $showComposer) {
            HighlightComposerView { highlight in
                highlights.insert(highlight, at: 0)
                showComposer = false
            }
            .presentationDetents([.large])
        }
        .fullScreenCover(item: $selectedHighlight) { highlight in
            HighlightDetailView(
                highlight: highlight,
                allHighlights: displayed
            )
        }
    }
    
    private var statsHeader: some View {
        HStack(spacing: 0) {
            statColumn(value: "\(displayed.count)", label: "Highlights")
            divider
            statColumn(value: formatCount(totalViews), label: "Total Views")
            divider
            statColumn(value: formatCount(totalLikes), label: "Total Likes")
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
    
    private func statColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .heavy))
                .foregroundColor(HSColors.gray900)
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(HSColors.gray500)
        }
        .frame(maxWidth: .infinity)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(HSColors.gray200)
            .frame(width: 1)
            .padding(.vertical, 8)
    }
    
    private func highlightThumbnail(_ highlight: HSHighlight) -> some View {
        GeometryReader { geometry in
            ZStack {
                // Thumbnail background (mock gradient)
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [HSColors.navy2, HSColors.navy],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Play icon overlay
                Image(systemName: "play.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.9))
                    .shadow(color: .black.opacity(0.3), radius: 4)

                // Bottom gradient + stats overlay
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [Color.black.opacity(0), Color.black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 44)
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 8) {
                            Label {
                                Text(formatCount(highlight.views))
                                    .font(.system(size: 11, weight: .bold))
                            } icon: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            Spacer()
                            Label {
                                Text(formatCount(highlight.likes))
                                    .font(.system(size: 11, weight: .bold))
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9, weight: .bold))
                            }
                        }
                        .labelStyle(.titleAndIcon)
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.5), radius: 2)
                        .padding(.horizontal, 6)
                        .padding(.bottom, 6)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width * 1.5)
            .clipped()
        }
        .aspectRatio(2/3, contentMode: .fit)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "video.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(HSColors.gray300)
            
            Text(isOwnProfile ? "No highlights yet" : "\(userName) hasn't posted any highlights")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(HSColors.gray900)
            
            if isOwnProfile {
                Text("Upload your best basketball moments")
                    .font(.system(size: 13))
                    .foregroundColor(HSColors.gray500)
                    .multilineTextAlignment(.center)
                
                Button {
                    showComposer = true
                } label: {
                    Text("Upload Highlight")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(HSColors.navy)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }
    
    private var totalViews: Int {
        displayed.reduce(0) { $0 + $1.views }
    }
    
    private var totalLikes: Int {
        displayed.reduce(0) { $0 + $1.likes }
    }
    
    private func formatCount(_ count: Int) -> String {
        if count >= 1000000 {
            return String(format: "%.1fM", Double(count) / 1000000)
        } else if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        } else {
            return "\(count)"
        }
    }
}

// MARK: - Highlight Detail View

struct HighlightDetailView: View {
    let highlight: HSHighlight
    let allHighlights: [HSHighlight]
    
    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int = 0
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            
            // Reuse the HighlightsView player but start at this highlight
            TabView(selection: $currentIndex) {
                ForEach(Array(allHighlights.enumerated()), id: \.element.id) { index, hl in
                    HighlightPlayerView(
                        highlight: hl,
                        isLiked: false,
                        onLike: { },
                        onComment: { },
                        onRepost: { },
                        onShare: { },
                        onOptions: { }
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
            
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(.top, 54)
            .padding(.leading, 16)
        }
        .onAppear {
            currentIndex = allHighlights.firstIndex(where: { $0.id == highlight.id }) ?? 0
        }
    }
}
