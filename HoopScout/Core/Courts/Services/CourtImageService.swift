//
//  CourtImageService.swift
//  HoopScout
//
//  Renders a real-world snapshot for a court location using MKLookAround
//  where available, falling back to MKMapSnapshotter (satellite-flyover) if
//  not. Snapshots are cached in memory and on disk so we don't redraw on
//  every scroll.
//

import UIKit
import MapKit

@MainActor
final class CourtImageService {
    static let shared = CourtImageService()
    private init() {
        try? FileManager.default.createDirectory(at: diskDir,
                                                 withIntermediateDirectories: true)
    }

    private var memoryCache: [String: UIImage] = [:]
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    private let diskDir: URL = {
        let base = FileManager.default
            .urls(for: .cachesDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("CourtSnapshots", isDirectory: true)
    }()

    /// Returns a real-world snapshot of the given coordinate, sized to
    /// roughly `size` in points. Look Around is preferred; MKMapSnapshotter
    /// is the fallback if Look Around isn't available there.
    func snapshot(for coordinate: CLLocationCoordinate2D,
                  size: CGSize,
                  scale: CGFloat = UIScreen.main.scale) async -> UIImage? {
        let key = cacheKey(for: coordinate, size: size, scale: scale)

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
            let image = await self.fetchSnapshot(coordinate: coordinate,
                                                 size: size, scale: scale)
            if let image {
                self.memoryCache[key] = image
                self.writeDisk(image: image, key: key)
            }
            return image
        }
        inFlight[key] = task
        let result = await task.value
        inFlight[key] = nil
        return result
    }

    // MARK: - Cache layout

    private func cacheKey(for coordinate: CLLocationCoordinate2D,
                          size: CGSize, scale: CGFloat) -> String {
        let lat = (coordinate.latitude * 10_000).rounded() / 10_000
        let lon = (coordinate.longitude * 10_000).rounded() / 10_000
        return "\(lat)_\(lon)_\(Int(size.width))x\(Int(size.height))@\(Int(scale))x"
    }

    private func diskURL(for key: String) -> URL {
        diskDir.appendingPathComponent("\(key).jpg")
    }

    private func readDisk(key: String) -> UIImage? {
        let url = diskURL(for: key)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    private func writeDisk(image: UIImage, key: String) {
        guard let data = image.jpegData(compressionQuality: 0.78) else { return }
        try? data.write(to: diskURL(for: key), options: .atomic)
    }

    // MARK: - Fetch

    private func fetchSnapshot(coordinate: CLLocationCoordinate2D,
                               size: CGSize, scale: CGFloat) async -> UIImage? {
        if let look = await lookAroundSnapshot(coordinate: coordinate,
                                                size: size, scale: scale) {
            return look
        }
        return await mapSnapshot(coordinate: coordinate, size: size, scale: scale)
    }

    private func lookAroundSnapshot(coordinate: CLLocationCoordinate2D,
                                    size: CGSize, scale: CGFloat) async -> UIImage? {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let result = try? await request.scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        options.size = size
        let snapper = MKLookAroundSnapshotter(scene: result, options: options)
        guard let snapshot = try? await snapper.snapshot else { return nil }
        return snapshot.image
    }

    private func mapSnapshot(coordinate: CLLocationCoordinate2D,
                             size: CGSize, scale: CGFloat) async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 220,
            longitudinalMeters: 220)
        options.size = size
        options.scale = scale
        options.mapType = .hybridFlyover
        options.showsBuildings = true

        let snapper = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapper.start { snapshot, _ in
                continuation.resume(returning: snapshot?.image)
            }
        }
    }
}
