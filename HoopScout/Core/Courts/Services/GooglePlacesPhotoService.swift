//
//  GooglePlacesPhotoService.swift
//  HoopScout
//
//  Looks up a real-world photo for a court via Google Places
//  (Find Place From Text → Place Photo) and caches the rendered image to
//  disk so repeat views don't pay the Places quota. No-ops silently when
//  `GooglePlacesAPIKey` is missing from Info.plist, so the rest of the
//  snapshot chain still works.
//

import Foundation
import UIKit
import CoreLocation

@MainActor
final class GooglePlacesPhotoService {
    static let shared = GooglePlacesPhotoService()
    private init() {
        try? FileManager.default.createDirectory(at: diskDir,
                                                 withIntermediateDirectories: true)
    }

    private var memoryCache: [String: UIImage] = [:]
    private var missCache: Set<String> = []
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private let diskDir: URL = {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("PlacesPhotos", isDirectory: true)
    }()

    /// Reads `GooglePlacesAPIKey` from Info.plist. Returns nil if unset or
    /// left as a placeholder build-setting reference.
    private var apiKey: String? {
        guard let key = Bundle.main
            .object(forInfoDictionaryKey: "GooglePlacesAPIKey") as? String,
              !key.isEmpty,
              !key.hasPrefix("$(") else { return nil }
        return key
    }

    /// Returns a Places photo of `name` near `coordinate`, or nil if Places
    /// has no matching listing (common for unnamed park courts).
    func photo(for name: String,
               coordinate: CLLocationCoordinate2D,
               maxWidth: Int = 800) async -> UIImage? {
        guard apiKey != nil else { return nil }
        let key = cacheKey(name: name, coordinate: coordinate, maxWidth: maxWidth)
        if missCache.contains(key) { return nil }
        if let cached = memoryCache[key] { return cached }
        if let disk = readDisk(key: key) {
            memoryCache[key] = disk
            return disk
        }
        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> { [weak self] in
            guard let self else { return nil }
            let img = await self.fetch(name: name,
                                       coordinate: coordinate,
                                       maxWidth: maxWidth)
            if let img {
                self.memoryCache[key] = img
                self.writeDisk(image: img, key: key)
            } else {
                self.missCache.insert(key)
            }
            return img
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    // MARK: - Network

    private func fetch(name: String,
                       coordinate: CLLocationCoordinate2D,
                       maxWidth: Int) async -> UIImage? {
        guard let apiKey,
              let reference = await photoReference(name: name,
                                                   coordinate: coordinate,
                                                   apiKey: apiKey)
        else { return nil }

        var components = URLComponents(string:
            "https://maps.googleapis.com/maps/api/place/photo")
        components?.queryItems = [
            URLQueryItem(name: "maxwidth", value: String(maxWidth)),
            URLQueryItem(name: "photo_reference", value: reference),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private func photoReference(name: String,
                                coordinate: CLLocationCoordinate2D,
                                apiKey: String) async -> String? {
        var components = URLComponents(string:
            "https://maps.googleapis.com/maps/api/place/findplacefromtext/json")
        components?.queryItems = [
            URLQueryItem(name: "input", value: name),
            URLQueryItem(name: "inputtype", value: "textquery"),
            URLQueryItem(name: "fields", value: "photos,place_id,name"),
            URLQueryItem(name: "locationbias",
                         value: "point:\(coordinate.latitude),\(coordinate.longitude)"),
            URLQueryItem(name: "key", value: apiKey)
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try JSONSerialization
                    .jsonObject(with: data) as? [String: Any],
                  let candidates = json["candidates"] as? [[String: Any]],
                  let first = candidates.first,
                  let photos = first["photos"] as? [[String: Any]],
                  let ref = photos.first?["photo_reference"] as? String
            else { return nil }
            return ref
        } catch {
            return nil
        }
    }

    // MARK: - Cache

    private func cacheKey(name: String,
                          coordinate: CLLocationCoordinate2D,
                          maxWidth: Int) -> String {
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        let slug = name.lowercased()
            .filter { $0.isLetter || $0.isNumber }
        return "\(slug)_\(lat)_\(lon)_w\(maxWidth)"
    }

    private func diskURL(for key: String) -> URL {
        diskDir.appendingPathComponent("\(key).jpg")
    }

    private func readDisk(key: String) -> UIImage? {
        guard let data = try? Data(contentsOf: diskURL(for: key)) else { return nil }
        return UIImage(data: data)
    }

    private func writeDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.82) else { return }
        try? data.write(to: diskURL(for: key), options: .atomic)
    }
}
