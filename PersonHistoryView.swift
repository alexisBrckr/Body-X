import SwiftUI

struct PersonHistoryView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @Environment(\.dismiss) private var dismiss
    let personID: UUID

    private var summary: EncounterViewModel.PersonSummary? {
        vm.personSummary(for: personID)
    }

    private var history: [Encounter] {
        vm.encounters(forPersonID: personID)
    }

    var body: some View {
        NavigationStack {
            List {
                if let summary {
                    Section("Résumé") {
                        HStack {
                            Label("Rencontres", systemImage: "number")
                            Spacer()
                            Text("\(summary.encounterCount)")
                                .fontWeight(.semibold)
                        }

                        HStack {
                            Label("Période", systemImage: "calendar")
                            Spacer()
                            Text(summary.relationDurationText)
                                .fontWeight(.semibold)
                        }

                        if summary.isLongTerm {
                            Label("Relation suivie", systemImage: "heart.fill")
                                .foregroundColor(.pink)
                        } else if summary.encounterCount > 1 {
                            Label("Personne revue", systemImage: "person.2.fill")
                                .foregroundColor(.themeAccent)
                        }
                    }
                }

                Section("Historique") {
                    ForEach(history) { encounter in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(encounter.formattedDate)
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                if let type = encounter.type {
                                    Text("\(type.emoji) \(type.rawValue)")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }

                            if !encounter.city.isEmpty {
                                Text(encounter.city)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }

                            if !encounter.note.isEmpty {
                                Text(encounter.note)
                                    .font(.system(size: 13))
                                    .lineLimit(3)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .navigationTitle(summary?.displayName ?? "Historique")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Fermer") { dismiss() }
                        .foregroundColor(.themeAccent)
                }
            }
        }
    }
}
