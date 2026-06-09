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
    @AppStorage("settings.language") private var languageRaw: String = AppLanguage.french.rawValue
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

    private var languageBinding: Binding<AppLanguage> {
        Binding(
            get: { AppLanguage(rawValue: languageRaw) ?? .french },
            set: { languageRaw = $0.rawValue }
        )
    }

    private func profileGenderLabel(_ value: String) -> String {
        switch value {
        case "Non précisé": return L10n.text("Non précisé", "Not specified")
        case "Femme": return L10n.text("Femme", "Woman")
        case "Homme": return L10n.text("Homme", "Man")
        case "Non-binaire": return L10n.text("Non-binaire", "Non-binary")
        case "Autre": return L10n.text("Autre", "Other")
        default: return value
        }
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
                            Text(firstName.isEmpty ? L10n.text("Mon profil", "My profile") : firstName)
                                .font(.title3.bold())
                            Text(L10n.text(
                                "\(vm.totalCount) rencontre\(vm.totalCount > 1 ? "s" : "") enregistrée\(vm.totalCount > 1 ? "s" : "")",
                                "\(vm.totalCount) saved encounter\(vm.totalCount == 1 ? "" : "s")"
                            ))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }

                Section(L10n.text("Informations", "Information")) {
                    TextField(L10n.text("Prénom", "First name"), text: firstNameBinding)
                    
                    DatePicker(
                        L10n.text("Date de naissance", "Date of birth"),
                        selection: birthDateBinding,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: AppLanguage.current.localeIdentifier))
                    
                    HStack {
                        Text(L10n.text("Âge", "Age"))
                        Spacer()
                        Text(L10n.text("\(computedAge) ans", "\(computedAge) years old"))
                            .foregroundColor(.secondary)
                    }

                    Picker(L10n.text("Genre", "Gender"), selection: $gender) {
                        ForEach(genders, id: \.self) { g in
                            Text(profileGenderLabel(g)).tag(g)
                        }
                    }

                    TextField(L10n.text("Ville", "City"), text: cityBinding)
                }

                Section("Bio") {
                    TextEditor(text: bioBinding)
                        .frame(minHeight: 90)
                }

                Section(L10n.text("Paramètres", "Settings")) {
                    Picker(L10n.text("Langue", "Language"), selection: languageBinding) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.title).tag(language)
                        }
                    }

                    Picker(L10n.text("Thème", "Theme"), selection: $theme) {
                        Text(L10n.text("Sombre", "Dark")).tag("sombre")
                        Text(L10n.text("Clair", "Light")).tag("light")
                    }
                    
                    Toggle(L10n.text("Verrouiller l’app", "Lock app"), isOn: biometricLockBinding)
                        .tint(.themeAccent)

                    if !availableAuthenticationMethods.isEmpty {
                        Picker(L10n.text("Méthode", "Method"), selection: authenticationMethodBinding) {
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
                            hasAppPasscode
                            ? L10n.text("Modifier le code Body X", "Change Body X code")
                            : L10n.text("Créer un code Body X", "Create Body X code"),
                            systemImage: "number.square.fill"
                        )
                    }
                    .foregroundColor(.themeAccent)

                    if biometricLock {
                        Picker(L10n.text("Verrouillage auto", "Auto-lock"), selection: $autoLockSeconds) {
                            Text(L10n.text("Immédiat", "Immediate")).tag(0)
                            Text(L10n.text("30 secondes", "30 seconds")).tag(30)
                            Text(L10n.text("1 minute", "1 minute")).tag(60)
                        }
                    }
                    
                }

                Section(L10n.text("Confidentialité", "Privacy")) {
                    Toggle(L10n.text("Mode discret", "Discreet mode"), isOn: $privacyMode)
                        .tint(.themeAccent)

                    Toggle(L10n.text("Masquer l’aperçu iOS", "Hide iOS preview"), isOn: $privacyShield)
                        .tint(.themeAccent)

                    if privacyMode {
                        Label(L10n.text("Noms, photos et notes privées sont masqués dans l’app.", "Names, photos, and private notes are hidden in the app."), systemImage: "eye.slash.fill")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }

                Section(L10n.text("Politique de confidentialité", "Privacy policy")) {
                    NavigationLink {
                        PrivacyPolicyView()
                    } label: {
                        Label(L10n.text("Voir la politique", "View policy"), systemImage: "hand.raised.fill")
                    }

                    Text(L10n.text("Résumé : les données restent sur cet appareil. Les sauvegardes exportées sont en clair.", "Summary: data stays on this device. Exported backups are plain text."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section {
                    Button {
                        exportBackupNote()
                    } label: {
                        Label(L10n.text("Créer une note de sauvegarde", "Create backup note"), systemImage: "square.and.arrow.up")
                    }
                    .foregroundColor(.themeAccent)
                    .disabled(vm.encounters.isEmpty)

                    Text(L10n.text("La note est lisible en clair et organisée par personne. Garde-la dans un endroit sécurisé.", "The note is readable plain text and organized by person. Keep it in a secure place."))
                        .font(.footnote)
                        .foregroundColor(.secondary)
                } header: {
                    Text(L10n.text("Sauvegarde", "Backup"))
                }

                Section {
                    Button(role: .destructive) {
                        showDeleteAll = true
                    } label: {
                        Label(L10n.text("Supprimer toutes les entrées", "Delete all entries"), systemImage: "trash.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(L10n.text("Profil", "Profile"))
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
            .confirmationDialog(L10n.text("Photo de profil", "Profile photo"), isPresented: $showPhotoSourceDialog, titleVisibility: .visible) {
                Button(L10n.text("Choisir une photo", "Choose a photo")) {
                    requestPhotoLibraryAccessAndPresentPicker()
                }
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button(L10n.text("Prendre une photo", "Take a photo")) {
                        requestCameraAccessAndPresentPicker()
                    }
                }
                Button(L10n.text("Personnaliser avec un emoji", "Customize with emoji")) {
                    showEmojiEditor = true
                }
                if !imageBase64.isEmpty {
                    Button(L10n.text("Supprimer la photo", "Delete photo"), role: .destructive) {
                        imageBase64 = ""
                    }
                }
                Button(L10n.text("Annuler", "Cancel"), role: .cancel) {}
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

                                TextField(L10n.text("Emoji personnalisé", "Custom emoji"), text: Binding(
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
                                Text(L10n.text("Couleur de fond", "Background color"))
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
                    .navigationTitle(L10n.text("Avatar Emoji", "Emoji Avatar"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("OK") { showEmojiEditor = false }
                                .foregroundColor(.themeAccent)
                        }
                    }
                }
            }
            .alert(L10n.text("Tout supprimer ?", "Delete everything?"), isPresented: $showDeleteAll) {
                Button(L10n.text("Supprimer", "Delete"), role: .destructive) {
                    showDeleteAll = false
                    Task { @MainActor in
                        await Task.yield()
                        vm.clearAll()
                    }
                }
                Button(L10n.text("Annuler", "Cancel"), role: .cancel) {}
            } message: {
                Text(L10n.text("Cette action est irréversible.", "This action cannot be undone."))
            }
            .alert(L10n.text("Accès requis", "Access required"), isPresented: $showPhotoAccessAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(photoAccessAlertMessage)
            }
            .alert(L10n.text("Sauvegarde impossible", "Backup unavailable"), isPresented: $showBackupError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(backupErrorMessage)
            }
        }
    }
    private func exportBackupNote() {
        guard !vm.encounters.isEmpty else {
            backupErrorMessage = L10n.text(
                "Aucune rencontre à sauvegarder pour le moment.",
                "There are no encounters to back up yet."
            )
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
            backupErrorMessage = L10n.text(
                "Impossible de créer le fichier de sauvegarde pour le moment.",
                "Unable to create the backup file right now."
            )
            showBackupError = true
        }
    }

    private func makeBackupMarkdown() -> String {
        var sections: [String] = []
        let groups = backupPersonGroups()

        sections.append("""
        \(L10n.text("# Sauvegarde Body X", "# Body X Backup"))

        \(L10n.text("Créée le", "Created on")) \(backupDateText(Date(), includesTime: true)).

        \(L10n.personCount(groups.count)) · \(L10n.encounterCount(vm.encounters.count))

        \(L10n.text("Note lisible, organisée par personne.", "Readable note, organized by person."))
        """)

        sections.append(makeProfileBackupSection())
        sections.append(makePeopleSummarySection(groups))

        for (groupIndex, group) in groups.enumerated() {
            sections.append(makePersonBackupSection(group, index: groupIndex + 1))
        }

        return sections.joined(separator: "\n\n")
    }

    private func makeProfileBackupSection() -> String {
        var lines: [String] = [L10n.text("## Mon profil", "## My profile")]

        appendReadableField(L10n.text("Prénom", "First name"), firstName, to: &lines)
        appendReadableField(L10n.text("Âge", "Age"), L10n.age(computedAge), to: &lines)
        appendReadableField(L10n.text("Genre", "Gender"), gender == "Non précisé" ? "" : profileGenderLabel(gender), to: &lines)
        appendReadableField(L10n.text("Ville", "City"), city, to: &lines)
        appendReadableTextBlock("Bio", bio, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func makePeopleSummarySection(_ groups: [BackupPersonGroup]) -> String {
        var lines: [String] = [L10n.text("## Vue d’ensemble", "## Overview")]

        for (index, group) in groups.enumerated() {
            var summary = "\(index + 1). \(group.displayName)"
            summary += " - \(L10n.encounterCount(group.encounters.count))"
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
        lines.append("\(L10n.text("Rencontres", "Encounters")) : \(group.encounters.count)")
        lines.append("\(L10n.text("Période", "Period")) : \(backupPeriodText(for: group.encounters))")

        appendReadableField("Types", backupTypeSummary(for: group.encounters), to: &lines)
        appendReadableField(L10n.text("Contextes", "Contexts"), backupContextSummary(for: group.encounters), to: &lines)
        appendReadableField(L10n.text("Villes", "Cities"), backupFrequencySummary(group.encounters.map(\.city)), to: &lines)
        lines.append("")

        for (encounterIndex, encounter) in group.encounters.enumerated() {
            lines.append(makeEncounterBackupSection(encounter, index: encounterIndex + 1))
        }

        return lines.joined(separator: "\n")
    }

    private func makeEncounterBackupSection(_ encounter: Encounter, index: Int) -> String {
        var lines: [String] = []
        lines.append(L10n.text("### Rencontre \(index)", "### Encounter \(index)"))
        lines.append("\(L10n.text("Date", "Date")) : \(backupDateText(encounter.date))")
        appendReadableField(L10n.text("Lieu", "Location"), backupLocationText(for: encounter), to: &lines)

        let headline = backupEncounterHeadline(for: encounter)
        if !headline.isEmpty {
            lines.append("\(L10n.text("Résumé", "Summary")) : \(headline)")
        }

        appendReadableField(L10n.text("Prénom ou surnom", "First name or nickname"), encounter.firstName, to: &lines)
        appendReadableField(L10n.text("Âge", "Age"), encounter.age.map { L10n.age($0) } ?? "", to: &lines)
        appendReadableField("Tags", backupListText(encounter.tags), to: &lines)
        appendReadableField("Green flags", backupListText(encounter.greenFlags), to: &lines)
        appendReadableField("Red flags", backupListText(encounter.redFlags), to: &lines)
        appendReadableTextBlock(L10n.text("Mémo", "Memo"), encounter.note, to: &lines)

        return lines.joined(separator: "\n")
    }

    private func backupEncounterHeadline(for encounter: Encounter) -> String {
        var parts: [String] = []

        if let type = encounter.type {
            parts.append(type.localizedName)
        }
        if let context = encounter.context {
            parts.append(context.localizedName)
        }
        if encounter.rating > 0 {
            parts.append("\(RatingScale.formatted(encounter.rating))/5")
        }
        if let outcome = encounter.outcome {
            parts.append(outcome.localizedName)
        }
        if encounter.wouldMeetAgain {
            parts.append(L10n.text("À revoir", "Would meet again"))
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
            .max { $0.count < $1.count } ?? L10n.text("Personne inconnue", "Unknown person")
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
            return count > 0 ? "\(type.localizedName) (\(count))" : nil
        }
        return parts.isEmpty ? "—" : parts.joined(separator: ", ")
    }

    private func backupContextSummary(for encounters: [Encounter]) -> String {
        let parts = EncounterContext.allCases.compactMap { context -> String? in
            let count = encounters.filter { $0.context == context }.count
            return count > 0 ? "\(context.localizedName) (\(count))" : nil
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
        L10n.date(date, includesTime: includesTime)
    }

    private func backupFileTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.dateFormat = "yyyy-MM-dd-HHmm"
        return formatter.string(from: Date())
    }

    private func yesNo(_ value: Bool) -> String {
        L10n.yesNo(value)
    }

    private var passcodeSetupSheet: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(L10n.text("Code Body X", "Body X code"), text: newPasscodeBinding)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)

                    SecureField(L10n.text("Confirmer le code", "Confirm code"), text: confirmPasscodeBinding)
                        .keyboardType(.numberPad)
                        .textContentType(.oneTimeCode)
                } footer: {
                    Text(L10n.text(
                        "Choisis un code de \(AppPasscodeStore.minimumLength) à \(AppPasscodeStore.maximumLength) chiffres. Il servira à déverrouiller l’app sans Touch ID ni Face ID.",
                        "Choose a \(AppPasscodeStore.minimumLength) to \(AppPasscodeStore.maximumLength) digit code. It will unlock the app without Touch ID or Face ID."
                    ))
                }

                if !passcodeSetupError.isEmpty {
                    Section {
                        Text(passcodeSetupError)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle(hasAppPasscode ? L10n.text("Modifier le code", "Change code") : L10n.text("Créer un code", "Create code"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("Annuler", "Cancel")) {
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
            showPhotoAccessAlert(message: L10n.text(
                "Autorise l’accès aux photos dans Réglages > Body X > Photos.",
                "Allow photo access in Settings > Body X > Photos."
            ))
        @unknown default:
            showPhotoAccessAlert(message: L10n.text(
                "Impossible d’accéder à la photothèque pour le moment.",
                "Unable to access the photo library right now."
            ))
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
            showPhotoAccessAlert(message: L10n.text(
                "Configure Face ID ou Touch ID dans Réglages iOS avant d’activer ce mode.",
                "Set up Face ID or Touch ID in iOS Settings before enabling this mode."
            ))
            return
        }

        let context = LAContext()
        context.localizedCancelTitle = L10n.text("Annuler", "Cancel")
        context.localizedFallbackTitle = L10n.text("Utiliser le code Body X", "Use Body X code")

        var error: NSError?

        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard context.biometryType != .faceID || hasFaceIDUsageDescription else {
            biometricLock = false
            showPhotoAccessAlert(message: L10n.text(
                "Ajoute Privacy - Face ID Usage Description dans le target Body X pour autoriser Face ID.",
                "Add Privacy - Face ID Usage Description to the Body X target to allow Face ID."
            ))
            return
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            biometricLock = false
            showPhotoAccessAlert(message: authenticationUnavailableMessage(from: error))
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: L10n.text("Activer le verrouillage de Body X", "Enable Body X lock")) { success, error in
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
            passcodeSetupError = L10n.text(
                "Le code doit contenir au moins \(AppPasscodeStore.minimumLength) chiffres.",
                "The code must contain at least \(AppPasscodeStore.minimumLength) digits."
            )
            return
        }

        guard newPasscode == confirmPasscode else {
            passcodeSetupError = L10n.text(
                "Les deux codes ne correspondent pas.",
                "The two codes do not match."
            )
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
            passcodeSetupError = L10n.text(
                "Impossible d’enregistrer le code pour le moment.",
                "Unable to save the code right now."
            )
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
            showPhotoAccessAlert(message: L10n.text(
                "Autorise l’accès aux photos dans Réglages > Body X > Photos.",
                "Allow photo access in Settings > Body X > Photos."
            ))
        }
    }

    private func requestCameraAccessAndPresentPicker() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showPhotoAccessAlert(message: L10n.text(
                "La caméra n’est pas disponible sur cet appareil.",
                "The camera is not available on this device."
            ))
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
                        showPhotoAccessAlert(message: L10n.text(
                            "Autorise l’accès à la caméra dans Réglages > Body X > Appareil photo.",
                            "Allow camera access in Settings > Body X > Camera."
                        ))
                    }
                }
            }
        case .denied, .restricted:
            showPhotoAccessAlert(message: L10n.text(
                "Autorise l’accès à la caméra dans Réglages > Body X > Appareil photo.",
                "Allow camera access in Settings > Body X > Camera."
            ))
        @unknown default:
            showPhotoAccessAlert(message: L10n.text(
                "Impossible d’accéder à la caméra pour le moment.",
                "Unable to access the camera right now."
            ))
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
            return L10n.text(
                "Configure Face ID, Touch ID ou un code dans Réglages avant d’activer ce verrouillage.",
                "Set up Face ID, Touch ID, or a passcode in Settings before enabling this lock."
            )
        case LAError.biometryNotAvailable.rawValue:
            return L10n.text(
                "Face ID / Touch ID n’est pas disponible. Le code de l’appareil sera utilisé s’il est configuré.",
                "Face ID / Touch ID is not available. The device passcode will be used if configured."
            )
        case LAError.biometryLockout.rawValue:
            return L10n.text(
                "Face ID / Touch ID est temporairement bloqué. Utilise le code de l’appareil.",
                "Face ID / Touch ID is temporarily locked. Use the device passcode."
            )
        case LAError.passcodeNotSet.rawValue:
            return L10n.text(
                "Aucun code n’est configuré sur cet appareil.",
                "No passcode is configured on this device."
            )
        case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
            return L10n.text(
                "Authentification annulée. Le verrouillage n’a pas été activé.",
                "Authentication canceled. The lock was not enabled."
            )
        default:
            return L10n.text(
                "Impossible d’activer Face ID, Touch ID ou le code pour le moment.",
                "Unable to enable Face ID, Touch ID, or the code right now."
            )
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
                Text(L10n.text("Politique de confidentialité de BodyX", "BodyX Privacy Policy"))
                    .font(.headline)
                PrivacyPolicyText(L10n.text("Dernière mise à jour : 9 juin 2026", "Last updated: June 9, 2026"))
                    .foregroundColor(.secondary)
            }

            Section("Introduction") {
                PrivacyPolicyText(L10n.text(
                    "BodyX respecte votre vie privée et s’engage à protéger vos données personnelles.",
                    "BodyX respects your privacy and is committed to protecting your personal data."
                ))
                PrivacyPolicyText(L10n.text(
                    "Cette politique de confidentialité explique quelles informations sont traitées lorsque vous utilisez l’application BodyX et comment celles-ci sont protégées.",
                    "This privacy policy explains what information is processed when you use the BodyX app and how it is protected."
                ))
                PrivacyPolicyText(L10n.text(
                    "En utilisant BodyX, vous acceptez les pratiques décrites dans cette politique.",
                    "By using BodyX, you accept the practices described in this policy."
                ))
            }

            Section(L10n.text("1. À propos de BodyX", "1. About BodyX")) {
                PrivacyPolicyText(L10n.text(
                    "BodyX est une application privée permettant aux utilisateurs de conserver un historique personnel de leurs relations et interactions intimes.",
                    "BodyX is a private app that lets users keep a personal history of their relationships and intimate interactions."
                ))
                PrivacyPolicyText(L10n.text(
                    "La confidentialité constitue un principe fondamental de la conception de l’application.",
                    "Privacy is a core principle in the design of the app."
                ))
            }

            Section(L10n.text("2. Données enregistrées", "2. Data saved in the app")) {
                PrivacyPolicyText(L10n.text(
                    "Les informations que vous saisissez dans BodyX, notamment les noms, surnoms, notes, dates, photos et autres informations personnelles que vous choisissez d’enregistrer, sont stockées exclusivement sur votre appareil.",
                    "The information you enter in BodyX, including names, nicknames, notes, dates, photos, and other personal information you choose to save, is stored exclusively on your device."
                ))
                PrivacyPolicyText(L10n.text(
                    "BodyX ne transmet pas ces informations à nos serveurs.",
                    "BodyX does not send this information to our servers."
                ))
                PrivacyPolicyText(L10n.text(
                    "Nous n’avons aucun accès à vos données personnelles ou à votre contenu.",
                    "We do not have access to your personal data or your content."
                ))
                PrivacyPolicyText(L10n.text(
                    "Nous ne pouvons pas consulter, récupérer, analyser ou partager les informations que vous enregistrez dans l’application.",
                    "We cannot view, retrieve, analyze, or share the information you save in the app."
                ))
            }

            Section(L10n.text("3. Absence de compte utilisateur", "3. No user account")) {
                PrivacyPolicyText(L10n.text(
                    "L’utilisation actuelle de BodyX ne nécessite aucune création de compte.",
                    "The current use of BodyX does not require creating an account."
                ))
                PrivacyPolicyText(L10n.text(
                    "Aucune inscription, adresse e-mail ou identification personnelle n’est demandée pour utiliser les fonctionnalités principales de l’application.",
                    "No registration, email address, or personal identification is requested to use the main features of the app."
                ))
            }

            Section(L10n.text("4. Stockage local des données", "4. Local data storage")) {
                PrivacyPolicyText(L10n.text(
                    "Toutes les données enregistrées dans BodyX sont conservées localement sur votre appareil.",
                    "All data saved in BodyX is kept locally on your device."
                ))
                PrivacyPolicyText(L10n.text(
                    "Aucune synchronisation avec un serveur distant n’est effectuée.",
                    "No synchronization with a remote server is performed."
                ))
                PrivacyPolicyText(L10n.text(
                    "Aucune base de données en ligne contenant vos informations personnelles n’est exploitée par BodyX.",
                    "BodyX does not operate any online database containing your personal information."
                ))
            }

            Section(L10n.text("5. Exportation de données", "5. Data export")) {
                PrivacyPolicyText(L10n.text(
                    "BodyX permet aux utilisateurs d’exporter certaines informations sous forme de document de sauvegarde.",
                    "BodyX allows users to export certain information as a backup document."
                ))
                PrivacyPolicyText(L10n.text(
                    "Une fois exporté hors de l’application, ce document devient sous la responsabilité exclusive de l’utilisateur.",
                    "Once exported outside the app, this document becomes the sole responsibility of the user."
                ))
                PrivacyPolicyText(L10n.text(
                    "BodyX ne contrôle pas l’utilisation, le stockage ou le partage des fichiers exportés.",
                    "BodyX does not control the use, storage, or sharing of exported files."
                ))
                PrivacyPolicyText(L10n.text(
                    "Nous recommandons aux utilisateurs de protéger ces fichiers et de les partager uniquement avec des personnes de confiance.",
                    "We recommend that users protect these files and share them only with trusted people."
                ))
            }

            Section(L10n.text("6. Accès aux fonctionnalités de l’appareil", "6. Access to device features")) {
                PrivacyPolicyText(L10n.text(
                    "Selon les fonctionnalités utilisées, BodyX peut demander les autorisations suivantes :",
                    "Depending on the features used, BodyX may request the following permissions:"
                ))
                PrivacyPolicyText(L10n.text(
                    "Appareil photo : permet d’ajouter des photos à vos entrées.",
                    "Camera: lets you add photos to your entries."
                ))
                PrivacyPolicyText(L10n.text(
                    "Bibliothèque de photos : permet de sélectionner des photos déjà présentes sur votre appareil.",
                    "Photo library: lets you select photos already stored on your device."
                ))
                PrivacyPolicyText(L10n.text(
                    "Face ID / Touch ID : permet de sécuriser l’accès à l’application et de protéger vos données contre les accès non autorisés.",
                    "Face ID / Touch ID: helps secure access to the app and protect your data from unauthorized access."
                ))
                PrivacyPolicyText(L10n.text(
                    "Ces autorisations sont facultatives et peuvent être désactivées à tout moment depuis les réglages de votre appareil.",
                    "These permissions are optional and can be disabled at any time from your device settings."
                ))
            }

            Section(L10n.text("7. Sécurité", "7. Security")) {
                PrivacyPolicyText(L10n.text(
                    "La protection de votre vie privée constitue l’une des priorités de BodyX.",
                    "Protecting your privacy is one of BodyX’s priorities."
                ))
                PrivacyPolicyText(L10n.text(
                    "Toutes les données enregistrées dans l’application sont stockées localement sur votre appareil et ne sont pas transmises à nos serveurs.",
                    "All data saved in the app is stored locally on your device and is not sent to our servers."
                ))
                PrivacyPolicyText(L10n.text(
                    "BodyX permet de protéger l’accès à vos informations grâce à un code PIN personnel défini par l’utilisateur ainsi qu’aux mécanismes biométriques pris en charge par votre appareil, tels que Face ID ou Touch ID.",
                    "BodyX can protect access to your information with a personal PIN code defined by the user and with biometric mechanisms supported by your device, such as Face ID or Touch ID."
                ))
                PrivacyPolicyText(L10n.text(
                    "Même les développeurs de BodyX ne peuvent pas accéder à vos données personnelles, à vos notes, à vos photos ou aux informations que vous enregistrez dans l’application.",
                    "Even the developers of BodyX cannot access your personal data, notes, photos, or information saved in the app."
                ))
                PrivacyPolicyText(L10n.text(
                    "Nous n’avons aucun moyen technique de consulter, récupérer ou analyser le contenu enregistré dans BodyX.",
                    "We have no technical way to view, retrieve, or analyze the content saved in BodyX."
                ))
                PrivacyPolicyText(L10n.text(
                    "Toutefois, la sécurité de vos données dépend également de la protection de votre appareil. Nous vous recommandons d’utiliser un code de verrouillage sécurisé et de maintenir votre système d’exploitation à jour.",
                    "However, the security of your data also depends on the protection of your device. We recommend using a secure device passcode and keeping your operating system up to date."
                ))
            }

            Section(L10n.text("8. Publicité", "8. Advertising")) {
                PrivacyPolicyText(L10n.text(
                    "À ce jour, BodyX n’affiche aucune publicité.",
                    "At this time, BodyX does not display any advertising."
                ))
                PrivacyPolicyText(L10n.text(
                    "Si des services publicitaires sont intégrés dans une future version de l’application, cette politique sera mise à jour afin d’expliquer clairement quelles données pourraient être utilisées et dans quel objectif.",
                    "If advertising services are added in a future version of the app, this policy will be updated to clearly explain what data could be used and for what purpose."
                ))
            }

            Section(L10n.text("9. Protection des mineurs", "9. Protection of minors")) {
                PrivacyPolicyText(L10n.text(
                    "BodyX est destiné aux personnes âgées d’au moins 16 ans.",
                    "BodyX is intended for people who are at least 16 years old."
                ))
                PrivacyPolicyText(L10n.text(
                    "Nous ne collectons pas sciemment de données concernant des enfants de moins de 16 ans.",
                    "We do not knowingly collect data concerning children under 16."
                ))
                PrivacyPolicyText(L10n.text(
                    "Si vous pensez qu’un mineur de moins de 16 ans utilise l’application contrairement à cette politique, veuillez nous contacter.",
                    "If you believe that a minor under 16 is using the app contrary to this policy, please contact us."
                ))
            }

            Section(L10n.text("10. Vos droits", "10. Your rights")) {
                PrivacyPolicyText(L10n.text(
                    "Conformément aux lois applicables en matière de protection des données, vous disposez notamment des droits suivants :",
                    "Under applicable data protection laws, you may have the following rights:"
                ))
                PrivacyPolicyText(L10n.text("Droit d’accès à vos données ;", "Right of access to your data;"))
                PrivacyPolicyText(L10n.text("Droit de rectification ;", "Right to rectification;"))
                PrivacyPolicyText(L10n.text("Droit à l’effacement ;", "Right to erasure;"))
                PrivacyPolicyText(L10n.text("Droit à la limitation du traitement ;", "Right to restriction of processing;"))
                PrivacyPolicyText(L10n.text("Droit d’opposition ;", "Right to object;"))
                PrivacyPolicyText(L10n.text("Droit à la portabilité.", "Right to portability."))
                PrivacyPolicyText(L10n.text(
                    "Étant donné que les données sont stockées uniquement sur votre appareil et ne sont pas accessibles par BodyX, la plupart de ces droits peuvent être exercés directement par vous depuis l’application ou en supprimant vos données localement.",
                    "Because the data is stored only on your device and is not accessible by BodyX, most of these rights can be exercised directly by you in the app or by deleting your local data."
                ))
            }

            Section(L10n.text("11. Modifications de cette politique", "11. Changes to this policy")) {
                PrivacyPolicyText(L10n.text(
                    "Nous pouvons modifier cette politique de confidentialité afin de refléter l’évolution de l’application ou des exigences légales.",
                    "We may update this privacy policy to reflect changes to the app or legal requirements."
                ))
                PrivacyPolicyText(L10n.text(
                    "La date de dernière mise à jour figurera toujours en haut de cette page.",
                    "The last updated date will always appear at the top of this page."
                ))
            }

            Section(L10n.text("12. Nous contacter", "12. Contact us")) {
                PrivacyPolicyText(L10n.text(
                    "Pour toute question concernant cette politique de confidentialité ou l’application BodyX, vous pouvez nous contacter :",
                    "For any question about this privacy policy or the BodyX app, you can contact us:"
                ))
                PrivacyPolicyText(L10n.text("Email : bodyxapp@gmail.com", "Email: bodyxapp@gmail.com"))
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.text("Confidentialité", "Privacy"))
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
