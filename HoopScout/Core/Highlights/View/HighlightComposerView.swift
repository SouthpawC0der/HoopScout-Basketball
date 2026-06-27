//
//  HighlightsComposerView.swift
//  HoopScout
//
//  Created by Christopher Doyle on 6/26/26.
//

//
//  HighlightComposerView.swift
//  HoopScout
//
//  Upload basketball highlight videos (up to 90 seconds).
//


//
//  HighlightComposerView.swift
//  HoopScout
//
//  Upload basketball highlight videos (up to 90 seconds).
//

import SwiftUI
import PhotosUI

struct HighlightComposerView: View {
    var onPost: (HSHighlight) -> Void
    
    @EnvironmentObject private var auth: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var caption: String = ""
    @State private var selectedVideo: PhotosPickerItem?
    @State private var videoURL: URL?
    @State private var videoDuration: TimeInterval = 0
    @State private var showDurationError = false
    @FocusState private var focused: Bool
    
    private var canPost: Bool {
        !caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        videoURL != nil &&
        videoDuration <= 90
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Video picker
                        videoPicker
                        
                        if showDurationError {
                            errorBanner
                        }
                        
                        // Caption input
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CAPTION")
                                .font(.system(size: 11, weight: .bold))
                                .kerning(1.2)
                                .foregroundColor(HSColors.gray500)
                            
                            TextEditor(text: $caption)
                                .focused($focused)
                                .font(.system(size: 15))
                                .foregroundColor(HSColors.gray900)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 100)
                                .padding(12)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(HSColors.gray200, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topLeading) {
                                    if caption.isEmpty {
                                        Text("Describe your highlight...")
                                            .font(.system(size: 15))
                                            .foregroundColor(HSColors.gray500)
                                            .padding(.top, 20)
                                            .padding(.leading, 16)
                                            .allowsHitTesting(false)
                                    }
                                }
                        }
                        
                        // Tips
                        tipsSection
                    }
                    .padding(20)
                }
            }
            .background(HSColors.bg)
            .navigationTitle("Upload Highlight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HSColors.gray500)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        guard canPost else { return }
                        let highlight = makeHighlight()
                        onPost(highlight)
                    }
                    .fontWeight(.bold)
                    .foregroundColor(canPost ? HSColors.navy : HSColors.gray500)
                    .disabled(!canPost)
                }
            }
        }
    }
    
    private var videoPicker: some View {
        PhotosPicker(selection: $selectedVideo, matching: .videos) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(HSColors.gray200, lineWidth: 1)
                    )
                
                if let videoURL {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(HSColors.live)
                        Text("Video selected")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                        Text("\(Int(videoDuration))s duration")
                            .font(.system(size: 12))
                            .foregroundColor(HSColors.gray500)
                        Text("Tap to change")
                            .font(.system(size: 11))
                            .foregroundColor(HSColors.gray500)
                    }
                    .frame(height: 200)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(HSColors.navy)
                        Text("Select a video")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(HSColors.gray900)
                        Text("Up to 90 seconds")
                            .font(.system(size: 13))
                            .foregroundColor(HSColors.gray500)
                    }
                    .frame(height: 200)
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: selectedVideo) { _, newValue in
            Task {
                await loadVideo(from: newValue)
            }
        }
    }
    
    private var errorBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Video too long")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(HSColors.gray900)
                Text("Please select a video under 90 seconds")
                    .font(.system(size: 12))
                    .foregroundColor(HSColors.gray700)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TIPS FOR GREAT HIGHLIGHTS")
                .font(.system(size: 11, weight: .bold))
                .kerning(1.2)
                .foregroundColor(HSColors.gray500)
            
            VStack(alignment: .leading, spacing: 8) {
                tipRow(icon: "camera.fill", text: "Film in good lighting")
                tipRow(icon: "waveform", text: "Keep audio clear")
                tipRow(icon: "clock.fill", text: "Trim to the best moments")
                tipRow(icon: "text.alignleft", text: "Write engaging captions")
            }
            .padding(14)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HSColors.gray200, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
    
    private func tipRow(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(HSColors.navy)
                .frame(width: 20)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(HSColors.gray700)
            Spacer()
        }
    }
    
    private func loadVideo(from item: PhotosPickerItem?) async {
        guard let item else { return }
        
        // In production, you'd load the actual video here
        // For now, simulate with mock data
        videoURL = URL(string: "mock://video")
        videoDuration = Double.random(in: 10...120)
        
        if videoDuration > 90 {
            showDurationError = true
            videoURL = nil
        } else {
            showDurationError = false
        }
    }
    
    private func makeHighlight() -> HSHighlight {
        HSHighlight(
            authorId: auth.profile?.id ?? "me",
            authorName: auth.profile?.name ?? "You",
            authorInitials: auth.profile?.initials ?? "?",
            videoURL: videoURL,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: videoDuration,
            authorIsPrivate: auth.profile?.isPrivate
        )
    }
}

