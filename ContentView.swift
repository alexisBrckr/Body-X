import SwiftUI
import LocalAuthentication

struct ContentView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @State private var selectedTab: Tab = .list
    @AppStorage("settings.theme") private var theme: String = "dark"
    @AppStorage("settings.biometricLock") private var biometricLock: Bool = false
    @AppStorage("settings.autolockSeconds") private var autoLockSeconds: Int = 0
    @Environment(\.scenePhase) private var scenePhase
    @State private var isUnlocked: Bool = true
    @State private var isAuthenticating: Bool = false
    @State private var backgroundAt: Date?

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
                VStack(spacing: 14) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 42))
                        .foregroundColor(.themeAccent)
                    Text("Application verrouillée")
                        .font(.headline)
                    Button("Déverrouiller avec Face ID / Touch ID") {
                        authenticate()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.themeAccent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
            }
        }
        .onAppear {
            if biometricLock {
                isUnlocked = false
                authenticate()
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
                    isUnlocked = false
                    authenticate()
                }
            }
        }
        .onChange(of: biometricLock) { enabled in
            if !enabled { isUnlocked = true }
            if enabled {
                isUnlocked = false
                authenticate()
            }
        }
    }
    
    private func authenticate() {
        if isAuthenticating { return }
        isAuthenticating = true
        let context = LAContext()
        context.localizedCancelTitle = "Annuler"
        var error: NSError?
        let reason = "Déverrouiller Body X"
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    isUnlocked = success
                    isAuthenticating = false
                }
            }
            return
        }
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            DispatchQueue.main.async {
                isAuthenticating = false
                isUnlocked = true
            }
            return
        }
        
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason) { success, _ in
            DispatchQueue.main.async {
                isUnlocked = success
                isAuthenticating = false
            }
        }
    }
}
