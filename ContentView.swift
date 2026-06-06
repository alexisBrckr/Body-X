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
                return "Biométrie"
            }
        case .passcode:
            return "Code Body X"
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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked: Bool = true
    @State private var isAuthenticating: Bool = false
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
                        Label("Liste", systemImage: "list.bullet")
                    }
                    .tag(Tab.list)

                EncounterMapView()
                    .tabItem {
                        Label("Carte", systemImage: "map")
                    }
                    .tag(Tab.map)

                StatsView()
                    .tabItem {
                        Label("Stats", systemImage: "chart.bar.fill")
                    }
                    .tag(Tab.stats)

                ProfileView()
                    .tabItem {
                        Label("Profil", systemImage: "person.fill")
                    }
                    .tag(Tab.profile)
            }
            .tint(.themeAccent)
            
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
            if (phase == .inactive || phase == .background) && biometricLock {
                backgroundAt = Date()
                if autoLockSeconds == 0 {
                    isUnlocked = false
                }
            }
            if phase == .active && biometricLock {
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
        .onChange(of: biometricLock) { enabled in
            if !enabled { isUnlocked = true }
            if enabled {
                isUnlocked = true
            }
        }
        .alert("Déverrouillage indisponible", isPresented: $showAuthenticationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authenticationErrorMessage)
        }
    }

    private var lockedOverlay: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 42))
                .foregroundColor(.themeAccent)
            Text("Application verrouillée")
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
                Button("Déverrouiller avec \(authenticationMethod.title(for: supportedBiometryType))") {
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
            SecureField("Code Body X", text: passcodeInputBinding)
                .textFieldStyle(.roundedBorder)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isPasscodeFieldFocused)
                .frame(maxWidth: 240)

            Button("Déverrouiller") {
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
        context.localizedCancelTitle = "Annuler"
        context.localizedFallbackTitle = AppPasscodeStore.hasPasscode ? "Utiliser le code Body X" : ""
        var error: NSError?
        let reason = "Déverrouiller Body X"

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
            disableBiometricLock(message: "Ajoute Privacy - Face ID Usage Description dans le target Body X pour autoriser Face ID.")
            return
        }

        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            if AppPasscodeStore.hasPasscode {
                showPasscodeFallback(message: "Entre le code Body X pour déverrouiller l’app.")
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
                    showPasscodeFallback(message: "Entre le code Body X pour déverrouiller l’app.")
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
            authenticationErrorMessage = "Crée d’abord un code Body X dans Profil > Paramètres."
            biometricLock = false
            isUnlocked = true
            passcodeInput = ""
            return
        }

        guard AppPasscodeStore.validate(passcodeInput) else {
            authenticationErrorMessage = "Code incorrect."
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
            return "Configure Face ID, Touch ID ou un code dans Réglages avant d’activer ce verrouillage."
        case LAError.biometryNotAvailable.rawValue:
            return "Face ID / Touch ID n’est pas disponible. Utilise le code si l’appareil en a un."
        case LAError.biometryLockout.rawValue:
            return "Face ID / Touch ID est temporairement bloqué. Utilise le code de l’appareil."
        case LAError.passcodeNotSet.rawValue:
            return "Aucun code n’est configuré sur cet appareil."
        case LAError.userCancel.rawValue, LAError.systemCancel.rawValue, LAError.appCancel.rawValue:
            return "Authentification annulée."
        default:
            return "Impossible d’utiliser Face ID, Touch ID ou le code pour le moment."
        }
    }
}
