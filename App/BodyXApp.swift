import SwiftUI

@main
struct BodyXApp: App {
    @State private var vm = EncounterViewModel()
    @AppStorage("settings.theme") private var theme: String = "sombre"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vm)
                .preferredColorScheme(theme == "light" ? .light : .dark)
        }
    }
}
