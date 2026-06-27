//
//  ProfilePhotoService.swift
//  HoopScout
//

import Foundation
import UIKit
import FirebaseStorage

enum ProfilePhotoError: LocalizedError {
    case encodingFailed

    var errorDescription: String? {
        switch self {
        case .encodingFailed: return "Couldn't process that image."
        }
    }
}

@MainActor
final class ProfilePhotoService {
    static let shared = ProfilePhotoService()
    private init() {}

    /// Uploads `image` to `users/{uid}/avatar.jpg` and returns the public URL.
    /// Retries the upload twice on transient errors before giving up.
    func uploadAvatar(_ image: UIImage, uid: String) async throws -> String {
        let resized = Self.resize(image, maxDimension: 512)
        guard let data = resized.jpegData(compressionQuality: 0.82) else {
            throw ProfilePhotoError.encodingFailed
        }

        let ref = Storage.storage().reference()
            .child("users/\(uid)/avatar.jpg")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        var attempt = 0
        var lastError: Error?
        while attempt < 3 {
            do {
                _ = try await ref.putDataAsync(data, metadata: metadata)
                let url = try await ref.downloadURL()
                return url.absoluteString
            } catch {
                lastError = error
                attempt += 1
                if attempt < 3 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 600_000_000)
                }
            }
        }
        throw lastError ?? ProfilePhotoError.encodingFailed
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
