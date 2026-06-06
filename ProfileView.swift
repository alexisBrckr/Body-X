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
                                size: 108
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
        }
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
