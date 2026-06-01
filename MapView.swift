import SwiftUI
import MapKit

// MARK: - Pin Annotation
struct EncounterAnnotation: Identifiable {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let encounter: Encounter
}

struct EncounterMapView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.3),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )
    @State private var selectedPin: Encounter?
    @State private var detailEncounter: Encounter?

    var annotations: [EncounterAnnotation] {
        vm.mappableEncounters.compactMap { e in
            guard let coord = e.coordinate else { return nil }
            return EncounterAnnotation(id: e.id, coordinate: coord, encounter: e)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(coordinateRegion: $region, annotationItems: annotations) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        pinView(for: pin.encounter)
                            .onTapGesture {
                                withAnimation(.spring()) {
                                    selectedPin = pin.encounter
                                }
                            }
                    }
                }
                .ignoresSafeArea(edges: .top)

                // Bottom card
                if let encounter = selectedPin {
                    pinDetailCard(encounter: encounter)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle("Carte")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { fitRegionToAnnotations() }
            .onChange(of: vm.mappableEncounters.count) { _ in
                fitRegionToAnnotations()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("\(vm.mappableEncounters.count) pins")
                        .font(.system(size: 13, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.themeAccent)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .sheet(item: $detailEncounter) { encounter in
                EncounterDetailView(encounter: encounter)
            }
        }
    }

    // MARK: - Pin View
    @ViewBuilder
    private func pinView(for encounter: Encounter) -> some View {
        AvatarView(
            initials: encounter.initials,
            gender: encounter.gender,
            encounterType: encounter.type ?? .body,
            photoDataBase64: encounter.photoDataBase64,
            customEmoji: encounter.customEmoji,
            customEmojiBackgroundHex: encounter.customEmojiBackgroundHex,
            size: 36
        )
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        .scaleEffect(selectedPin?.id == encounter.id ? 1.2 : 1.0)
        .animation(.spring(response: 0.3), value: selectedPin?.id)
    }

    // MARK: - Bottom Card
    private func pinDetailCard(encounter: Encounter) -> some View {
        HStack(spacing: 12) {
            AvatarView(
                initials: encounter.initials,
                gender: encounter.gender,
                encounterType: encounter.type ?? .body,
                photoDataBase64: encounter.photoDataBase64,
                customEmoji: encounter.customEmoji,
                customEmojiBackgroundHex: encounter.customEmojiBackgroundHex,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(encounter.firstName)
                    .font(.system(size: 15, weight: .semibold))
                Text("\(encounter.city) · \(encounter.formattedDate)")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                if encounter.rating > 0 {
                    StarRatingView(rating: encounter.rating, size: 12)
                }
            }

            Spacer()

            Button {
                detailEncounter = encounter
            } label: {
                Image(systemName: "arrow.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.themeAccent)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal)
    }

    private func fitRegionToAnnotations() {
        let coordinates = annotations.map(\.coordinate)
        guard !coordinates.isEmpty else { return }

        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude

        for coord in coordinates.dropFirst() {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }

        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.6, 0.08),
            longitudeDelta: max((maxLon - minLon) * 1.6, 0.08)
        )

        withAnimation(.easeInOut(duration: 0.35)) {
            region = MKCoordinateRegion(center: center, span: span)
        }
    }
}
