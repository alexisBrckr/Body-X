import SwiftUI
import Combine
import CoreLocation
import MapKit
import UIKit

struct AddEncounterView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @Environment(\.dismiss) var dismiss

    // Edit mode
    var editingEncounter: Encounter?

    // Form fields
    @State private var firstName: String = ""
    @State private var age: Int = 25
    @State private var date: Date = Date()
    @State private var gender: Gender? = .male
    @State private var context: EncounterContext? = nil
    @State private var encounterType: EncounterType = .body
    @State private var city: String = ""
    @State private var precisePlace: String = ""
    @State private var rating: Double = 0
    @State private var outcome: EncounterOutcome? = nil
    @State private var wouldMeetAgain: Bool = false
    @State private var note: String = ""
    @State private var pinOnMap: Bool = false
    @State private var photoDataBase64: String = ""
    @State private var customEmoji: String = ""
    @State private var customEmojiBackgroundColor: Color = Color(hex: "#C084FC")
    @State private var showPhotoSourceDialog = false
    @State private var showEmojiEditor = false
    @State private var showPhotoPicker = false
    @State private var photoSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var greenFlagsInput: String = ""
    @State private var redFlagsInput: String = ""
    @State private var selectedLatitude: Double?
    @State private var selectedLongitude: Double?
    @StateObject private var addressAutocomplete = AddressAutocompleteService()
    @FocusState private var focusedField: FocusedField?
    @State private var isApplyingAddressSuggestion = false

    @State private var showValidation = false
    private var isEditing: Bool { editingEncounter != nil }
    
    enum PersonLinkMode: String, CaseIterable {
        case new = "Nouvelle personne"
        case existing = "Personne existante"
    }

    private enum FocusedField {
        case address
    }

    @State private var personLinkMode: PersonLinkMode = .new
    @State private var selectedExistingPersonID: UUID? = nil
    
    private let emojiSuggestions: [String] = ["😀","😎","🥰","😘","🤩","😈","🥳","🤍","🔥","✨","🌹","🦋","🍸","🎵","☕️","🌙"]
    private let emojiColorPresets: [Color] = [
        Color(hex: "#C084FC"), Color(hex: "#F472B6"), Color(hex: "#60A5FA"),
        Color(hex: "#34D399"), Color(hex: "#F59E0B"), Color(hex: "#F87171"),
        Color(hex: "#A3A3A3"), Color(hex: "#1F2937")
    ]

    private var firstNameBinding: Binding<String> {
        Binding(
            get: { firstName },
            set: { firstName = InputSanitizer.cleanSingleLine($0, maxLength: 60) }
        )
    }

    private var cityBinding: Binding<String> {
        Binding(
            get: { city },
            set: { city = InputSanitizer.cleanSingleLine($0, maxLength: 80) }
        )
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { precisePlace },
            set: { precisePlace = InputSanitizer.cleanSingleLine($0, maxLength: 160) }
        )
    }

    private var greenFlagsBinding: Binding<String> {
        Binding(
            get: { greenFlagsInput },
            set: { greenFlagsInput = InputSanitizer.cleanSingleLine($0, maxLength: 250) }
        )
    }

    private var redFlagsBinding: Binding<String> {
        Binding(
            get: { redFlagsInput },
            set: { redFlagsInput = InputSanitizer.cleanSingleLine($0, maxLength: 250) }
        )
    }

    private var noteBinding: Binding<String> {
        Binding(
            get: { note },
            set: { note = InputSanitizer.cleanMultiLine($0, maxLength: 800) }
        )
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Avatar Preview
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Button {
                                showPhotoSourceDialog = true
                            } label: {
                                AvatarView(
                                    initials: firstName.isEmpty ? "?" : String(firstName.prefix(2)).uppercased(),
                                    gender: gender,
                                    photoDataBase64: photoDataBase64,
                                    customEmoji: customEmoji,
                                    customEmojiBackgroundHex: customEmojiBackgroundColor.toHexString(),
                                    size: 72
                                )
                            }
                            .buttonStyle(.plain)
                            
                            Text("Touchez l’avatar pour ajouter une photo")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                            if !firstName.isEmpty {
                                Text(firstName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                    .padding(.vertical, 4)
                }

                // MARK: Identité
                Section(header: Text("Identité")) {
                    if !vm.personSummaries.isEmpty {
                        Picker("Lier la rencontre", selection: $personLinkMode) {
                            ForEach(PersonLinkMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if personLinkMode == .existing {
                            Picker("Personne", selection: $selectedExistingPersonID) {
                                Text("Choisir...").tag(Optional<UUID>.none)
                                ForEach(vm.personSummaries) { person in
                                    Text(person.displayName).tag(Optional(person.id))
                                }
                            }
                            .onChange(of: selectedExistingPersonID) { newValue in
                                applyIdentityFromExistingPerson(newValue)
                            }
                        }
                    }
                    
                    TextField("Prénom ou surnom", text: firstNameBinding)
                        .disabled(personLinkMode == .existing)
                        .overlay(
                            showValidation && firstName.isEmpty
                            ? RoundedRectangle(cornerRadius: 6).stroke(Color.red, lineWidth: 1)
                            : nil
                        )
                    
                    Stepper(value: $age, in: 18...99) {
                        HStack {
                            Text("Âge")
                            Spacer()
                            Text("\(age) ans")
                                .foregroundColor(.secondary)
                        }
                    }
                    .disabled(personLinkMode == .existing)

                    Picker("Genre", selection: $gender) {
                        ForEach(Gender.selectableCases, id: \.self) { g in
                            Text(g.rawValue).tag(Optional(g))
                        }
                    }
                    .disabled(personLinkMode == .existing)
                }

                // MARK: Contexte
                Section(header: Text("Contexte")) {
                    DatePicker("Date de la rencontre", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .environment(\.locale, Locale(identifier: "fr_FR"))
                    
                    Picker("Type", selection: $encounterType) {
                        ForEach(EncounterType.allCases, id: \.self) { type in
                            Label(type.rawValue, systemImage: type.icon).tag(type)
                        }
                    }

                    TextField("Ville", text: cityBinding)
                    TextField("Adresse", text: addressBinding)
                        .focused($focusedField, equals: .address)
                        .onChange(of: precisePlace) { newValue in
                            guard !isApplyingAddressSuggestion else { return }
                            addressAutocomplete.updateQuery(newValue, cityHint: city)
                        }
                        .onChange(of: city) { newValue in
                            guard !isApplyingAddressSuggestion else { return }
                            addressAutocomplete.updateQuery(precisePlace, cityHint: newValue)
                        }
                    
                    if !addressAutocomplete.suggestions.isEmpty && !precisePlace.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(addressAutocomplete.suggestions.prefix(5))) { suggestion in
                                Button {
                                    applyAddressSuggestion(suggestion)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.title)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        if !suggestion.subtitle.isEmpty {
                                            Text(suggestion.subtitle)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 8)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    Picker("Contexte", selection: $context) {
                        Text("Non précisé").tag(Optional<EncounterContext>.none)
                        ForEach(EncounterContext.allCases, id: \.self) { c in
                            Label(c.rawValue, systemImage: c.icon).tag(Optional(c))
                        }
                    }
                }

                // MARK: Note
                Section(header: Text("Note globale")) {
                    HStack {
                        StarPickerView(rating: $rating)
                        Spacer()
                        if rating > 0 {
                            Text("\(RatingScale.formatted(rating)) / 5")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Critères
                Section(header: Text("Critères")) {
                    Picker("Ressenti", selection: $outcome) {
                        Text("Non précisé").tag(Optional<EncounterOutcome>.none)
                        ForEach(EncounterOutcome.allCases, id: \.self) { value in
                            Label(value.rawValue, systemImage: value.icon).tag(Optional(value))
                        }
                    }

                    Toggle("Je souhaite revoir cette personne", isOn: $wouldMeetAgain)
                        .tint(.themeAccent)
                }
                // MARK: Flags
                Section(header: Text("Flags")) {
                    TextField("Green flags", text: greenFlagsBinding)
                    TextField("Red flags", text: redFlagsBinding)
                }

                // MARK: Carte
                Section(header: Text("Carte")) {
                    Toggle(isOn: $pinOnMap) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Épingler sur la carte")
                                .font(.system(size: 15))
                            Text("Utilise la ville saisie pour géolocaliser")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                    .tint(.themeAccent)
                }

                // MARK: Mémo
                Section(header: Text("Mémo privé")) {
                    TextEditor(text: noteBinding)
                        .frame(minHeight: 80)
                        .font(.system(size: 15))
                }
            }
            .navigationTitle(isEditing ? "Modifier" : "Nouvelle entrée")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Annuler") { dismiss() }
                        .foregroundColor(.themeAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "Enregistrer" : "Ajouter") {
                        let missingExistingPerson = personLinkMode == .existing && selectedExistingPersonID == nil
                        guard !firstName.isEmpty && !missingExistingPerson else {
                            showValidation = true
                            return
                        }
                        saveEncounter()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(.themeAccent)
                }
            }
            .onAppear { prefillIfEditing() }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: photoSourceType, allowsEditing: true) { image in
                    if let data = image.jpegData(compressionQuality: 0.85) {
                        photoDataBase64 = data.base64EncodedString()
                    }
                }
            }
            .confirmationDialog("Photo de la rencontre", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("Choisir une photo") {
                    photoSourceType = .photoLibrary
                    showPhotoPicker = true
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Prendre une photo") {
                        photoSourceType = .camera
                        showPhotoPicker = true
                    }
                }
                Button("Personnaliser avec un emoji") {
                    showEmojiEditor = true
                }
                if !photoDataBase64.isEmpty {
                    Button("Supprimer la photo", role: .destructive) {
                        photoDataBase64 = ""
                    }
                }
                Button("Annuler", role: .cancel) {}
            }
            .sheet(isPresented: $showEmojiEditor) {
                NavigationStack {
                    ScrollView {
                        VStack(spacing: 18) {
                            AvatarView(
                                initials: firstName.isEmpty ? "?" : String(firstName.prefix(2)).uppercased(),
                                gender: gender,
                                photoDataBase64: "",
                                customEmoji: customEmoji,
                                customEmojiBackgroundHex: customEmojiBackgroundColor.toHexString(),
                                size: 92
                            )
                            .padding(.top, 6)
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Emoji")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)

                                TextField("Emoji personnalisé", text: Binding(
                                    get: { customEmoji },
                                    set: { customEmoji = InputSanitizer.cleanEmoji($0) }
                                ))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                                    ForEach(emojiSuggestions, id: \.self) { emoji in
                                        Button {
                                            customEmoji = InputSanitizer.cleanEmoji(emoji)
                                        } label: {
                                            Text(emoji)
                                                .font(.system(size: 24))
                                                .frame(width: 40, height: 40)
                                                .background(Color.themeSurface)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Couleur de fond")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                
                                HStack(spacing: 12) {
                                    ForEach(Array(emojiColorPresets.enumerated()), id: \.offset) { _, color in
                                        Button {
                                            customEmojiBackgroundColor = color
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            customEmojiBackgroundColor.toHexString() == color.toHexString()
                                                            ? Color.themeAccent : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                
                                ColorPicker("Personnalisée", selection: $customEmojiBackgroundColor, supportsOpacity: false)
                                    .font(.system(size: 13))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom)
                    }
                    .navigationTitle("Avatar Emoji")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("OK") { showEmojiEditor = false }
                                .foregroundColor(.themeAccent)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers
    private func prefillIfEditing() {
        guard let e = editingEncounter else { return }
        if let personID = e.personId {
            selectedExistingPersonID = personID
            personLinkMode = .existing
        } else {
            personLinkMode = .new
        }
        firstName = e.firstName
        age = e.age ?? 25
        date      = e.date
        gender    = e.gender ?? .male
        context   = e.context
        encounterType = e.type ?? .body
        city      = e.city
        precisePlace = e.precisePlace
        rating    = e.rating
        outcome = e.outcome
        wouldMeetAgain = e.wouldMeetAgain
        note      = e.note
        pinOnMap  = e.pinOnMap
        selectedLatitude = e.latitude
        selectedLongitude = e.longitude
        photoDataBase64 = e.photoDataBase64
        customEmoji = e.customEmoji
        customEmojiBackgroundColor = Color(hex: e.customEmojiBackgroundHex)
        greenFlagsInput = e.greenFlags.joined(separator: ", ")
        redFlagsInput = e.redFlags.joined(separator: ", ")
        
        if personLinkMode == .existing, let personID = selectedExistingPersonID {
            applyIdentityFromExistingPerson(personID)
        }
    }

    private func saveEncounter() {
        let sanitizedFirstName = InputSanitizer.cleanSingleLine(firstName, maxLength: 60)
        let sanitizedCity = InputSanitizer.cleanSingleLine(city, maxLength: 80)
        let sanitizedPrecisePlace = InputSanitizer.cleanSingleLine(precisePlace, maxLength: 160)
        let sanitizedNote = InputSanitizer.cleanMultiLine(note, maxLength: 800)

        var encounter = Encounter(
            personId: resolvedPersonID(),
            firstName: sanitizedFirstName,
            age: age,
            date: date,
            gender: gender,
            context: context,
            city: sanitizedCity,
            rating: rating,
            note: sanitizedNote,
            pinOnMap: pinOnMap,
            precisePlace: sanitizedPrecisePlace,
            outcome: outcome,
            wouldMeetAgain: wouldMeetAgain,
        )
        encounter.photoDataBase64 = photoDataBase64
        encounter.type = encounterType
        encounter.greenFlags = parseList(greenFlagsInput)
        encounter.redFlags = parseList(redFlagsInput)
        encounter.customEmoji = InputSanitizer.cleanEmoji(customEmoji)
        encounter.customEmojiBackgroundHex = customEmojiBackgroundColor.toHexString()
        if personLinkMode == .existing, let personID = selectedExistingPersonID, let identitySource = vm.latestEncounter(for: personID) {
            encounter.firstName = identitySource.firstName
            encounter.age = identitySource.age
            encounter.gender = identitySource.gender
            encounter.photoDataBase64 = identitySource.photoDataBase64
            encounter.customEmoji = identitySource.customEmoji
            encounter.customEmojiBackgroundHex = identitySource.customEmojiBackgroundHex
        }
        if pinOnMap, let lat = selectedLatitude, let lon = selectedLongitude {
            encounter.latitude = lat
            encounter.longitude = lon
        }

        if isEditing {
            encounter.id = editingEncounter!.id
            // Geocode city for map pin
            if pinOnMap && !city.isEmpty {
                geocodeAndUpdate(encounter)
            } else {
                vm.update(encounter)
            }
        } else {
            if pinOnMap && !city.isEmpty {
                geocodeAndAdd(encounter)
            } else {
                vm.add(encounter)
            }
        }
    }

    private func geocodeAndAdd(_ encounter: Encounter) {
        let query = precisePlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? city
            : "\(precisePlace), \(city)"
        CLGeocoder().geocodeAddressString(query) { placemarks, _ in
            var updatedEncounter = encounter
            if let loc = placemarks?.first?.location {
                updatedEncounter.latitude = loc.coordinate.latitude
                updatedEncounter.longitude = loc.coordinate.longitude
            }
            Task { @MainActor in
                vm.add(updatedEncounter)
            }
        }
    }

    private func geocodeAndUpdate(_ encounter: Encounter) {
        let query = precisePlace.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? city
            : "\(precisePlace), \(city)"
        CLGeocoder().geocodeAddressString(query) { placemarks, _ in
            var updatedEncounter = encounter
            if let loc = placemarks?.first?.location {
                updatedEncounter.latitude = loc.coordinate.latitude
                updatedEncounter.longitude = loc.coordinate.longitude
            }
            Task { @MainActor in
                vm.update(updatedEncounter)
            }
        }
    }
    
    private func parseList(_ raw: String) -> [String] {
        raw.split(separator: ",")
            .map { InputSanitizer.cleanSingleLine(String($0), maxLength: 40) }
            .filter { !$0.isEmpty }
    }
    
    private func resolvedPersonID() -> UUID {
        if personLinkMode == .existing, let selectedExistingPersonID {
            return selectedExistingPersonID
        }
        if isEditing, let existingID = editingEncounter?.personId {
            return existingID
        }
        return UUID()
    }
    
    private func applyIdentityFromExistingPerson(_ personID: UUID?) {
        guard let personID, let source = vm.latestEncounter(for: personID) else { return }
        firstName = InputSanitizer.cleanSingleLine(source.firstName, maxLength: 60)
        age = source.age ?? 25
        gender = source.gender ?? .male
        photoDataBase64 = source.photoDataBase64
        customEmoji = source.customEmoji
        customEmojiBackgroundColor = Color(hex: source.customEmojiBackgroundHex)
    }

    private func applyAddressSuggestion(_ suggestion: AddressSuggestion) {
        isApplyingAddressSuggestion = true
        focusedField = nil

        let formatted = suggestion.subtitle.isEmpty
            ? suggestion.title
            : "\(suggestion.title), \(suggestion.subtitle)"

        precisePlace = InputSanitizer.cleanSingleLine(formatted, maxLength: 160)
        if city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            city = InputSanitizer.cleanSingleLine(suggestion.subtitle, maxLength: 80)
        }
        addressAutocomplete.clear()

        Task { @MainActor in
            await Task.yield()
            isApplyingAddressSuggestion = false
        }
    }
    
}

struct AddressSuggestion: Identifiable {
    let title: String
    let subtitle: String

    var id: String {
        "\(title)\u{1F}\(subtitle)"
    }
}

final class AddressAutocompleteService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published private(set) var suggestions: [AddressSuggestion] = []

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func updateQuery(_ address: String, cityHint: String) {
        let cleanedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedCity = cityHint.trimmingCharacters(in: .whitespacesAndNewlines)

        guard cleanedAddress.count >= 2 else {
            suggestions = []
            return
        }

        completer.queryFragment = cleanedCity.isEmpty ? cleanedAddress : "\(cleanedAddress), \(cleanedCity)"
    }

    func clear() {
        completer.queryFragment = ""
        suggestions = []
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard !completer.queryFragment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            suggestions = []
            return
        }
        suggestions = completer.results.map {
            AddressSuggestion(title: $0.title, subtitle: $0.subtitle)
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        suggestions = []
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    let allowsEditing: Bool
    let onImagePicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.allowsEditing = allowsEditing
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImagePicked: onImagePicked, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImagePicked: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImagePicked: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImagePicked = onImagePicked
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = (info[.editedImage] as? UIImage) ?? (info[.originalImage] as? UIImage) {
                onImagePicked(image)
            }
            dismiss()
        }
    }
}
