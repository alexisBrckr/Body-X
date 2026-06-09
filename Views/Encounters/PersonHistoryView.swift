import SwiftUI

struct PersonHistoryView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("settings.privacyMode") private var privacyMode = false
    @State private var selectedEncounter: Encounter?

    let personID: UUID

    private var summary: EncounterViewModel.PersonSummary? {
        vm.personSummary(for: personID)
    }

    private var history: [Encounter] {
        vm.encounters(forPersonID: personID)
    }

    private var oldestEncounter: Encounter? {
        history.min { $0.date < $1.date }
    }

    private var latestEncounter: Encounter? {
        history.max { $0.date < $1.date }
    }

    private var displayName: String {
        if privacyMode { return "Personne masquée" }
        return summary?.displayName ?? latestEncounter?.firstName ?? "Personne"
    }

    private var averageRating: Double {
        let rated = history.filter { $0.rating > 0 }
        guard !rated.isEmpty else { return 0 }
        return rated.map(\.rating).reduce(0, +) / Double(rated.count)
    }

    private var averageRatingText: String {
        averageRating > 0 ? RatingScale.formattedAverage(averageRating) : "—"
    }

    private var relationDatesText: String {
        guard let first = oldestEncounter, let last = latestEncounter else { return "—" }
        if Calendar.current.isDate(first.date, inSameDayAs: last.date) {
            return first.formattedDate
        }
        return "\(first.formattedDate) - \(last.formattedDate)"
    }

    private var topCityText: String {
        guard topValues(history.map(\.city), limit: 1).first != nil else { return "—" }
        return privacyMode ? "Lieu masqué" : topValues(history.map(\.city), limit: 1).first?.0 ?? "—"
    }

    private var typeCounts: [(EncounterType, Int)] {
        EncounterType.allCases.compactMap { type in
            let count = history.filter { ($0.type ?? .body) == type }.count
            return count > 0 ? (type, count) : nil
        }
    }

    private var contextCounts: [(EncounterContext, Int)] {
        EncounterContext.allCases.compactMap { context in
            let count = history.filter { $0.context == context }.count
            return count > 0 ? (context, count) : nil
        }
        .sorted { $0.1 > $1.1 }
    }

    private var topTags: [(String, Int)] {
        topValues(history.flatMap(\.tags), limit: 8)
    }

    private var topGreenFlags: [(String, Int)] {
        topValues(history.flatMap(\.greenFlags), limit: 8)
    }

    private var topRedFlags: [(String, Int)] {
        topValues(history.flatMap(\.redFlags), limit: 8)
    }

    var body: some View {
        NavigationStack {
            List {
                if let latestEncounter {
                    Section {
                        PersonProfileHeaderView(
                            encounter: latestEncounter,
                            displayName: displayName,
                            encounterCount: history.count,
                            relationDatesText: relationDatesText,
                            isLongTerm: summary?.isLongTerm == true,
                            privacyMode: privacyMode
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                }

                overviewSection
                activitySection
                preferencesSection
                historySection
            }
            .listStyle(.insetGrouped)
            .navigationTitle(displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.themeAccent)
                }
            }
            .sheet(item: $selectedEncounter) { encounter in
                EncounterDetailView(encounter: encounter)
            }
        }
    }

    private var overviewSection: some View {
        Section("Résumé") {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                PersonMetricTile(
                    icon: "number",
                    label: "Rencontres",
                    value: "\(history.count)"
                )
                PersonMetricTile(
                    icon: "calendar",
                    label: "Période",
                    value: summary?.relationDurationText ?? "—"
                )
                PersonMetricTile(
                    icon: "star.fill",
                    label: "Note moy.",
                    value: averageRatingText,
                    tint: .yellow
                )
                PersonMetricTile(
                    icon: "mappin",
                    label: "Ville #1",
                    value: topCityText
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
        }
    }

    @ViewBuilder
    private var activitySection: some View {
        if !typeCounts.isEmpty || !contextCounts.isEmpty {
            Section("Profil de rencontre") {
                if !typeCounts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Types")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach(typeCounts, id: \.0.rawValue) { type, count in
                            PersonDistributionRow(
                                icon: type.icon,
                                emoji: type.emoji,
                                label: type.rawValue,
                                count: count,
                                total: history.count,
                                tint: .themeAccent
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }

                if !contextCounts.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Contextes")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        ForEach(contextCounts, id: \.0.rawValue) { context, count in
                            PersonDistributionRow(
                                icon: context.icon,
                                emoji: nil,
                                label: context.rawValue,
                                count: count,
                                total: history.count,
                                tint: .blue
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    @ViewBuilder
    private var preferencesSection: some View {
        if privacyMode && (!topTags.isEmpty || !topGreenFlags.isEmpty || !topRedFlags.isEmpty) {
            Section("Ce qui revient souvent") {
                Label("Tags et flags masqués en mode discret", systemImage: "eye.slash.fill")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        } else if !topTags.isEmpty || !topGreenFlags.isEmpty || !topRedFlags.isEmpty {
            Section("Ce qui revient souvent") {
                if !topTags.isEmpty {
                    PersonTagGroup(title: "Tags", items: topTags, tint: .themeAccent)
                }

                if !topGreenFlags.isEmpty {
                    PersonTagGroup(title: "Green flags", items: topGreenFlags, tint: .green)
                }

                if !topRedFlags.isEmpty {
                    PersonTagGroup(title: "Red flags", items: topRedFlags, tint: .red)
                }
            }
        }
    }

    private var historySection: some View {
        Section("Historique") {
            ForEach(history) { encounter in
                Button {
                    selectedEncounter = encounter
                } label: {
                    PersonTimelineRow(encounter: encounter)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func topValues(_ values: [String], limit: Int) -> [(String, Int)] {
        let cleanedValues = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        return Dictionary(grouping: cleanedValues) { $0 }
            .map { ($0.key, $0.value.count) }
            .sorted {
                if $0.1 == $1.1 {
                    return $0.0.localizedCaseInsensitiveCompare($1.0) == .orderedAscending
                }
                return $0.1 > $1.1
            }
            .prefix(limit)
            .map { $0 }
    }
}

private struct PersonProfileHeaderView: View {
    let encounter: Encounter
    let displayName: String
    let encounterCount: Int
    let relationDatesText: String
    let isLongTerm: Bool
    let privacyMode: Bool

    private var subtitle: String {
        if privacyMode {
            return "Fiche personne masquée"
        }

        var parts: [String] = []
        if let age = encounter.age {
            parts.append("\(age) ans")
        }
        if let gender = encounter.gender {
            parts.append(gender.rawValue)
        }
        if !encounter.city.isEmpty {
            parts.append(encounter.city)
        }
        return parts.isEmpty ? "Fiche personne" : parts.joined(separator: " · ")
    }

    private var badgeText: String {
        if isLongTerm { return "Relation suivie" }
        if encounterCount > 1 { return "Personne revue" }
        return "Rencontre unique"
    }

    private var badgeIcon: String {
        if isLongTerm { return "heart.fill" }
        if encounterCount > 1 { return "person.2.fill" }
        return "person.fill"
    }

    private var badgeColor: Color {
        if isLongTerm { return .pink }
        if encounterCount > 1 { return .themeAccent }
        return .secondary
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            AvatarView(
                initials: encounter.initials,
                gender: encounter.gender,
                encounterType: encounter.type ?? .body,
                photoDataBase64: encounter.photoDataBase64,
                customEmoji: encounter.customEmoji,
                customEmojiBackgroundHex: encounter.customEmojiBackgroundHex,
                size: 76
            )

            VStack(alignment: .leading, spacing: 8) {
                Text(displayName)
                    .font(.title3.bold())
                    .foregroundColor(.primary)
                    .lineLimit(2)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Image(systemName: badgeIcon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(badgeText)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(badgeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(badgeColor.opacity(0.12))
                .clipShape(Capsule())

                Label(relationDatesText, systemImage: "clock.arrow.circlepath")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }
}

private struct PersonMetricTile: View {
    let icon: String
    let label: String
    let value: String
    var tint: Color = .themeAccent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(tint)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
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

private struct PersonDistributionRow: View {
    let icon: String
    let emoji: String?
    let label: String
    let count: Int
    let total: Int
    let tint: Color

    private var ratio: CGFloat {
        guard total > 0 else { return 0 }
        return CGFloat(count) / CGFloat(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 8) {
                if let emoji {
                    Text(emoji)
                        .font(.system(size: 14))
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tint)
                        .frame(width: 18)
                }

                Text(label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)

                Spacer()

                Text("\(count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.themeSilver.opacity(0.16))
                    Capsule()
                        .fill(tint.opacity(0.62))
                        .frame(width: max(8, proxy.size.width * ratio))
                }
            }
            .frame(height: 6)
        }
    }
}

private struct PersonTagGroup: View {
    let title: String
    let items: [(String, Int)]
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)

            FlowWrapView(items: items.map { "\($0.0) ×\($0.1)" }) { item in
                TagChip(text: item, tint: tint.opacity(0.18))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PersonTimelineRow: View {
    @AppStorage("settings.privacyMode") private var privacyMode = false

    let encounter: Encounter

    private var cityText: String {
        privacyMode ? "Lieu masqué" : encounter.city
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 4) {
                Circle()
                    .fill(Color.themeAccent)
                    .frame(width: 9, height: 9)
                Rectangle()
                    .fill(Color.themeSilver.opacity(0.22))
                    .frame(width: 2, height: 48)
            }
            .padding(.top, 8)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline) {
                    Text(encounter.formattedDate)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)

                    Spacer()

                    if let type = encounter.type {
                        Text("\(type.emoji) \(type.rawValue)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                HStack(spacing: 8) {
                    if !encounter.city.isEmpty {
                        Label(cityText, systemImage: "mappin")
                            .lineLimit(1)
                    }

                    if let context = encounter.context {
                        Label(context.rawValue, systemImage: context.icon)
                            .lineLimit(1)
                    }
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                if encounter.rating > 0 {
                    StarRatingView(rating: encounter.rating, size: 12)
                }

                if privacyMode && !encounter.note.isEmpty {
                    Label("Note privée masquée", systemImage: "eye.slash.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if !encounter.note.isEmpty {
                    Text(encounter.note)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
            }
            .padding(.vertical, 6)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
                .padding(.top, 10)
        }
    }
}
