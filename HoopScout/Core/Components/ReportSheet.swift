//
//  ReportSheet.swift
//  HoopScout
//
//  Modal sheet used everywhere a hooper can report objectionable content.
//  Submits to ReportRepository so reports are persisted and reviewable —
//  no fake "thanks!" alerts.
//

import SwiftUI

struct ReportSheet: View {
    let entity: HSReportEntity
    let entityId: String
    let reportedUid: String?
    let reporterUid: String
    let subjectLabel: String
    var onSubmitted: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var reason: HSReportReason = .spam
    @State private var details: String = ""
    @State private var submitting = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Help us keep HoopScout safe. Reports are reviewed and we act on violations within 24 hours.")
                        .font(.system(size: 13))
                        .foregroundColor(HSColors.gray700)

                    Text("WHAT'S WRONG?")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(HSColors.gray500)

                    VStack(spacing: 8) {
                        ForEach(HSReportReason.allCases) { r in
                            reasonRow(r)
                        }
                    }

                    Text("MORE DETAIL (OPTIONAL)")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(1.2)
                        .foregroundColor(HSColors.gray500)
                        .padding(.top, 4)

                    TextField("What happened?", text: $details, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.system(size: 14))
                        .padding(12)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12))
                            .foregroundColor(.red.opacity(0.85))
                    }
                }
                .padding(20)
            }
            .background(HSColors.bg.ignoresSafeArea())
            .navigationTitle("Report \(subjectLabel)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(HSColors.gray500)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(submitting ? "Sending…" : "Submit") {
                        Task { await submit() }
                    }
                    .foregroundColor(HSColors.navy)
                    .fontWeight(.bold)
                    .disabled(submitting)
                }
            }
        }
    }

    private func reasonRow(_ r: HSReportReason) -> some View {
        Button { reason = r } label: {
            HStack {
                Text(r.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HSColors.gray900)
                Spacer()
                Image(systemName: reason == r ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(reason == r ? HSColors.navy : HSColors.gray300)
            }
            .padding(.horizontal, 14).frame(height: 48)
            .background(Color.white)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(HSColors.gray200, lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        do {
            try await ReportRepository.shared.submit(
                entity: entity,
                entityId: entityId,
                reason: reason,
                reportedUid: reportedUid,
                reporterUid: reporterUid,
                details: details.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            onSubmitted?()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
