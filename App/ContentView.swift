import SwiftUI
import LocalAuthentication

enum AppAuthenticationMethod: String, CaseIterable, Identifiable {
    case biometry
    case passcode

    var id: String { rawValue }

    func title(for biometryType: LABiometryType) -> String {
        switch self {
        case .biometry:
            switch biometryType {
            case .faceID:
                return "Face ID"
            case .touchID:
                return "Touch ID"
            default:
                return L10n.text("Biométrie", "Biometrics")
            }
        case .passcode:
            return L10n.text("Code Body X", "Body X code")
        }
    }

    func icon(for biometryType: LABiometryType) -> String {
        switch self {
        case .biometry:
            switch biometryType {
            case .faceID:
                return "faceid"
            case .touchID:
                return "touchid"
            default:
                return "person.badge.key.fill"
            }
        case .passcode:
            return "number.square.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @State private var selectedTab: Tab = .list
    @AppStorage("settings.theme") private var theme: String = "dark"
    @AppStorage("settings.biometricLock") private var biometricLock: Bool = false
    @AppStorage("settings.authenticationMethod") private var authenticationMethodRaw: String = AppAuthenticationMethod.biometry.rawValue
    @AppStorage("settings.autolockSeconds") private var autoLockSeconds: Int = 0
    @AppStorage("settings.privacyShield") private var privacyShield: Bool = true
    @AppStorage("settings.language") private var languageRaw: String = AppLanguage.french.rawValue
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked: Bool = true
    @State private var isAuthenticating: Bool = false
    @State private var isPrivacyShieldVisible: Bool = false
    @State private var backgroundAt: Date?
    @State private var authenticationErrorMessage = ""
    @State private var showAuthenticationError = false
    @State private var supportedBiometryType: LABiometryType = .none
    @State private var passcodeInput = ""
    @State private var isShowingPasscodeEntry = false
    @FocusState private var isPasscodeFieldFocused: Bool

    enum Tab { case list, map, stats, profile }

    var body: some View {
        ZStack {
            TabView(selection: $selectedTab) {
                EncounterListView()
                    .tabItem {
                        Label(L10n.text("Liste", "List"), systemImage: "list.bullet")
                    }
                    .tag(Tab.list)

                EncounterMapView()
                    .tabItem {
                        Label(L10n.text("Carte", "Map"), systemImage: "map")
                    }
                    .tag(Tab.map)

                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(Tab.stats)

                ProfileView()
                    .tabItem {
                        Label(L10n.text("Profil", "Profile"), systemImage: "person.fill")
                    }
                    .tag(Tab.profile)
            }
            .tint(.themeAccent)
            .id(languageRaw)

            if privacyShield && isPrivacyShieldVisible {
                privacyShieldOverlay
            }
            
            if biometricLock && !isUnlocked {
                lockedOverlay
            }
        }
        .onAppear {
            refreshSupportedBiometryType()
            if biometricLock {
                lockApp()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .inactive || phase == .background {
                if privacyShield {
                    isPrivacyShieldVisible = true
                }

                if biometricLock {
                    backgroundAt = Date()
                    if autoLockSeconds == 0 {
                        isUnlocked = false
                    }
                }
            }

            if phase == .active {
                isPrivacyShieldVisible = false

                if biometricLock {
                    let shouldLock: Bool
                    if autoLockSeconds == 0 {
                        shouldLock = !isUnlocked
                    } else if let backgroundAt {
                        shouldLock = Date().timeIntervalSince(backgroundAt) >= Double(autoLockSeconds)
                    } else {
                        shouldLock = false
                    }
                    if shouldLock {
                        lockApp()
                    }
                }
            }
        }
        .onChange(of: biometricLock) { enabled in
            if !enabled { isUnlocked = true }
            if enabled {
                isUnlocked = true
            }
        }
        .alert(L10n.text("Déverrouillage indisponible", "Unlock unavailable"), isPresented: $showAuthenticationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authenticationErrorMessage)
        }
        .onChange(of: privacyShield) { enabled in
            if !enabled {
                isPrivacyShieldVisible = false
            }
        }
    }

    private var privacyShieldOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "eye.slash.fill")
                .font(.system(size: 44))
                .foregroundColor(.themeAccent)
            Text("Body X")
                .font(.system(size: 28, weight: .black, design: .rounded))
            Text(L10n.text("Aperçu masqué", "Preview hidden"))
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.themeBlack)
    }

    private var lockedOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(.themeAccent)
            Text(L10n.text("Application verrouillée", "App locked"))
                .font(.headline)
            if !authenticationErrorMessage.isEmpty {
                Text(authenticationErrorMessage)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if shouldShowPasscodeEntry {
                passcodeUnlockControls
            } else {
                Button(L10n.text("Déverrouiller avec", "Unlock with") + " \(authenticationMethod.title(for: supportedBiometryType))") {
                    authenticate()
                }
                .buttonStyle(.borderedProminent)
                .tint(.themeAccent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }

    private var passcodeUnlockControls: some View {
        VStack(spacing: 10) {
            SecureField(L10n.text("Code Body X", "Body X code"), text: passcodeInputBinding)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isPasscodeFieldFocused)
                .frame(maxWidth: 240)

            Button(L10n.text("Déverrouiller", "Unlock")) {
                unlockWithAppPasscode()
            }
            .buttonStyle(.borderedProminent)
            .tint(.themeAccent)
            .disabled(passcodeInput.count < AppPasscodeStore.minimumLength)
        }
    }

    private var passcodeInputBinding: Binding<String> {
        Binding(
            get: { passcodeInput },
            set: { passcodeInput = AppPasscodeStore.normalized($0) }
        )
    }

    private var shouldShowPasscodeEntry: Bool {
        authenticationMethod == .passcode || isShowingPasscodeEntry
    }

    private func lockApp() {
        isUnlocked = false
        authenticationErrorMessage = ""
        passcodeInput = ""
        isShowingPasscodeEntry = authenticationMethod == .passcode

        if authenticationMethod == .biometry {
            authenticate()
        } else {
            focusPasscodeField()
        }
    }
    
    private func authenticate() {
        guard authenticationMethod == .biometry else {
            isShowingPasscodeEntry = true
            focusPasscodeField()
            return
        }

        if isAuthenticating { return }
        isAuthenticating = true

        let context = LAContext()
        context.localizedCancelTitle = L10n.text("Annuler", "Cancel")
        context.localizedFallbackTitle = AppPasscodeStore.hasPasscode ? L10n.text("Utiliser le code Body X", "Use Body X code") : ""
        var error: NSError?
        let reason = L10n.text("Déverrouiller Body X", "Unlock Body X")

        // Helper to finish on main thread
        func finish(success: Bool) {
            DispatchQueue.main.async {
                self.isUnlocked = success
                self.isAuthenticating = false
                self.isShowingPasscodeEntry = false
                self.passcodeInput = ""
                if success {
                    self.authenticationErrorMessage = ""
                }
            }
        }

        func disableBiometricLock(message: String) {
            DispatchQueue.main.async {
                self.authenticationErrorMessage = message
                self.showAuthenticationError = true
                self.biometricLock = false
                self.isUnlocked = true
                self.isAuthenticating = false
            }
        }

        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        guard context.biometryType != .faceID || hasFaceIDUsageDescription else {
            disableBiometricLock(message: L10n.text("Ajoute Privacy - Face ID Usage Description dans le target Body X pour autoriser Face ID.", "Add Privacy - Face ID Usage Description to the Body X target to allow Face ID."))
            return
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if AppPasscodeStore.hasPasscode {
                showPasscodeFallback(message: L10n.text("Entre le code Body X pour déverrouiller l’app.", "Enter your Body X code to unlock the app."))
            } else {
                disableBiometricLock(message: authenticationUnavailableMessage(from: error))
            }
            return
        }

        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, evaluationError in
            if success {
                finish(success: true)
            } else {
                let errorCode = (evaluationError as NSError?)?.code
                if AppPasscodeStore.hasPasscode && errorCode == LAError.userFallback.rawValue {
                    showPasscodeFallback(message: L10n.text("Entre le code Body X pour déverrouiller l’app.", "Enter your Body X code to unlock the app."))
                    return
                }

                DispatchQueue.main.async {
                    self.authenticationErrorMessage = authenticationUnavailableMessage(from: evaluationError as NSError?)
                    self.isAuthenticating = false
                }
            }
        }
    }

    private func unlockWithAppPasscode() {
        guard AppPasscodeStore.hasPasscode else {
            authenticationErrorMessage = L10n.text("Crée d’abord un code Body X dans Profil > Paramètres.", "Create a Body X code first in Profile > Settings.")
            biometricLock = false
            isUnlocked = true
            passcodeInput = ""
            return
        }

        guard AppPasscodeStore.validate(passcodeInput) else {
            authenticationErrorMessage = L10n.text("Code incorrect.", "Incorrect code.")
            passcodeInput = ""
            focusPasscodeField()
            return
        }

        isUnlocked = true
        isShowingPasscodeEntry = false
        authenticationErrorMessage = ""
        passcodeInput = ""
    }

    private func showPasscodeFallback(message: String) {
        DispatchQueue.main.async {
            self.authenticationErrorMessage = message
            self.isShowingPasscodeEntry = true
            self.isAuthenticating = false
            self.passcodeInput = ""
            self.focusPasscodeField()
        }
    }

    private func focusPasscodeField() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.isPasscodeFieldFocused = true
        }
    }

    private var authenticationMethod: AppAuthenticationMethod {
        AppAuthenticationMethod(rawValue: authenticationMethodRaw) ?? .passcode
    }

    private var hasFaceIDUsageDescription: Bool {
        Bundle.main.object(forInfoDictionaryKey: "NSFaceIDUsageDescription") is String
    }

    private func refreshSupportedBiometryType() {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        supportedBiometryType = context.biometryType
    }

    private func authenticationUnavailableMessage(from error: NSError?) -> String {
        switch error?.code {
        case LAError.biometryNotEnrolled.rawValue:
            return L10n.text("Configure Face ID, Touch ID ou un code dans Réglages avant d’activer ce verrouillage.", "Set up Face ID, Touch ID, or a passcode in Settings before enabling this lock.")
        case LAError.biometryNotAvailable.rawValue:
            return L10n.text("Face ID / Touch ID n’est pas disponible. Utilise le code si l’appareil en a un.", "Face ID / Touch ID is unavailable. Use the code if the device has one.")
        case LAError.biometryLockout.rawValue:
            return L10n.text("Face ID / Touch ID est temporairement bloqué. Utilise le code de l’appareil.", "Face ID / Touch ID is temporarily locked. Use the device passcode.")
        case LAError.passcodeNotSet.rawValue:
            return L10n.text("Aucun code n’est configuré sur cet appareil.", "No passcode is configured on this device.")
        case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
            return L10n.text("Authentification annulée.", "Authentication canceled.")
        default:
            return L10n.text("Impossible d’utiliser Face ID, Touch ID ou le code pour le moment.", "Unable to use Face ID, Touch ID, or the code right now.")
        }
    }
}
