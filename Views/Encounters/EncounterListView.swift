import SwiftUI

struct EncounterListView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @AppStorage("settings.theme") private var theme: String = "sombre"
    @State private var showAddSheet = false
    @State private var selectedEncounter: Encounter?
    @State private var selectedPersonGroupID: UUID?
    
    private var searchBinding: Binding<String> {
        Binding(
            get: { vm.searchQuery },
            set: { vm.searchQuery = InputSanitizer.cleanSingleLine($0, maxLength: 60) }
        )
    }

    private var brandTitle: some View {
        Text("BodyX")
            .font(.system(size: 20, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(listAccentColor)
            .clipShape(Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("BodyX")
    }

    private var listAccentColor: Color {
        theme == "light" ? .themePink : .themeViolet
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.encounters.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    brandTitle
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.themeAccent)
                    }
                }
            }
            .searchable(text: searchBinding, prompt: L10n.text("Rechercher...", "Search..."))
            .sheet(isPresented: $showAddSheet) {
                AddEncounterView()
            }
            .sheet(item: $selectedEncounter) { encounter in
                EncounterDetailView(encounter: encounter)
            }
            .sheet(isPresented: Binding(
                get: { selectedPersonGroupID != nil },
                set: { if !$0 { selectedPersonGroupID = nil } }
            )) {
                if let personID = selectedPersonGroupID {
                    PersonEncounterPickerView(
                        personGroup: vm.alphabeticalPersonGroups.first(where: { $0.id == personID }),
                        onSelect: { encounter in
                            selectedPersonGroupID = nil
                            selectedEncounter = encounter
                        }
                    )
                }
            }
        }
    }

    // MARK: - Stats Header
    private var statsHeader: some View {
        HStack(spacing: 10) {
            StatPillView(value: "\(vm.bodyCount)", label: "Body")
            StatPillView(value: "\(vm.preliCount)", label: "Preli")
            StatPillView(value: "\(vm.kissCount)", label: "Kiss")
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: - Year Filter
    private var yearFilter: some View {
        HStack(spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.availableYears, id: \.self) { year in
                        Button {
                            vm.selectedYear = year
                        } label: {
                            Text(year)
                                .font(.system(size: 16, weight: .semibold))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .frame(minHeight: 44)
                                .background(vm.selectedYear == year ? Color.themeAccent : Color(.systemGray6))
                                .foregroundColor(vm.selectedYear == year ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            Menu {
                ForEach([
                    EncounterViewModel.SortOption.none,
                    .alphabetical,
                    .kiss,
                    .preli,
                    .body
                ], id: \.self) { option in
                    Button {
                        vm.sortOption = option
                    } label: {
                        if vm.sortOption == option {
                            Label(option.label, systemImage: "checkmark")
                        } else {
                            Text(option.label)
                        }
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 26, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .foregroundColor(.themeAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    // MARK: - List Content
    private var listContent: some View {
        List {
            Section {
                statsHeader
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                yearFilter
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if vm.sortOption == .none {
                ForEach(vm.groupedByYear, id: \.0) { year, list in
                    Section(header: Text(year).font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary).textCase(.uppercase)) {
                        ForEach(list) { encounter in
                            Button {
                                selectedEncounter = encounter
                            } label: {
                                EncounterRowView(encounter: encounter)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        }
                        .onDelete { offsets in
                            vm.delete(at: offsets, in: list)
                        }
                    }
                }
            } else if vm.sortOption == .alphabetical {
                Section {
                    ForEach(vm.alphabeticalPersonGroups) { group in
                        Button {
                            selectedPersonGroupID = group.id
                        } label: {
                            PersonGroupRowView(group: group)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            } else {
                Section {
                    ForEach(vm.filteredEncounters) { encounter in
                        Button {
                            selectedEncounter = encounter
                        } label: {
                            EncounterRowView(encounter: encounter)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                    .onDelete { offsets in
                        vm.delete(at: offsets, in: vm.filteredEncounters)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 56))
                .foregroundColor(.themeAccent.opacity(0.45))
            Text(L10n.text("Aucune entrée", "No entries"))
                .font(.title3.bold())
            Text(L10n.text("Appuie sur + pour ajouter ta première rencontre.", "Tap + to add your first encounter."))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button(L10n.text("Ajouter", "Add")) { showAddSheet = true }
                .buttonStyle(.borderedProminent)
                .tint(.themeAccent)
        }
        .padding()
    }
}

struct PersonGroupRowView: View {
    @AppStorage("settings.privacyMode") private var privacyMode = false

    let group: EncounterViewModel.AlphabeticalPersonGroup

    private var displayName: String {
        privacyMode ? L10n.text("Personne masquée", "Hidden person") : group.displayName
    }

    var body: some View {
        HStack(spacing: 14) {
            if let latest = group.encounters.first {
                AvatarView(
                    initials: latest.initials,
                    gender: latest.gender,
                    encounterType: latest.type ?? .body,
                    photoDataBase64: latest.photoDataBase64,
                    customEmoji: latest.customEmoji,
                    customEmojiBackgroundHex: latest.customEmojiBackgroundHex,
                    size: 52
                )
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(L10n.encounterCount(group.encounters.count))
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }
}

struct PersonEncounterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.privacyMode") private var privacyMode = false

    let personGroup: EncounterViewModel.AlphabeticalPersonGroup?
    let onSelect: (Encounter) -> Void
    @State private var selectedCardIndex = 0

    private var displayName: String {
        guard personGroup != nil else { return L10n.text("Rencontres", "Encounters") }
        return privacyMode ? L10n.text("Personne masquée", "Hidden person") : personGroup?.displayName ?? L10n.text("Rencontres", "Encounters")
    }

    private func cityText(for encounter: Encounter) -> String {
        privacyMode ? L10n.text("Lieu masqué", "Hidden location") : encounter.city
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let personGroup, let latest = personGroup.encounters.first {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 12) {
                            AvatarView(
                                initials: latest.initials,
                                gender: latest.gender,
                                encounterType: latest.type ?? .body,
                                photoDataBase64: latest.photoDataBase64,
                                customEmoji: latest.customEmoji,
                                customEmojiBackgroundHex: latest.customEmojiBackgroundHex,
                                size: 74
                            )
                            VStack(alignment: .leading, spacing: 4) {
                                Text(displayName)
                                    .font(.system(size: 22, weight: .bold))
                                HStack(spacing: 8) {
                                Text(L10n.encounterCount(personGroup.encounters.count))
                                        .font(.system(size: 14))
                                        .foregroundColor(.secondary)
                                    if let age = latest.age, !privacyMode {
                                        Text(L10n.text("· \(age) ans", "· \(age) years old"))
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                        Text(L10n.text("Fiches récapitulatives", "Summary cards"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)

                        TabView(selection: $selectedCardIndex) {
                            ForEach(Array(personGroup.encounters.enumerated()), id: \.element.id) { index, encounter in
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(L10n.text("Rencontre \(index + 1)", "Encounter \(index + 1)"))
                                            .font(.system(size: 18, weight: .bold))
                                        Spacer()
                                        if let type = encounter.type {
                                            HStack(spacing: 5) {
                                                Text(type.emoji)
                                                Text(type.localizedName)
                                                    .lineLimit(1)
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(Color.themeAccent.opacity(0.18))
                                            .foregroundColor(.primary)
                                            .clipShape(Capsule())
                                        }
                                    }

                                    HStack(spacing: 8) {
                                        Label(encounter.formattedDate, systemImage: "calendar")
                                            .lineLimit(1)
                                        if !encounter.city.isEmpty {
                                            Label(cityText(for: encounter), systemImage: "mappin.and.ellipse")
                                                .lineLimit(1)
                                        }
                                    }
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 2)

                                    if encounter.rating > 0 {
                                        StarRatingView(rating: encounter.rating, size: 13)
                                    }

                                    if privacyMode && !encounter.note.isEmpty {
                                        Label(L10n.text("Note privée masquée", "Private note hidden"), systemImage: "eye.slash.fill")
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .padding(.top, 2)
                                    } else if !encounter.note.isEmpty {
                                        Text(encounter.note)
                                            .font(.system(size: 14))
                                            .foregroundColor(.primary)
                                            .lineLimit(4)
                                            .padding(.top, 2)
                                    } else {
                                            Text(L10n.text("Aucune note privée", "No private note"))
                                                .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                            .italic()
                                    }

                                    Spacer()
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                .background(
                                    LinearGradient(
                                        colors: [Color.themeSurface, Color.themeSurface.opacity(0.92)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.themeSilver.opacity(0.25), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 3)
                                .cornerRadius(16)
                                .tag(index)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 6)
                            }
                        }
                        .frame(height: 250)
                        .tabViewStyle(.page(indexDisplayMode: .automatic))

                        if !personGroup.encounters.isEmpty {
                            Button {
                                let safeIndex = min(max(0, selectedCardIndex), personGroup.encounters.count - 1)
                                onSelect(personGroup.encounters[safeIndex])
                            } label: {
                                HStack {
                                    Text(L10n.text("Ouvrir la fiche", "Open details"))
                                        .font(.system(size: 15, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                        .font(.system(size: 20))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(Color.themeAccent.opacity(0.16))
                                .foregroundColor(.themeAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.text("Fermer", "Close")) { dismiss() }
                        .foregroundColor(.themeAccent)
                }
            }
        }
    }
}

// MARK: - Stat Pill
struct StatPillView: View {
    @AppStorage("settings.theme") private var theme: String = "sombre"

    let value: String
    let label: String

    private var tint: Color {
        theme == "light" ? .themePink : .themeViolet
    }

    private var surface: Color {
        theme == "light" ? .white : Color.themeSurface
    }

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(tint)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(tint.opacity(0.28), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}
