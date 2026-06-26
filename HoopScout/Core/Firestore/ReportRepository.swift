//
//  ReportRepository.swift
//  HoopScout
//
//  Writes user-submitted reports of objectionable content / users to a
//  top-level `reports` collection. Reports are reviewed out-of-band (Cloud
//  Functions + moderator console). Required by App Store Guideline 1.2 for
//  any app surfacing user-generated content.
//

import Foundation
import FirebaseFirestore

enum HSReportEntity: String {
    case user
    case post
    case comment
    case message
    case thread
}

enum HSReportReason: String, CaseIterable, Identifiable {
    case spam
    case harassment
    case hate
    case sexual
    case violence
    case impersonation
    case other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .spam:          return "Spam"
        case .harassment:    return "Harassment or bullying"
        case .hate:          return "Hate speech"
        case .sexual:        return "Sexual or explicit content"
        case .violence:      return "Violence or threats"
        case .impersonation: return "Impersonation or fake account"
        case .other:         return "Something else"
        }
    }
}

final class ReportRepository {
    static let shared = ReportRepository()
    private init() {}

    private var collection: CollectionReference {
        Firestore.firestore().collection("reports")
    }

    /// Submit a report. `reportedUid` should be set for user-authored
    /// content so moderators can pivot on the offender.
    func submit(entity: HSReportEntity,
                entityId: String,
                reason: HSReportReason,
                reportedUid: String?,
                reporterUid: String,
                details: String? = nil) async throws {
        var data: [String: Any] = [
            "entityType": entity.rawValue,
            "entityId": entityId,
            "reason": reason.rawValue,
            "reporterUid": reporterUid,
            "status": "pending",
            "createdAt": FieldValue.serverTimestamp()
        ]
        if let reportedUid, !reportedUid.isEmpty {
            data["reportedUid"] = reportedUid
        }
        if let details, !details.isEmpty {
            data["details"] = String(details.prefix(2000))
        }
        try await collection.addDocument(data: data)
    }
}
