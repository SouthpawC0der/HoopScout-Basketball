//
//  CourtMapView.swift
//  HoopScout
//

import SwiftUI
import MapKit

struct CourtMapView: View {
    var onClose: () -> Void
    var onOpenCourt: (HSCourt) -> Void

    @EnvironmentObject private var location: LocationManager
    @EnvironmentObject private var courtSearch: CourtSearchService
    @EnvironmentObject private var courtRepo: CourtRepository
    @StateObject private var liveCounts = CourtLiveCountStore()

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedCourtId: String?

    private var courts: [HSCourt] {
        courtSearch.courts.isEmpty ? HSMockData.courts : courtSearch.courts
    }

    private var selectedCourt: HSCourt? {
        guard let id = selectedCourtId else { return nil }
        return courts.first { $0.id == id }
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition, selection: $selectedCourtId) {
                UserAnnotation()
                ForEach(courts) { court in
                    if let lat = court.latitude, let lon = court.longitude {
                        Annotation(court.name,
                                   coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon)) {
                            CourtPin(court: court,
                                     liveCount: liveCounts.counts[courtRepo.stableId(for: court)],
                                     isSelected: court.id == selectedCourtId)
                        }
                        .tag(court.id)
                    }
                }
            }
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }
            .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                if let c = selectedCourt {
                    bottomCard(c)
                }
            }
        }
        .task {
            if let coord = location.location?.coordinate {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coord,
                    latitudinalMeters: 8000,
                    longitudinalMeters: 8000))
                if courtSearch.courts.isEmpty {
                    await courtSearch.search(near: coord)
                }
            } else {
                cameraPosition = .userLocation(fallback: .automatic)
            }
            liveCounts.subscribe(courtIds: Set(courts.map { courtRepo.stableId(for: $0) }))
        }
        .onChange(of: courtSearch.courts) { _, newCourts in
            liveCounts.subscribe(courtIds: Set(newCourts.map { courtRepo.stableId(for: $0) }))
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(HSColors.navy)
                    .frame(width: 42, height: 42)
                    .background(.thinMaterial)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundColor(HSColors.gray500)
                Text(courtSearch.lastSearchLabel ?? "Courts near you")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(HSColors.gray900)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 16)
            .frame(height: 42)
            .background(.thinMaterial)
            .clipShape(Capsule())
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
        }
        .padding(.horizontal, 16)
        .padding(.top, 52)
    }

    private func bottomCard(_ court: HSCourt) -> some View {
        Button { onOpenCourt(court) } label: {
            HStack(spacing: 12) {
                HSCourtImage(variant: court.img, height: 66, cornerRadius: 12)
                    .frame(width: 66, height: 66)

                VStack(alignment: .leading, spacing: 1) {
                    let live = liveCounts.counts[courtRepo.stableId(for: court)] ?? court.playing
                    HStack(spacing: 8) {
                        HSLivePulse(size: 6)
                        Text("\(live) PLAYING")
                            .font(.system(size: 10, weight: .bold))
                            .kerning(1)
                            .foregroundColor(HSColors.live)
                    }
                    Text(court.name)
                        .font(.system(size: 15, weight: .heavy))
                        .kerning(-0.3)
                        .foregroundColor(HSColors.gray900)
                        .lineLimit(1)
                    Text("\(court.distance, specifier: "%.1f") mi · ★ \(court.rating, specifier: "%.1f")")
                        .font(.system(size: 12))
                        .foregroundColor(HSColors.gray500)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(HSColors.navy)
                    .clipShape(Circle())
                    .shadow(color: HSColors.navy.opacity(0.3), radius: 10, x: 0, y: 2)
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 30, x: 0, y: 18)
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .buttonStyle(.plain)
    }
}

private struct CourtPin: View {
    let court: HSCourt
    let liveCount: Int?
    let isSelected: Bool

    private var playing: Int { liveCount ?? court.playing }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 5) {
                if isSelected {
                    HSLivePulse(size: 6, color: HSColors.court)
                }
                Text("\(playing)")
                    .font(.system(size: 12, weight: .heavy))
                    .kerning(-0.2)
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(isSelected ? HSColors.navy : Color.white)
            .foregroundColor(isSelected ? .white : HSColors.navy)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: .black.opacity(isSelected ? 0.45 : 0.18),
                    radius: isSelected ? 12 : 5, x: 0, y: 4)
            Triangle()
                .fill(isSelected ? HSColors.navy : Color.white)
                .frame(width: 10, height: 6)
        }
        .scaleEffect(isSelected ? 1.12 : 1)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.closeSubpath()
        return p
    }
}

#Preview {
    CourtMapView(onClose: {}, onOpenCourt: { _ in })
        .environmentObject(LocationManager())
        .environmentObject(CourtSearchService())
        .environmentObject(CourtRepository.shared)
}
