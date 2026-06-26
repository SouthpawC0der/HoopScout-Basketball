//
//  CourtSnapshotImage.swift
//  HoopScout
//
//  Renders a real-world image for a court. Priority chain:
//    1. User-uploaded `photoURL` (Firebase Storage)
//    2. Google Places photo (when courtName is supplied + API key configured)
//    3. MKLookAround street-level snapshot
//    4. MKMapSnapshotter satellite-flyover
//    5. Painted gradient variant
//  Hides loading behind the painted variant to avoid empty space while
//  imagery streams in.
//

import SwiftUI
import CoreLocation

struct CourtSnapshotImage: View {
    let coordinate: CLLocationCoordinate2D?
    var courtName: String? = nil
    var photoURL: String? = nil
    let height: CGFloat
    let cornerRadius: CGFloat
    let fallback: HSCourtImageVariant

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            HSCourtImage(variant: fallback,
                         height: height,
                         cornerRadius: cornerRadius)
                .opacity(image == nil ? 1 : 0)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: height)
                    .frame(height: height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius,
                                                style: .continuous))
                    .transition(.opacity)
            }
        }
        .frame(height: height)
        .task(id: taskKey) {
            await loadImage()
        }
    }

    private func loadImage() async {
        // 1. User-uploaded photo wins immediately.
        if let photoURL,
           let url = URL(string: photoURL),
           let img = await loadRemote(url) {
            set(img)
            return
        }

        // 2. Google Places — only when we have a name (skip on list thumbs).
        if let courtName, !courtName.isEmpty, let coordinate,
           let img = await GooglePlacesPhotoService.shared
                .photo(for: courtName, coordinate: coordinate) {
            set(img)
            return
        }

        // 3 + 4. Fall back to the map-based snapshot chain.
        guard let coordinate, image == nil else { return }
        let targetSize = CGSize(width: 800, height: height * 2)
        if let snap = await CourtImageService.shared
            .snapshot(for: coordinate, size: targetSize) {
            set(snap)
        }
    }

    private func set(_ img: UIImage) {
        withAnimation(.easeInOut(duration: 0.25)) {
            self.image = img
        }
    }

    private func loadRemote(_ url: URL) async -> UIImage? {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }

    private var taskKey: String {
        let coord = coordinate.map { "\($0.latitude),\($0.longitude)" } ?? "no-coord"
        return "\(coord)|\(Int(height))|\(photoURL ?? "")|\(courtName ?? "")"
    }
}
