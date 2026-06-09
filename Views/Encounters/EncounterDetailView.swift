import SwiftUI
import MapKit

struct EncounterDetailView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @Environment(\.dismiss) var dismiss
    @AppStorage("settings.privacyMode") private var privacyMode = false

    var encounter: Encounter

    @State private var showEditSheet  = false
    @State private var showDeleteAlert = false
    @State private var showPersonHistory = false

    private var displayName: String {
        privacyMode ? "Personne masquée" : encounter.firstName
    }

    private var cityText: String {
        guard !encounter.city.isEmpty else { return "" }
        return privacyMode ? "Lieu masqué" : encounter.city
    }

    private var heroSubtitle: String {
        let parts = [encounter.formattedDate, cityText].filter { !$0.isEmpty }
        return parts.joined(separator: " · ")
    }

    private var precisePlaceText: String {
        privacyMode ? "Lieu précis masqué" : encounter.precisePlace
    }

    private var hasHiddenPrivateDetails: Bool {
        privacyMode && (!encounter.tags.isEmpty || !encounter.greenFlags.isEmpty || !encounter.redFlags.isEmpty)
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: Hero
                Section {
                    HStack(spacing: 14) {
                        AvatarView(
                            initials: encounter.initials,
                            gender: encounter.gender,
                            encounterType: encounter.type ?? .body,
                            photoDataBase64: encounter.photoDataBase64,
                            customEmoji: encounter.customEmoji,
                            customEmojiBackgroundHex: encounter.customEmojiBackgroundHex,
                            size: 72
                        )
                        VStack(alignment: .leading, spacing: 6) {
                            Text(displayName)
                                .font(.title2.bold())
                            Text(heroSubtitle)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 6) {
                                TypeChip(type: encounter.type ?? .body)
                                if let ctx = encounter.context {
                                    DetailChip(text: ctx.rawValue, icon: ctx.icon)
                                }
                            }
                            if encounter.rating > 0 {
                                StarRatingView(rating: encounter.rating, size: 16, color: .yellow)
                            }
                        }
                        Spacer()
                        if let gender = encounter.gender, !privacyMode {
                            Text(gender.rawValue)
                                .font(.system(size: 11, weight: .semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.avatarBG(for: gender))
                                .foregroundColor(Color.avatarFG(for: gender))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 8)
                }

                // MARK: Info Grid
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        InfoTile(icon: "calendar", label: "Date", value: encounter.formattedDate)
                        InfoTile(icon: "clock", label: "Il y a", value: encounter.daysAgo)
                        InfoTile(icon: "mappin", label: "Ville", value: cityText.isEmpty ? "—" : cityText)
                        if let ctx = encounter.context {
                            InfoTile(icon: ctx.icon, label: "Contexte", value: ctx.rawValue)
                        }
                        if let age = encounter.age, !privacyMode {
                            InfoTile(icon: "person.text.rectangle", label: "Âge", value: "\(age) ans")
                        }
                        if !encounter.precisePlace.isEmpty {
                            InfoTile(icon: "mappin.and.ellipse", label: "Lieu précis", value: precisePlaceText)
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                
                // MARK: Criteria
                if encounter.outcome != nil || encounter.wouldMeetAgain {
                    Section(header: Text("Critères")) {
                        VStack(alignment: .leading, spacing: 10) {
                            if let outcome = encounter.outcome {
                                DetailPill(
                                    icon: outcome.icon,
                                    title: "Ressenti",
                                    value: outcome.rawValue,
                                    tint: .themeAccent
                                )
                            }
                            if encounter.wouldMeetAgain {
                                DetailPill(
                                    icon: "heart.fill",
                                    title: "Suite",
                                    value: "Tu souhaites revoir cette personne",
                                    tint: .green
                                )
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !privacyMode && !encounter.tags.isEmpty {
                    Section(header: Text("Tags perso")) {
                        FlowWrapView(items: encounter.tags) { item in
                            TagChip(text: item, tint: .themeAccent.opacity(0.2))
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                if !privacyMode && (!encounter.greenFlags.isEmpty || !encounter.redFlags.isEmpty) {
                    Section(header: Text("Green / Red Flags")) {
                        VStack(alignment: .leading, spacing: 10) {
                            if !encounter.greenFlags.isEmpty {
                                Text("Green flags")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.green)
                                FlowWrapView(items: encounter.greenFlags) { item in
                                    TagChip(text: item, tint: .green.opacity(0.22))
                                }
                            }
                            if !encounter.redFlags.isEmpty {
                                Text("Red flags")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(.red)
                                FlowWrapView(items: encounter.redFlags) { item in
                                    TagChip(text: item, tint: .red.opacity(0.22))
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                if hasHiddenPrivateDetails {
                    Section(header: Text("Données privées")) {
                        Label("Tags et flags masqués en mode discret", systemImage: "eye.slash.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: Mini Map
                if encounter.pinOnMap, let coord = encounter.coordinate {
                    Section(header: Text("Localisation")) {
                        MiniMapView(coordinate: coord)
                            .frame(height: 140)
                            .cornerRadius(12)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }

                // MARK: Note
                if !encounter.note.isEmpty {
                    Section(header: Text("Mémo privé")) {
                        if privacyMode {
                            Label("Note masquée en mode discret", systemImage: "eye.slash.fill")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .padding(.vertical, 4)
                        } else {
                            Text(encounter.note)
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                                .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: Actions
                Section {
                    if encounter.personId != nil {
                        Button {
                            showPersonHistory = true
                        } label: {
                            Label("Voir l’historique de cette personne", systemImage: "clock.arrow.circlepath")
                        }
                        .foregroundColor(.themeAccent)
                    }
                    
                    Button {
                        showEditSheet = true
                    } label: {
                        Label("Modifier", systemImage: "pencil")
                    }
                    .foregroundColor(.blue)

                    Button(role: .destructive) {
                        showDeleteAlert = true
                    } label: {
                        Label("Supprimer cette entrée", systemImage: "trash")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.themeAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showEditSheet = true
                    } label: {
                        Text("Modifier")
                            .foregroundColor(.themeAccent)
                    }
                }
            }
            .alert("Supprimer ?", isPresented: $showDeleteAlert) {
                Button("Supprimer", role: .destructive) {
                    vm.delete(encounter)
                    dismiss()
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible.")
            }
            .sheet(isPresented: $showEditSheet) {
                AddEncounterView(editingEncounter: encounter)
            }
            .sheet(isPresented: $showPersonHistory) {
                if let personID = encounter.personId {
                    PersonHistoryView(personID: personID)
                }
            }
        }
    }
}

// MARK: - Info Tile
struct InfoTile: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.themeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.themeSilver.opacity(0.22), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

struct TypeChip: View {
    let type: EncounterType

    var body: some View {
        HStack(spacing: 5) {
            Text(type.emoji)
            Text(type.rawValue)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .semibold))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.themeAccent.opacity(0.2))
        .foregroundColor(.themeSilver)
        .clipShape(Capsule())
    }
}

struct DetailChip: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
            Text(text)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.themeSurface)
        .overlay(
            Capsule().stroke(Color.themeSilver.opacity(0.2), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct DetailPill: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(tint)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
            }
            Spacer()
        }
        .padding(10)
        .background(Color.themeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.themeSilver.opacity(0.22), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct TagChip: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tint)
            .overlay(
                Capsule().stroke(Color.themeSilver.opacity(0.18), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct FlowWrapView<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), alignment: .leading)], alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

// MARK: - Mini Map
struct MiniMapView: UIViewRepresentable {
    let coordinate: CLLocationCoordinate2D

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.isUserInteractionEnabled = false
        map.layer.cornerRadius = 12
        let region = MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
        map.setRegion(region, animated: false)
        let pin = MKPointAnnotation()
        pin.coordinate = coordinate
        map.addAnnotation(pin)
        return map
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {}
}
