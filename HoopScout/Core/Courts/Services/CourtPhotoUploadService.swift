//
//  CourtPhotoUploadService.swift
//  HoopScout
//
//  Uploads a user-supplied photo of a court to Firebase Storage and writes
//  the resulting URL onto the court's Firestore doc as `photoURL`. Last
//  write wins — moderation goes through the existing report flow.
//

import Foundation
import UIKit
import FirebaseStorage

enum CourtPhotoError: LocalizedError {
    case encodingFailed
    case missingCourtId

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Couldn't process that image."
        case .missingCourtId: return "Couldn't identify the court."
        }
    }
}

@MainActor
final class CourtPhotoUploadService {
    static let shared = CourtPhotoUploadService()
    private init() {}

    /// Resizes, uploads, then writes `photoURL` on the court doc. Returns
    /// the public download URL.
    func upload(_ image: UIImage,
                courtId: String,
                uid: String) async throws -> String {
        guard !courtId.isEmpty else { throw CourtPhotoError.missingCourtId }
        let resized = Self.resize(image, maxDimension: 1280)
        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw CourtPhotoError.encodingFailed
        }

        let ref = Storage.storage().reference()
            .child("courts/\(courtId)/hero-\(uid).jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        var attempt = 0
        var lastError: Error?
        while attempt < 3 {
            do {
                _ = try await ref.putDataAsync(data, metadata: metadata)
                let url = try await ref.downloadURL()
                try await CourtRepository.shared.setPhotoURL(
                    courtId: courtId,
                    url: url.absoluteString,
                    uploaderUID: uid)
                return url.absoluteString
            } catch {
                lastError = error
                attempt += 1
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 600_000_000)
                }
            }
        }
        throw lastError ?? CourtPhotoError.encodingFailed
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let largest = max(size.width, size.height)
        guard largest > maxDimension else { return image }
        let scale = maxDimension / largest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
