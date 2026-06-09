import SwiftUI
import UIKit
import AVFoundation
import LocalAuthentication
import Photos

struct ProfileView: View {
    @EnvironmentObject var vm: EncounterViewModel

    @AppStorage("profile.firstName") private var firstName: String = ""
    @AppStorage("profile.birthDate") private var birthDateTimestamp: Double = Date().addingTimeInterval(-25 * 365.25 * 24 * 60 * 60).timeIntervalSince1970
    @AppStorage("profile.gender") private var gender: String = "Non précisé"
    @AppStorage("profile.city") private var city: String = ""
    @AppStorage("profile.bio") private var bio: String = ""
    @AppStorage("profile.imageBase64") private var imageBase64: String = ""
    @AppStorage("profile.customEmoji") private var customEmoji: String = ""
    @AppStorage("profile.customEmojiBgHex") private var customEmojiBgHex: String = "#C084FC"

    @State private var showDeleteAll = false
    @AppStorage("settings.theme") private var theme: String = "sombre"
    @AppStorage("settings.biometricLock") private var biometricLock: Bool = false
    @AppStorage("settings.authenticationMethod") private var authenticationMethodRaw: String = AppAuthenticationMethod.biometry.rawValue
    @AppStorage("settings.autolockSeconds") private var autoLockSeconds: Int = 0
    @AppStorage("settings.privacyMode") private var privacyMode: Bool = false
    @AppStorage("settings.privacyShield") private var privacyShield: Bool = true
    @State private var showPhotoSourceDialog = false
    @State private var showPhotoPicker = false
    @State private var photoSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var showEmojiEditor = false
    @State private var photoAccessAlertMessage = ""
    @State private var showPhotoAccessAlert = false
    @State private var supportedBiometryType: LABiometryType = .none
    @State private var availableAuthenticationMethods: [AppAuthenticationMethod] = []
    @State private var showPasscodeSetup = false
    @State private var newPasscode = ""
    @State private var confirmPasscode = ""
    @State private var passcodeSetupError = ""
    @State private var enableLockAfterPasscodeSetup = false
    @State private var hasAppPasscode = AppPasscodeStore.hasPasscode
    @State private var showBackupShareSheet = false
    @State private var backupShareItems: [URL] = []
    @State private var backupErrorMessage = ""
    @State private var showBackupError = false

    private let genders = ["Non précisé", "Femme", "Homme", "Non-binaire", "Autre"]
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

    private var bioBinding: Binding<String> {
        Binding(
            get: { bio },
            set: { bio = InputSanitizer.cleanMultiLine($0, maxLength: 500) }
        )
    }
    
