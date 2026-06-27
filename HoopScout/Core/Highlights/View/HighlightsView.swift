//
//  HighlightsView.swift
//  HoopScout
//
//  Created by Christopher Doyle on 6/26/26.
//

//
//  HighlightsView.swift
//  HoopScout
//
//  Full-screen vertical video feed similar to TikTok/Reels for basketball
//  highlights. Users can swipe up/down to navigate between videos.
//

import SwiftUI
import AVKit

struct HighlightsView: View {
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var blocks: BlockRepository
    @State private var highlights: [HSHighlight] = HSHighlightMock.highlights
    @State private var currentIndex: Int = 0
    @State private var liked: Set<String> = []
    @State private var showComposer = false
    @State private var dragOffset: CGFloat = 0
    
    private var displayed: [HSHighlight] {
        highlights.filter { !blocks.isBlocked($0.authorId) }
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .topTrailing) {
                Color.black.ignoresSafeArea()
                
                TabView(selection: $currentIndex) {
                    ForEach(Array(displayed.enumerated()), id: \.element.id) { index, highlight in
                        HighlightPlayerView(
                            highlight: highlight,
                            isLiked: liked.contains(highlight.id),
                            onLike: { toggleLike(highlight.id) },
                            onComment: { /* TODO */ },
                            onRepost: { /* TODO */ },
                            onShare: { /* TODO */ },
                            onOptions: { /* TODO */ }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Top overlay with title and upload button
                VStack {
                    HStack {
                        Text("HIGHLIGHTS")
                            .font(.system(size: 12, weight: .bold))
                            .kerning(1.5)
                            .foregroundColor(.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.3), radius: 4)
                        
                        Spacer()
                        
                        Button {
                            showComposer = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 54)
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showComposer) {
                HighlightComposerView { highlight in
                    highlights.insert(highlight, at: 0)
                    showComposer = false
                }
                .presentationDetents([.large])
            }
        }
    }
    
    private func toggleLike(_ id: String) {
        if liked.contains(id) {
            liked.remove(id)
            if let idx = highlights.firstIndex(where: { $0.id == id }) {
                highlights[idx].likes = max(0, highlights[idx].likes - 1)
            }
        } else {
            liked.insert(id)
            if let idx = highlights.firstIndex(where: { $0.id == id }) {
                highlights[idx].likes += 1
            }
        }
    }
}

// MARK: - Individual Highlight Player

struct HighlightPlayerView: View {
    let highlight: HSHighlight
    let isLiked: Bool
    let onLike: () -> Void
    let onComment: () -> Void
    let onRepost: () -> Void
    let onShare: () -> Void
    let onOptions: () -> Void
    
    @State private var showCaption = true
    
    var body: some View {
        ZStack {
            // Video player placeholder (would use AVPlayer in production)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [HSColors.navy2, HSColors.navy, .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Mock video placeholder
            VStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 64, weight: .light))
                    .foregroundColor(.white.opacity(0.3))
                Text("Video: \(highlight.caption)")
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            // Right side action buttons
            VStack(spacing: 24) {
                Spacer()
                
                actionButton(
                    icon: isLiked ? "heart.fill" : "heart",
                    label: formatCount(highlight.likes),
                    color: isLiked ? .red : .white,
                    action: onLike
                )
                
                actionButton(
                    icon: "bubble.right.fill",
                    label: formatCount(highlight.comments),
                    action: onComment
                )
                
                actionButton(
                    icon: "arrow.2.squarepath",
                    label: formatCount(highlight.reposts),
                    action: onRepost
                )
                
                actionButton(
                    icon: "paperplane.fill",
                    label: "Share",
                    action: onShare
                )
                
                actionButton(
                    icon: "ellipsis",
                    label: "",
                    action: onOptions
                )
                
                // Author avatar
                NavigationLink {
                    // TODO: Link to author profile
                    EmptyView()
                } label: {
                    HSAvatar(
                        uid: highlight.authorId,
                        initials: highlight.authorInitials,
                        size: 44
                    )
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.trailing, 12)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .trailing)
            
            // Bottom caption area
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                
                HStack(spacing: 8) {
                    Text("@\(highlight.authorName)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                    
                    Spacer()
                }
                
                if showCaption {
                    Text(highlight.caption)
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .lineLimit(3)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
                
                Text("\(formatCount(highlight.views)) views")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 4)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 100)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onTapGesture {
            withAnimation { showCaption.toggle() }
        }
    }
    
    private func actionButton(
        icon: String,
        label: String,
        color: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(color)
                    .shadow(color: .black.opacity(0.3), radius: 4)
                
                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 4)
                }
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
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
