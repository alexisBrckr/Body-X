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
    @AppStorage("settings.privacyMode") private var privacyMode = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 46.5, longitude: 2.3),
        span: MKCoordinateSpan(latitudeDelta: 8, longitudeDelta: 8)
    )
    @State private var selectedPin: Encounter?
    @State private var detailEncounter: Encounter?
    @State private var mapDisplayStyle: MapDisplayStyle = .standard
    @State private var selectedTypeFilter: MapTypeFilter = .all

    private enum MapDisplayStyle: String, CaseIterable {
        case standard = "standard"
        case satellite = "Satellite"

        var title: String {
            switch self {
            case .standard: return L10n.text("Plan", "Map")
            case .satellite: return L10n.text("Satellite", "Satellite")
            }
        }
    }

    private enum MapTypeFilter: String, CaseIterable, Identifiable {
        case all
        case body
        case preli
        case kiss

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all: return L10n.text("Toutes", "All")
            case .body: return EncounterType.body.localizedName
            case .preli: return EncounterType.preli.localizedName
            case .kiss: return EncounterType.kiss.localizedName
            }
        }

        var shortTitle: String {
            switch self {
            case .all: return L10n.text("Tous", "All")
            case .body: return "Body"
            case .preli: return "Preli"
            case .kiss: return "Kiss"
            }
        }

        var systemImage: String {
            switch self {
            case .all: return "mappin.and.ellipse"
            case .body: return EncounterType.body.icon
            case .preli: return EncounterType.preli.icon
            case .kiss: return EncounterType.kiss.icon
            }
        }

        var type: EncounterType? {
            switch self {
            case .all: return nil
            case .body: return .body
            case .preli: return .preli
            case .kiss: return .kiss
            }
        }

        func includes(_ encounter: Encounter) -> Bool {
            guard let type else { return true }
            return (encounter.type ?? .body) == type
        }
    }

    var annotations: [EncounterAnnotation] {
        vm.mappableEncounters.filter { selectedTypeFilter.includes($0) }.compactMap { e in
            guard let coord = e.coordinate else { return nil }
            return EncounterAnnotation(id: e.id, coordinate: coord, encounter: e)
        }
    }

    private func displayName(for encounter: Encounter) -> String {
        privacyMode ? L10n.text("Personne masquée", "Hidden person") : encounter.firstName
    }

    private func cityText(for encounter: Encounter) -> String {
        privacyMode ? L10n.text("Lieu masqué", "Hidden location") : encounter.city
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                mapContent
                    .ignoresSafeArea(edges: .top)

                VStack {
                    mapControls
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

                // Bottom card
                if let encounter = selectedPin {
                    pinDetailCard(encounter: encounter)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 8)
                }
            }
            .navigationTitle(L10n.text("Carte", "Map"))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { fitRegionToAnnotations() }
            .onChange(of: vm.mappableEncounters.count) { _ in
                clearSelectedPinIfHidden()
                fitRegionToAnnotations()
            }
            .onChange(of: selectedTypeFilter) { _ in
                selectedPin = nil
                fitRegionToAnnotations()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(L10n.text("\(annotations.count) pins", "\(annotations.count) pins"))
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

    private var mapControls: some View {
        HStack(spacing: 10) {
            filterMenu
            mapStyleControl
        }
    }

    private var filterMenu: some View {
        Menu {
            ForEach(MapTypeFilter.allCases) { filter in
                Button {
                    selectedTypeFilter = filter
                } label: {
                    if selectedTypeFilter == filter {
                        Label(filter.title, systemImage: "checkmark")
                    } else {
                        Label(filter.title, systemImage: filter.systemImage)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(selectedTypeFilter.shortTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
        }
        .foregroundColor(.primary)
    }

    @ViewBuilder
    private var mapContent: some View {
        if #available(iOS 17.0, *) {
            swiftUIMap
                .mapStyle(mapDisplayStyle == .satellite ? .imagery : .standard)
        } else if mapDisplayStyle == .satellite {
            LegacyEncounterMapView(
                region: $region,
                annotations: annotations,
                selectedPin: $selectedPin
            )
        } else {
            swiftUIMap
        }
    }

    private var swiftUIMap: some View {
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
    }

    private var mapStyleControl: some View {
        Picker(L10n.text("Style de carte", "Map style"), selection: $mapDisplayStyle) {
            ForEach(MapDisplayStyle.allCases, id: \.self) { style in
                Text(style.title).tag(style)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .padding(6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
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
                Text(displayName(for: encounter))
                    .font(.system(size: 15, weight: .semibold))
                Text("\(cityText(for: encounter)) · \(encounter.formattedDate)")
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

    private func clearSelectedPinIfHidden() {
        guard let selectedPin else { return }
        if !selectedTypeFilter.includes(selectedPin) || !vm.mappableEncounters.contains(where: { $0.id == selectedPin.id }) {
            self.selectedPin = nil
        }
    }
}

@MainActor
private struct LegacyEncounterMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let annotations: [EncounterAnnotation]
    @Binding var selectedPin: Encounter?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.mapType = .satellite
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        mapView.mapType = .satellite

        if mapView.region.isMeaningfullyDifferent(from: region) {
            mapView.setRegion(region, animated: false)
        }

        let legacyAnnotations = annotations.map(LegacyEncounterAnnotation.init)
        mapView.removeAnnotations(mapView.annotations)
        mapView.addAnnotations(legacyAnnotations)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LegacyEncounterMapView

        init(_ parent: LegacyEncounterMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.region = mapView.region
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let annotation = view.annotation as? LegacyEncounterAnnotation else { return }
            withAnimation(.spring()) {
                parent.selectedPin = annotation.encounter
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? LegacyEncounterAnnotation else { return nil }

            let identifier = "EncounterAvatarAnnotation"
            let annotationView = mapView.dequeueReusableAnnotationView(
                withIdentifier: identifier
            ) as? LegacyAvatarAnnotationView ?? LegacyAvatarAnnotationView(
                annotation: annotation,
                reuseIdentifier: identifier
            )

            annotationView.annotation = annotation
            annotationView.canShowCallout = false
            annotationView.configure(
                with: annotation.encounter,
                isSelected: parent.selectedPin?.id == annotation.encounter.id
            )
            return annotationView
        }
    }
}

@MainActor
private final class LegacyAvatarAnnotationView: MKAnnotationView {
    private let hostingController = UIHostingController(rootView: AnyView(EmptyView()))
    private let contentSize = CGSize(width: 52, height: 52)

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        bounds = CGRect(origin: .zero, size: contentSize)
        centerOffset = CGPoint(x: 0, y: -contentSize.height / 2)
        canShowCallout = false

        hostingController.view.backgroundColor = .clear
        hostingController.view.frame = bounds
        addSubview(hostingController.view)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        hostingController.view.frame = bounds
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        guard let annotation = annotation as? LegacyEncounterAnnotation else { return }
        configure(with: annotation.encounter, isSelected: selected)
    }

    func configure(with encounter: Encounter, isSelected: Bool) {
        hostingController.rootView = AnyView(
            ZStack {
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
                .scaleEffect(isSelected ? 1.2 : 1.0)
            }
            .frame(width: contentSize.width, height: contentSize.height)
        )
    }
}

private final class LegacyEncounterAnnotation: NSObject, MKAnnotation {
    let encounter: Encounter
    dynamic var coordinate: CLLocationCoordinate2D
    var title: String? { "Rencontre" }

    init(_ annotation: EncounterAnnotation) {
        self.encounter = annotation.encounter
        self.coordinate = annotation.coordinate
    }
}

private extension MKCoordinateRegion {
    func isMeaningfullyDifferent(from other: MKCoordinateRegion) -> Bool {
        abs(center.latitude - other.center.latitude) > 0.0001 ||
            abs(center.longitude - other.center.longitude) > 0.0001 ||
            abs(span.latitudeDelta - other.span.latitudeDelta) > 0.0001 ||
            abs(span.longitudeDelta - other.span.longitudeDelta) > 0.0001
    }
}
