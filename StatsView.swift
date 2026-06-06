import SwiftUI
import Charts

struct StatsView: View {
    @EnvironmentObject var vm: EncounterViewModel
    @State private var mode: StatsMode = .global
    @State private var selectedType: EncounterType = .body
    
    enum StatsMode: String, CaseIterable {
        case global = "Global"
        case custom = "Personnalisé"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vue globale")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 10) {
                            KPICard(icon: EncounterType.body.icon, color: .themeAccent, value: "\(vm.bodyCount)", label: "Body")
                            KPICard(icon: EncounterType.preli.icon, color: .yellow, value: "\(vm.preliCount)", label: "Préli")
                            KPICard(icon: EncounterType.kiss.icon, color: .blue, value: "\(vm.kissCount)", label: "Kiss")
                        }
                        
                        Picker("Mode", selection: $mode) {
                            ForEach(StatsMode.allCases, id: \.self) { item in
                                Text(item.rawValue).tag(item)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if mode == .custom {
                            Picker("Catégorie", selection: $selectedType) {
                                ForEach(EncounterType.allCases, id: \.self) { type in
                                    Label(type.rawValue, systemImage: type.icon).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                // MARK: - KPIs
                Section {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        KPICard(icon: mode == .global ? "person.2.fill" : selectedType.icon, color: .themeAccent, value: mode == .global ? "\(vm.totalCount)" : "\(vm.count(for: selectedType))", label: mode == .global ? "Total" : selectedType.rawValue)
                        KPICard(icon: "calendar", color: .blue, value: mode == .global ? "\(vm.thisYearCount)" : "\(vm.thisYearCount(for: selectedType))", label: "Cette année")
                        KPICard(icon: "star.fill", color: .yellow, value: mode == .global ? vm.averageRatingString : vm.averageRatingString(for: selectedType), label: "Note moy.")
                        KPICard(icon: "mappin.circle.fill", color: .green, value: mode == .global ? vm.topCity : vm.topCity(for: selectedType), label: "Ville #1")
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                // MARK: - Rating Distribution
                Section(header: Text("Distribution des notes")) {
                    VStack(spacing: 10) {
                        let distribution = mode == .global ? vm.ratingDistribution : vm.ratingDistribution(for: selectedType)
                        ForEach(RatingScale.descendingValues, id: \.self) { star in
                            let count = distribution[star] ?? 0
                            let max   = distribution.values.max() ?? 1
                            HStack(spacing: 10) {
                                Text("\(RatingScale.formatted(star))★")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 42, alignment: .leading)

                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(.systemGray6))
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.yellow)
                                            .frame(width: max > 0 ? geo.size.width * CGFloat(count) / CGFloat(max) : 0)
                                    }
                                }
                                .frame(height: 10)

                                Text("\(count)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }

                // MARK: - Context breakdown
                Section(header: Text("Par contexte")) {
                    ForEach(mode == .global ? vm.contextDistribution : vm.contextDistribution(for: selectedType), id: \.0) { ctx, count in
                        HStack {
                            Image(systemName: ctx.icon)
                                .frame(width: 28)
                                .foregroundColor(.themeAccent)
                            Text(ctx.rawValue)
                                .font(.system(size: 15))
                            Spacer()
                            Text("\(count)")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Statistiques")
        }
    }
}

// MARK: - KPI Card
struct KPICard: View {
    let icon: String
    let color: Color
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.themeSurface)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.themeSilver.opacity(0.25), lineWidth: 1)
        )
        .cornerRadius(16)
    }
}