    private var birthDateBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: birthDateTimestamp) },
            set: { birthDateTimestamp = $0.timeIntervalSince1970 }
        )
    }
    
    private var computedAge: Int {
        let calendar = Calendar.current
        let birthDate = Date(timeIntervalSince1970: birthDateTimestamp)
        let years = calendar.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
        return max(0, years)
    }

    private var biometricLockBinding: Binding<Bool> {
        Binding(
            get: { biometricLock },
            set: { enabled in
                if enabled {
                    refreshAuthenticationMethods()
                    requestLockActivation()
                } else {
                    biometricLock = false
                }
            }
        )
    }

    private var authenticationMethodBinding: Binding<AppAuthenticationMethod> {
        Binding(
            get: { authenticationMethod },
            set: { method in
                authenticationMethodRaw = method.rawValue
                if biometricLock {
                    requestLockActivation()
                }
            }
        )
    }

    private var newPasscodeBinding: Binding<String> {
        Binding(
            get: { newPasscode },
            set: { newPasscode = AppPasscodeStore.normalized($0) }
        )
    }

    private var confirmPasscodeBinding: Binding<String> {
        Binding(
            get: { confirmPasscode },
            set: { confirmPasscode = AppPasscodeStore.normalized($0) }
        )
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        Button {
                            showPhotoSourceDialog = true
                        } label: {
                            AvatarView(
                                initials: firstName.isEmpty ? "?" : String(firstName.prefix(2)).uppercased(),
                                gender: nil,
                                photoDataBase64: imageBase64,
                                customEmoji: customEmoji,
                                customEmojiBackgroundHex: customEmojiBgHex,
                                size: 108,
                                respectsPrivacyMode: false
                            )
                        }
                        .buttonStyle(.plain)

                        VStack(spacing: 4) {
                            Text(firstName.isEmpty ? "Mon profil" : firstName)
                                .font(.title3.bold())
                            Text("\(vm.totalCount) rencontre\(vm.totalCount > 1 ? "s" : "") enregistrée\(vm.totalCount > 1 ? "s" : "")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section("Informations") {
                    TextField("Prénom", text: firstNameBinding)
                    
                    DatePicker(
                        "Date de naissance",
                        selection: birthDateBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "fr_FR"))
                    
                    HStack {
                        Text("Âge")
                        Spacer()
                        Text("\(computedAge) ans")
                            .foregroundColor(.secondary)
                    }

                    Picker("Genre", selection: $gender) {
                        ForEach(genders, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }

                    TextField("Ville", text: cityBinding)
                }

                Section("Bio") {
                    TextEditor(text: bioBinding)
                        .frame(minHeight: 90)
                }

                Section("Paramètres") {
                    Picker("Thème", selection: $theme) {
                        Text("Sombre").tag("sombre")
                        Text("Clair").tag("light")
                    }
                    
                    Toggle("Verrouiller l’app", isOn: biometricLockBinding)
                        .tint(.themeAccent)

                    if !availableAuthenticationMethods.isEmpty {
                        Picker("Méthode", selection: authenticationMethodBinding) {
                            ForEach(availableAuthenticationMethods) { method in
                                Label(
                                    method.title(for: supportedBiometryType),
                                    systemImage: method.icon(for: supportedBiometryType)
                                )
                                .tag(method)
                            }
                        }
                        .disabled(!biometricLock)
                    }

                    Button {
                        presentPasscodeSetup(enableLockAfterSetup: false)
                    } label: {
                        Label(
                            hasAppPasscode ? "Modifier le code Body X" : "Créer un code Body X",
                            systemImage: "number.square.fill"
                        )
                    }
                    .foregroundColor(.themeAccent)

                    if biometricLock {
                        Picker("Verrouillage auto", selection: $autoLockSeconds) {
                            Text("Immédiat").tag(0)
                            Text("30 secondes").tag(30)
                            Text("1 minute").tag(60)
                        }
                    }
                    
                }

                Section("Confidentialité") {
                    Toggle("Mode discret", isOn: $privacyMode)
                        .tint(.themeAccent)

                    Toggle("Masquer l’aperçu iOS", isOn: $privacyShield)
                        .tint(.themeAccent)

                    if privacyMode {
                        Label("Noms, photos et notes privées sont masqués dans l’app.", systemImage: "eye.slash.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section("Politique de confidentialité") {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label("Voir la politique", systemImage: "hand.raised.fill")
                    }

                    Text("Résumé : les données restent sur cet appareil. Les sauvegardes exportées sont en clair.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        exportBackupNote()
                    } label: {
                        Label("Créer une note de sauvegarde", systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.themeAccent)
                    .disabled(vm.encounters.isEmpty)

                    Text("La note est lisible en clair et organisée par personne. Garde-la dans un endroit sécurisé.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text("Sauvegarde")
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAll = true
                    } label: {
                        Label("Supprimer toutes les entrées", systemImage: "trash.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profil")
            .onAppear {
                refreshAuthenticationMethods()
            }
            .sheet(isPresented: $showPhotoPicker) {
                ImagePicker(sourceType: photoSourceType, allowsEditing: true) { image in
                    if let jpegData = image.jpegData(compressionQuality: 0.85) {
                        imageBase64 = jpegData.base64EncodedString()
                    }
                }
            }
            .sheet(isPresented: $showPasscodeSetup) {
                passcodeSetupSheet
            }
            .sheet(isPresented: $showBackupShareSheet, onDismiss: {
                backupShareItems = []
            }) {
                if !backupShareItems.isEmpty {
                    ActivityShareSheet(activityItems: backupShareItems)
                }
            }
            .confirmationDialog("Photo de profil", isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button("Choisir une photo") {
                    requestPhotoLibraryAccessAndPresentPicker()
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Prendre une photo") {
                        requestCameraAccessAndPresentPicker()
                    }
                }
                Button("Personnaliser avec un emoji") {
                    showEmojiEditor = true
                }
                if !imageBase64.isEmpty {
                    Button("Supprimer la photo", role: .destructive) {
                        imageBase64 = ""
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
                                gender: nil,
                                photoDataBase64: "",
                                customEmoji: customEmoji,
                                customEmojiBackgroundHex: customEmojiBgHex,
                                size: 92,
                                respectsPrivacyMode: false
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
                                            customEmojiBgHex = color.toHexString()
                                        } label: {
                                            Circle()
                                                .fill(color)
                                                .frame(width: 30, height: 30)
                                                .overlay(
                                                    Circle()
                                                        .stroke(
                                                            customEmojiBgHex == color.toHexString()
                                                            ? Color.themeAccent : Color.clear,
                                                            lineWidth: 2
                                                        )
                                                )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
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
            .alert("Tout supprimer ?", isPresented: $showDeleteAll) {
                Button("Supprimer", role: .destructive) {
                    showDeleteAll = false
                    Task { @MainActor in
                        await Task.yield()
                        vm.clearAll()
                    }
                }
                Button("Annuler", role: .cancel) {}
            } message: {
                Text("Cette action est irréversible.")
            }
            .alert("Accès requis", isPresented: $showPhotoAccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photoAccessAlertMessage)
            }
            .alert("Sauvegarde impossible", isPresented: $showBackupError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupErrorMessage)
            }
        }
    }

    private func exportBackupNote() {
        guard !vm.encounters.isEmpty else {
            backupErrorMessage = "Aucune rencontre à sauvegarder pour le moment."
            showBackupError = true
            return
        }

        do {
            let timestamp = backupFileTimestamp()
            let markdown = makeBackupMarkdown()
            let noteURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("BodyX-Note-\(timestamp).md")
            try markdown.write(to: noteURL, atomically: true, encoding: .utf8)

            backupShareItems = [noteURL]
            showBackupShareSheet = true
        } catch {
            backupErrorMessage = "Impossible de créer le fichier de sauvegarde pour le moment."
            showBackupError = true
        }
    }

    private func makeBackupMarkdown() -> String {
        var sections: [String] = []
        let groups = backupPersonGroups()

        sections.append("""
        # Sauvegarde Body X

        Créée le \(backupDateText(Date(), includesTime: true)).

        \(groups.count) personne\(groups.count > 1 ? "s" : "") · \(vm.encounters.count) rencontre\(vm.encounters.count > 1 ? "s" : "")

        Note lisible, organisée par personne.
        """)

        sections.append(makeProfileBackupSection())
        sections.append(makePeopleSummarySection(groups))

        for (groupIndex, group) in groups.enumerated() {
            sections.append(makePersonBackupSection(group, index: groupIndex + 1))
        }

        return sections.joined(separator: "\n\n")
    }

    private func makeProfileBackupSection() -> String {
        var lines: [String] = ["## Mon profil"]

        appendReadableField("Prénom", firstName, to: &lines)
        appendReadableField("Âge", "\(computedAge) ans", to: &lines)
        appendReadableField("Genre", gender == "Non précisé" ? "" : gender, to: &lines)
        appendReadableField("Ville", city, to: &lines)
        appendReadableTextBlock("Bio", bio, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func makePeopleSummarySection(_ groups: [BackupPersonGroup]) -> String {
        var lines: [String] = ["## Vue d’ensemble"]

        for (index, group) in groups.enumerated() {
            var summary = "\(index + 1). \(group.displayName)"
            summary += " - \(group.encounters.count) rencontre\(group.encounters.count > 1 ? "s" : "")"
            summary += " - \(backupPeriodText(for: group.encounters))"
            let city = primaryCityText(for: group.encounters)
            if city != "—" {
                summary += " - \(city)"
            }
            lines.append(summary)
        }

        return lines.joined(separator: "\n")
    }

    private func makePersonBackupSection(_ group: BackupPersonGroup, index: Int) -> String {
        var lines: [String] = []
        lines.append("## \(index). \(group.displayName)")
        lines.append("Rencontres : \(group.encounters.count)")
        lines.append("Période : \(backupPeriodText(for: group.encounters))")

        appendReadableField("Types", backupTypeSummary(for: group.encounters), to: &lines)
        appendReadableField("Contextes", backupContextSummary(for: group.encounters), to: &lines)
        appendReadableField("Villes", backupFrequencySummary(group.encounters.map(\.city)), to: &lines)
        lines.append("")

        for (encounterIndex, encounter) in group.encounters.enumerated() {
            lines.append(makeEncounterBackupSection(encounter, index: encounterIndex + 1))
        }

        return lines.joined(separator: "\n")
    }

    private func makeEncounterBackupSection(_ encounter: Encounter, index: Int) -> String {
        var lines: [String] = []
        lines.append("### Rencontre \(index)")
        lines.append("Date : \(backupDateText(encounter.date))")
        appendReadableField("Lieu", backupLocationText(for: encounter), to: &lines)

        let headline = backupEncounterHeadline(for: encounter)
        if !headline.isEmpty {
            lines.append("Résumé : \(headline)")
        }

        appendReadableField("Prénom ou surnom", encounter.firstName, to: &lines)
        appendReadableField("Âge", encounter.age.map { "\($0) ans" } ?? "", to: &lines)
        appendReadableField("Tags", backupListText(encounter.tags), to: &lines)
        appendReadableField("Green flags", backupListText(encounter.greenFlags), to: &lines)
        appendReadableField("Red flags", backupListText(encounter.redFlags), to: &lines)
        appendReadableTextBlock("Mémo", encounter.note, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func backupEncounterHeadline(for encounter: Encounter) -> String {
        var parts: [String] = []

        if let type = encounter.type {
            parts.append(type.rawValue)
        }
        if let context = encounter.context {
            parts.append(context.rawValue)
        }
        if encounter.rating > 0 {
            parts.append("\(RatingScale.formatted(encounter.rating))/5")
        }
        if let outcome = encounter.outcome {
            parts.append(outcome.rawValue)
        }
        if encounter.wouldMeetAgain {
            parts.append("À revoir")
        }

        return parts.joined(separator: " · ")
    }

    private func backupLocationText(for encounter: Encounter) -> String {
        [encounter.city, encounter.precisePlace]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    private func appendReadableField(_ label: String, _ value: String, to lines: inout [String]) {
        let clean = cleanBackupValue(value)
        guard clean != "—" else { return }
        lines.append("\(label) : \(clean)")
    }

    private func appendReadableTextBlock(_ label: String, _ value: String, to lines: inout [String]) {
        let clean = cleanBackupValue(value)
        guard clean != "—" else { return }

        let quoted = clean
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { "> \($0)" }
            .joined(separator: "\n")

        lines.append("\(label) :\n\(quoted)")
    }

    private func backupPersonGroups() -> [BackupPersonGroup] {
        Dictionary(grouping: vm.encounters) { encounter in
            encounter.personId ?? encounter.id
        }
        .map { id, encounters in
            BackupPersonGroup(
                id: id,
                displayName: backupDisplayName(for: encounters),
                encounters: encounters.sorted { $0.date > $1.date }
            )
        }
        .sorted { lhs, rhs in
            let lhsDate = lhs.encounters.first?.date ?? .distantPast
            let rhsDate = rhs.encounters.first?.date ?? .distantPast
            return lhsDate > rhsDate
        }
    }

    private func backupDisplayName(for encounters: [Encounter]) -> String {
        encounters
            .map { $0.firstName.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .max { $0.count < $1.count } ?? "Personne inconnue"
    }

    private func primaryCityText(for encounters: [Encounter]) -> String {
        backupFrequencySummary(encounters.map(\.city))
            .components(separatedBy: ",")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "—"
    }

    private func backupPeriodText(for encounters: [Encounter]) -> String {
        guard let first = encounters.map(\.date).min(), let last = encounters.map(\.date).max() else {
            return "—"
        }

        if Calendar.current.isDate(first, inSameDayAs: last) {
            return backupDateText(first)
        }

        return "\(backupDateText(first)) - \(backupDateText(last))"
    }

    private func backupTypeSummary(for encounters: [Encounter]) -> String {
        let parts = EncounterType.allCases.compactMap { type -> String? in
            let count = encounters.filter { ($0.type ?? .body) == type }.count
            return count > 0 ? "\(type.rawValue) (\(count))" : nil
        }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    private func backupContextSummary(for encounters: [Encounter]) -> String {
        let parts = EncounterContext.allCases.compactMap { context -> String? in
            let count = encounters.filter { $0.context == context }.count
            return count > 0 ? "\(context.rawValue) (\(count))" : nil
        }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    private func backupFrequencySummary(_ values: [String]) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let parts = Dictionary(grouping: cleaned) { $0 }
            .map { ($0.key, $0.value.count) }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .map { "\($0.0) (\($0.1))" }

        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    private func backupListText(_ values: [String]) -> String {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? "—" : cleaned.joined(separator: ", ")
    }

    private func cleanBackupValue(_ value: String) -> String {
        let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? "—" : clean
    }

    private func backupDateText(_ date: Date, includesTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = includesTime ? "d MMM yyyy HH:mm" : "d MMM yyyy"
        return formatter.string(from: date)
    }

    private func backupFileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }

    private func yesNo(_ value: Bool) -> String {
        value ? "Oui" : "Non"
    }

    private var passcodeSetupSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Code Body X", text: newPasscodeBinding)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)

                    SecureField("Confirmer le code", text: confirmPasscodeBinding)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } footer: {
                    Text("Choisis un code de \(AppPasscodeStore.minimumLength) à \(AppPasscodeStore.maximumLength) chiffres. Il servira à déverrouiller l’app sans Touch ID ni Face ID.")
                }

                if !passcodeSetupError.isEmpty {
                    Section {
                        Text(passcodeSetupError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(hasAppPasscode ? "Modifier le code" : "Créer un code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        cancelPasscodeSetup()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("OK") {
                        saveAppPasscode()
                    }
                    .disabled(newPasscode.count < AppPasscodeStore.minimumLength || confirmPasscode.isEmpty)
                }
            }
        }
    }

    private func requestPhotoLibraryAccessAndPresentPicker() {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            presentPhotoPicker(sourceType: .photoLibrary)
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                Task { @MainActor in
                    handlePhotoLibraryAuthorization(newStatus)
                }
            }
        case .denied, .restricted:
            showPhotoAccessAlert(message: "Autorise l’accès aux photos dans Réglages > Body X > Photos.")
        @unknown default:
            showPhotoAccessAlert(message: "Impossible d’accéder à la photothèque pour le moment.")
        }
    }

    private func requestLockActivation() {
        hasAppPasscode = AppPasscodeStore.hasPasscode

        guard hasAppPasscode else {
            biometricLock = false
            presentPasscodeSetup(enableLockAfterSetup: true)
            return
        }

        if authenticationMethod == .passcode {
            biometricLock = true
            return
        }

        requestBiometricLockActivation()
    }

    private func requestBiometricLockActivation() {
        guard !availableAuthenticationMethods.isEmpty else {
            biometricLock = false
            showPhotoAccessAlert(message: "Configure Face ID ou Touch ID dans Réglages iOS avant d’activer ce mode.")
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        context.localizedFallbackTitle = "Utiliser le code Body X"

        var error: NSError?

        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard context.biometryType != .faceID || hasFaceIDUsageDescription else {
            biometricLock = false
            showPhotoAccessAlert(message: "Ajoute Privacy - Face ID Usage Description dans le target Body X pour autoriser Face ID.")
            return
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricLock = false
            showPhotoAccessAlert(message: authenticationUnavailableMessage(from: error))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: "Activer le verrouillage de Body X") { success, error in
            Task { @MainActor in
                biometricLock = success
                if !success {
                    showPhotoAccessAlert(message: authenticationUnavailableMessage(from: error as NSError?))
                }
            }
        }
    }

    private func presentPasscodeSetup(enableLockAfterSetup: Bool) {
        newPasscode = ""
        confirmPasscode = ""
        passcodeSetupError = ""
        enableLockAfterPasscodeSetup = enableLockAfterSetup
        showPasscodeSetup = true
    }

    private func saveAppPasscode() {
        guard newPasscode.count >= AppPasscodeStore.minimumLength else {
            passcodeSetupError = "Le code doit contenir au moins \(AppPasscodeStore.minimumLength) chiffres."
            return
        }

        guard newPasscode == confirmPasscode else {
            passcodeSetupError = "Les deux codes ne correspondent pas."
            return
        }

        do {
            try AppPasscodeStore.set(newPasscode)
            hasAppPasscode = true
            showPasscodeSetup = false
            newPasscode = ""
            confirmPasscode = ""
            passcodeSetupError = ""

            if enableLockAfterPasscodeSetup {
                enableLockAfterPasscodeSetup = false
                biometricLock = true
                if authenticationMethod == .biometry {
                    requestBiometricLockActivation()
                }
            }
        } catch {
            passcodeSetupError = "Impossible d’enregistrer le code pour le moment."
        }
    }

    private func cancelPasscodeSetup() {
        if enableLockAfterPasscodeSetup {
            biometricLock = false
        }
        enableLockAfterPasscodeSetup = false
        showPasscodeSetup = false
        newPasscode = ""
        confirmPasscode = ""
        passcodeSetupError = ""
    }

    private func handlePhotoLibraryAuthorization(_ status: PHAuthorizationStatus) {
        if status == .authorized || status == .limited {
            presentPhotoPicker(sourceType: .photoLibrary)
        } else {
            showPhotoAccessAlert(message: "Autorise l’accès aux photos dans Réglages > Body X > Photos.")
        }
    }

    private func requestCameraAccessAndPresentPicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showPhotoAccessAlert(message: "La caméra n’est pas disponible sur cet appareil.")
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentPhotoPicker(sourceType: .camera)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Task { @MainActor in
                    if granted {
                        presentPhotoPicker(sourceType: .camera)
                    } else {
                        showPhotoAccessAlert(message: "Autorise l’accès à la caméra dans Réglages > Body X > Appareil photo.")
                    }
                }
            }
        case .denied, .restricted:
            showPhotoAccessAlert(message: "Autorise l’accès à la caméra dans Réglages > Body X > Appareil photo.")
        @unknown default:
            showPhotoAccessAlert(message: "Impossible d’accéder à la caméra pour le moment.")
        }
    }

    private func presentPhotoPicker(sourceType: UIImagePickerController.SourceType) {
        showPhotoSourceDialog = false
        photoSourceType = sourceType

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            showPhotoPicker = true
        }
    }

    private func showPhotoAccessAlert(message: String) {
        photoAccessAlertMessage = message
        showPhotoAccessAlert = true
    }

    private var authenticationMethod: AppAuthenticationMethod {
        AppAuthenticationMethod(rawValue: authenticationMethodRaw) ?? availableAuthenticationMethods.first ?? .passcode
    }

    private var hasFaceIDUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") is String
    }

    private func refreshAuthenticationMethods() {
        let context = LAContext()
        var biometricError: NSError?
        let canUseBiometry = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &biometricError)
        supportedBiometryType = context.biometryType

        var methods: [AppAuthenticationMethod] = []
        if canUseBiometry && (supportedBiometryType == .faceID || supportedBiometryType == .touchID) {
            methods.append(.biometry)
        }

        methods.append(.passcode)

        availableAuthenticationMethods = methods
        hasAppPasscode = AppPasscodeStore.hasPasscode

        if !methods.contains(authenticationMethod), let firstMethod = methods.first {
            authenticationMethodRaw = firstMethod.rawValue
        }
    }

    private func authenticationUnavailableMessage(from error: NSError?) -> String {
        switch error?.code {
        case LAError.biometryNotEnrolled.rawValue:
            return "Configure Face ID, Touch ID ou un code dans Réglages avant d’activer ce verrouillage."
        case LAError.biometryNotAvailable.rawValue:
            return "Face ID / Touch ID n’est pas disponible. Le code de l’appareil sera utilisé s’il est configuré."
        case LAError.biometryLockout.rawValue:
            return "Face ID / Touch ID est temporairement bloqué. Utilise le code de l’appareil."
        case LAError.passcodeNotSet.rawValue:
            return "Aucun code n’est configuré sur cet appareil."
        case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
            return "Authentification annulée. Le verrouillage n’a pas été activé."
        default:
            return "Impossible d’activer Face ID, Touch ID ou le code pour le moment."
        }
    }
}

private struct BackupPersonGroup {
    let id: UUID
    let displayName: String
    let encounters: [Encounter]
}

private struct PrivacyPolicyView: View {
    var body: some View {
        List {
            Section {
                Text("Politique de confidentialité de BodyX")
                    .font(.headline)
                PrivacyPolicyText("Dernière mise à jour : 9 juin 2026")
                    .foregroundColor(.secondary)
            }

            Section("Introduction") {
                PrivacyPolicyText("BodyX respecte votre vie privée et s’engage à protéger vos données personnelles.")
                PrivacyPolicyText("Cette politique de confidentialité explique quelles informations sont traitées lorsque vous utilisez l’application BodyX et comment celles-ci sont protégées.")
                PrivacyPolicyText("En utilisant BodyX, vous acceptez les pratiques décrites dans cette politique.")
            }

            Section("1. À propos de BodyX") {
                PrivacyPolicyText("BodyX est une application privée permettant aux utilisateurs de conserver un historique personnel de leurs relations et interactions intimes.")
                PrivacyPolicyText("La confidentialité constitue un principe fondamental de la conception de l’application.")
            }

            Section("2. Données enregistrées") {
                PrivacyPolicyText("Les informations que vous saisissez dans BodyX, notamment les noms, surnoms, notes, dates, photos et autres informations personnelles que vous choisissez d’enregistrer, sont stockées exclusivement sur votre appareil.")
                PrivacyPolicyText("BodyX ne transmet pas ces informations à nos serveurs.")
                PrivacyPolicyText("Nous n’avons aucun accès à vos données personnelles ou à votre contenu.")
                PrivacyPolicyText("Nous ne pouvons pas consulter, récupérer, analyser ou partager les informations que vous enregistrez dans l’application.")
            }

            Section("3. Absence de compte utilisateur") {
                PrivacyPolicyText("L’utilisation actuelle de BodyX ne nécessite aucune création de compte.")
                PrivacyPolicyText("Aucune inscription, adresse e-mail ou identification personnelle n’est demandée pour utiliser les fonctionnalités principales de l’application.")
            }

            Section("4. Stockage local des données") {
                PrivacyPolicyText("Toutes les données enregistrées dans BodyX sont conservées localement sur votre appareil.")
                PrivacyPolicyText("Aucune synchronisation avec un serveur distant n’est effectuée.")
                PrivacyPolicyText("Aucune base de données en ligne contenant vos informations personnelles n’est exploitée par BodyX.")
            }

            Section("5. Exportation de données") {
                PrivacyPolicyText("BodyX permet aux utilisateurs d’exporter certaines informations sous forme de document de sauvegarde.")
                PrivacyPolicyText("Une fois exporté hors de l’application, ce document devient sous la responsabilité exclusive de l’utilisateur.")
                PrivacyPolicyText("BodyX ne contrôle pas l’utilisation, le stockage ou le partage des fichiers exportés.")
                PrivacyPolicyText("Nous recommandons aux utilisateurs de protéger ces fichiers et de les partager uniquement avec des personnes de confiance.")
            }

            Section("6. Accès aux fonctionnalités de l’appareil") {
                PrivacyPolicyText("Selon les fonctionnalités utilisées, BodyX peut demander les autorisations suivantes :")
                PrivacyPolicyText("Appareil photo : permet d’ajouter des photos à vos entrées.")
                PrivacyPolicyText("Bibliothèque de photos : permet de sélectionner des photos déjà présentes sur votre appareil.")
                PrivacyPolicyText("Face ID / Touch ID : permet de sécuriser l’accès à l’application et de protéger vos données contre les accès non autorisés.")
                PrivacyPolicyText("Ces autorisations sont facultatives et peuvent être désactivées à tout moment depuis les réglages de votre appareil.")
            }

            Section("7. Sécurité") {
                PrivacyPolicyText("La protection de votre vie privée constitue l’une des priorités de BodyX.")
                PrivacyPolicyText("Toutes les données enregistrées dans l’application sont stockées localement sur votre appareil et ne sont pas transmises à nos serveurs.")
                PrivacyPolicyText("BodyX permet de protéger l’accès à vos informations grâce à un code PIN personnel défini par l’utilisateur ainsi qu’aux mécanismes biométriques pris en charge par votre appareil, tels que Face ID ou Touch ID.")
                PrivacyPolicyText("Même les développeurs de BodyX ne peuvent pas accéder à vos données personnelles, à vos notes, à vos photos ou aux informations que vous enregistrez dans l’application.")
                PrivacyPolicyText("Nous n’avons aucun moyen technique de consulter, récupérer ou analyser le contenu enregistré dans BodyX.")
                PrivacyPolicyText("Toutefois, la sécurité de vos données dépend également de la protection de votre appareil. Nous vous recommandons d’utiliser un code de verrouillage sécurisé et de maintenir votre système d’exploitation à jour.")
            }

            Section("8. Publicité") {
                PrivacyPolicyText("À ce jour, BodyX n’affiche aucune publicité.")
                PrivacyPolicyText("Si des services publicitaires sont intégrés dans une future version de l’application, cette politique sera mise à jour afin d’expliquer clairement quelles données pourraient être utilisées et dans quel objectif.")
            }

            Section("9. Protection des mineurs") {
                PrivacyPolicyText("BodyX est destiné aux personnes âgées d’au moins 16 ans.")
                PrivacyPolicyText("Nous ne collectons pas sciemment de données concernant des enfants de moins de 16 ans.")
                PrivacyPolicyText("Si vous pensez qu’un mineur de moins de 16 ans utilise l’application contrairement à cette politique, veuillez nous contacter.")
            }

            Section("10. Vos droits") {
                PrivacyPolicyText("Conformément aux lois applicables en matière de protection des données, vous disposez notamment des droits suivants :")
                PrivacyPolicyText("Droit d’accès à vos données ;")
                PrivacyPolicyText("Droit de rectification ;")
                PrivacyPolicyText("Droit à l’effacement ;")
                PrivacyPolicyText("Droit à la limitation du traitement ;")
                PrivacyPolicyText("Droit d’opposition ;")
                PrivacyPolicyText("Droit à la portabilité.")
                PrivacyPolicyText("Étant donné que les données sont stockées uniquement sur votre appareil et ne sont pas accessibles par BodyX, la plupart de ces droits peuvent être exercés directement par vous depuis l’application ou en supprimant vos données localement.")
            }

            Section("11. Modifications de cette politique") {
                PrivacyPolicyText("Nous pouvons modifier cette politique de confidentialité afin de refléter l’évolution de l’application ou des exigences légales.")
                PrivacyPolicyText("La date de dernière mise à jour figurera toujours en haut de cette page.")
            }

            Section("12. Nous contacter") {
                PrivacyPolicyText("Pour toute question concernant cette politique de confidentialité ou l’application BodyX, vous pouvez nous contacter :")
                PrivacyPolicyText("Email : bodyxapp@gmail.com")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Confidentialité")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PrivacyPolicyText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 2)
    }
}

private struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [URL]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems.map { $0 as Any },
            applicationActivities: nil
        )
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
