import Foundation
import Combine

class EncounterViewModel: ObservableObject {
    enum SortOption: CaseIterable {
        case none
        case alphabetical
        case kiss
        case preli
        case body
        
        var label: String {
            switch self {
            case .none: return "Par défaut"
            case .alphabetical: return "Ordre alphabétique"
            case .kiss: return "Kiss"
            case .preli: return "Préli"
            case .body: return "Body"
            }
        }
    }

    @Published var encounters: [Encounter] = []
    @Published var searchQuery: String = ""
    @Published var selectedYear: String = "Tous"
    @Published var sortOption: SortOption = .none
    private let saveKey = "bodyx_encounters"
    private let sampleSeedKey = "bodyx_sample_data_seeded"
    private let secureStorage = SecureStorage()
    private let rateLimiter = RateLimiter()

    init() {
        load()
        if encounters.isEmpty && !UserDefaults.standard.bool(forKey: sampleSeedKey) {
            encounters = Encounter.samples
            UserDefaults.standard.set(true, forKey: sampleSeedKey)
        } else if !encounters.isEmpty {
            UserDefaults.standard.set(true, forKey: sampleSeedKey)
        }
        if assignMissingPersonIDs() {
            save()
        }
    }
    
    struct PersonSummary: Identifiable {
        let id: UUID
        let displayName: String
        let firstDate: Date
        let lastDate: Date
        let encounterCount: Int
        
        var relationDurationText: String {
            let months = max(1, Calendar.current.dateComponents([.month], from: firstDate, to: lastDate).month ?? 0)
            if months < 12 { return "\(months) mois" }
            let years = months / 12
            let remainingMonths = months % 12
            if remainingMonths == 0 { return "\(years) an\(years > 1 ? "s" : "")" }
            return "\(years) an\(years > 1 ? "s" : "") \(remainingMonths) mois"
        }
        
        var isLongTerm: Bool {
            (Calendar.current.dateComponents([.month], from: firstDate, to: lastDate).month ?? 0) >= 2
        }
    }
    
    struct AlphabeticalPersonGroup: Identifiable {
        let id: UUID
        let displayName: String
        let encounters: [Encounter]
    }

    var availableYears: [String] {
        ["Tous"] + Set(encounters.map { $0.yearString }).sorted(by: >)
    }

    var filteredEncounters: [Encounter] {
        let filtered = encounters.filter { e in
            (searchQuery.isEmpty || e.firstName.localizedCaseInsensitiveContains(searchQuery)) &&
            (selectedYear == "Tous" || e.yearString == selectedYear)
        }
        return sort(filtered, by: sortOption)
    }

    var groupedByYear: [(String, [Encounter])] {
        let g = Dictionary(grouping: filteredEncounters) { $0.yearString }
        return g.keys.sorted(by: >).map { ($0, g[$0]!) }
    }
    
    var personSummaries: [PersonSummary] {
        let grouped = Dictionary(grouping: encounters) { $0.personId }
        return grouped.compactMap { personId, list in
            guard let personId else { return nil }
            let sorted = list.sorted { $0.date < $1.date }
            guard let first = sorted.first, let last = sorted.last else { return nil }
            return PersonSummary(
                id: personId,
                displayName: displayName(for: sorted),
                firstDate: first.date,
                lastDate: last.date,
                encounterCount: sorted.count
            )
        }
        .sorted { $0.lastDate > $1.lastDate }
    }
    
    var alphabeticalPersonGroups: [AlphabeticalPersonGroup] {
        let filtered = encounters.filter { e in
            (searchQuery.isEmpty || e.firstName.localizedCaseInsensitiveContains(searchQuery)) &&
            (selectedYear == "Tous" || e.yearString == selectedYear)
        }
        let grouped = Dictionary(grouping: filtered) { $0.personId }
        return grouped.compactMap { personId, list in
            guard let personId else { return nil }
            let sorted = list.sorted { $0.date > $1.date }
            guard !sorted.isEmpty else { return nil }
            return AlphabeticalPersonGroup(
                id: personId,
                displayName: displayName(for: sorted),
                encounters: sorted
            )
        }
        .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    private func sort(_ list: [Encounter], by option: SortOption) -> [Encounter] {
        switch option {
        case .none:
            return list.sorted { $0.date > $1.date }
        case .alphabetical:
            return list.sorted { $0.firstName.localizedCaseInsensitiveCompare($1.firstName) == .orderedAscending }
        case .kiss:
            return list
                .filter { ($0.type ?? .body) == .kiss }
                .sorted { $0.date > $1.date }
        case .preli:
            return list
                .filter { ($0.type ?? .body) == .preli }
                .sorted { $0.date > $1.date }
        case .body:
            return list
                .filter { ($0.type ?? .body) == .body }
                .sorted { $0.date > $1.date }
        }
    }

    var mappableEncounters: [Encounter] { encounters.filter { $0.pinOnMap && $0.coordinate != nil } }
    var totalCount: Int { encounters.count }
    var bodyCount: Int { count(for: .body) }
    var kissCount: Int { count(for: .kiss) }
    var preliCount: Int { count(for: .preli) }
    var thisYearCount: Int {
        let y = Calendar.current.component(.year, from: Date())
        return encounters.filter { Calendar.current.component(.year, from: $0.date) == y }.count
    }
    var averageRating: Double {
        let r = encounters.filter { $0.rating > 0 }
        guard !r.isEmpty else { return 0 }
        return r.map(\.rating).reduce(0, +) / Double(r.count)
    }
    var averageRatingString: String { averageRating > 0 ? RatingScale.formattedAverage(averageRating) : "—" }
    var topCity: String {
        let freq = Dictionary(grouping: encounters.map(\.city)) { $0 }.mapValues(\.count)
        return freq.max(by: { $0.value < $1.value })?.key ?? "—"
    }
    var ratingDistribution: [Double: Int] {
        var d = Dictionary(uniqueKeysWithValues: RatingScale.values.map { ($0, 0) })
        encounters.filter { $0.rating > 0 }.forEach { d[RatingScale.normalized($0.rating), default: 0] += 1 }
        return d
    }
    var contextDistribution: [(EncounterContext, Int)] {
        Dictionary(grouping: encounters.compactMap(\.context)) { $0 }
            .map { ($0.key, $0.value.count) }.sorted { $0.1 > $1.1 }
    }
    
    struct MonthlyPoint: Identifiable {
        let id = UUID()
        let month: Date
        let type: EncounterType
        let count: Int
    }
    
    struct ComparisonSummary {
        let current: Int
        let previous: Int
        var delta: Int { current - previous }
        var deltaPercent: Double {
            guard previous > 0 else { return current > 0 ? 100 : 0 }
            return (Double(delta) / Double(previous)) * 100
        }
    }
    
    func count(for type: EncounterType) -> Int {
        encounters.filter { ($0.type ?? .body) == type }.count
    }
    
    func thisYearCount(for type: EncounterType) -> Int {
        let y = Calendar.current.component(.year, from: Date())
        return encounters.filter {
            ($0.type ?? .body) == type &&
            Calendar.current.component(.year, from: $0.date) == y
        }.count
    }
    
    func averageRatingString(for type: EncounterType) -> String {
        let rated = encounters.filter { ($0.type ?? .body) == type && $0.rating > 0 }
        guard !rated.isEmpty else { return "—" }
        let avg = rated.map(\.rating).reduce(0, +) / Double(rated.count)
        return RatingScale.formattedAverage(avg)
    }
    
    func topCity(for type: EncounterType) -> String {
        let cities = encounters.filter { ($0.type ?? .body) == type }.map(\.city).filter { !$0.isEmpty }
        let freq = Dictionary(grouping: cities) { $0 }.mapValues(\.count)
        return freq.max(by: { $0.value < $1.value })?.key ?? "—"
    }
    
    func ratingDistribution(for type: EncounterType) -> [Double: Int] {
        var d = Dictionary(uniqueKeysWithValues: RatingScale.values.map { ($0, 0) })
        encounters
            .filter { ($0.type ?? .body) == type && $0.rating > 0 }
            .forEach { d[RatingScale.normalized($0.rating), default: 0] += 1 }
        return d
    }
    
    func contextDistribution(for type: EncounterType) -> [(EncounterContext, Int)] {
        Dictionary(grouping: encounters.filter { ($0.type ?? .body) == type }.compactMap(\.context)) { $0 }
            .map { ($0.key, $0.value.count) }
            .sorted { $0.1 > $1.1 }
    }
    
    func monthlySeries(lastMonths: Int = 6) -> [MonthlyPoint] {
        let calendar = Calendar.current
        let now = Date()
        let months: [Date] = (0..<lastMonths).compactMap { offset in
            calendar.date(byAdding: .month, value: -(lastMonths - 1 - offset), to: now)
        }.map { date in
            let c = calendar.dateComponents([.year, .month], from: date)
            return calendar.date(from: c) ?? date
        }
        
        var result: [MonthlyPoint] = []
        for monthDate in months {
            let comp = calendar.dateComponents([.year, .month], from: monthDate)
            for type in EncounterType.allCases {
                let count = encounters.filter { encounter in
                    let eComp = calendar.dateComponents([.year, .month], from: encounter.date)
                    return eComp.year == comp.year &&
                        eComp.month == comp.month &&
                        (encounter.type ?? .body) == type
                }.count
                result.append(MonthlyPoint(month: monthDate, type: type, count: count))
            }
        }
        return result
    }
    
    func monthlyComparison(for type: EncounterType, referenceDate: Date = Date()) -> ComparisonSummary {
        let calendar = Calendar.current
        let currentComp = calendar.dateComponents([.year, .month], from: referenceDate)
        let previousDate = calendar.date(byAdding: .month, value: -1, to: referenceDate) ?? referenceDate
        let previousComp = calendar.dateComponents([.year, .month], from: previousDate)
        
        let current = encounters.filter { e in
            let c = calendar.dateComponents([.year, .month], from: e.date)
            return c.year == currentComp.year &&
                c.month == currentComp.month &&
                (e.type ?? .body) == type
        }.count
        let previous = encounters.filter { e in
            let c = calendar.dateComponents([.year, .month], from: e.date)
            return c.year == previousComp.year &&
                c.month == previousComp.month &&
                (e.type ?? .body) == type
        }.count
        
        return ComparisonSummary(current: current, previous: previous)
    }

    func add(_ e: Encounter) {
        guard rateLimiter.allows("encounter.add", interval: 0.6) else { return }
        encounters.insert(e, at: 0)
        save()
    }

    func update(_ e: Encounter) {
        guard rateLimiter.allows("encounter.update", interval: 0.4) else { return }
        if let i = encounters.firstIndex(where: { $0.id == e.id }) { encounters[i] = e; save() }
    }

    func delete(_ e: Encounter) {
        guard rateLimiter.allows("encounter.delete", interval: 0.25) else { return }
        encounters.removeAll { $0.id == e.id }
        save()
    }

    func delete(at offsets: IndexSet, in list: [Encounter]) {
        guard rateLimiter.allows("encounter.deleteBatch", interval: 0.25) else { return }
        let ids = offsets.map { list[$0].id }
        encounters.removeAll { ids.contains($0.id) }
        save()
    }
    
    func clearAll() {
        guard rateLimiter.allows("encounter.clearAll", interval: 1.5) else { return }
        searchQuery = ""
        selectedYear = "Tous"
        sortOption = .none
        encounters = []
        UserDefaults.standard.set(true, forKey: sampleSeedKey)
        save()
    }
    
    func encounters(forPersonID personID: UUID) -> [Encounter] {
        encounters
            .filter { $0.personId == personID }
            .sorted { $0.date > $1.date }
    }
    
    func personSummary(for personID: UUID) -> PersonSummary? {
        personSummaries.first { $0.id == personID }
    }
    
    func latestEncounter(for personID: UUID) -> Encounter? {
        encounters(forPersonID: personID).first
    }

    private func save() {
        try? secureStorage.save(encounters)
    }

    private func load() {
        if let secure: [Encounter] = try? secureStorage.load([Encounter].self) {
            encounters = secure
            return
        }
        // One-time fallback migration from old UserDefaults storage.
        if let d = UserDefaults.standard.data(forKey: saveKey),
           let dec = try? JSONDecoder().decode([Encounter].self, from: d) {
            encounters = dec
            try? secureStorage.save(dec)
            UserDefaults.standard.removeObject(forKey: saveKey)
        }
    }
    
    @discardableResult
    private func assignMissingPersonIDs() -> Bool {
        var didUpdate = false
        var nameToPersonID: [String: UUID] = [:]
        
        for index in encounters.indices {
            if let personId = encounters[index].personId {
                let key = normalizedName(encounters[index].firstName)
                if !key.isEmpty && nameToPersonID[key] == nil {
                    nameToPersonID[key] = personId
                }
                continue
            }
            
            let key = normalizedName(encounters[index].firstName)
            let resolvedID: UUID
            if let existingID = nameToPersonID[key], !key.isEmpty {
                resolvedID = existingID
            } else {
                resolvedID = UUID()
                if !key.isEmpty {
                    nameToPersonID[key] = resolvedID
                }
            }
            encounters[index].personId = resolvedID
            didUpdate = true
        }
        return didUpdate
    }
    
    private func normalizedName(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }
    
    private func displayName(for encounters: [Encounter]) -> String {
        encounters
            .map(\.firstName)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .max(by: { $0.count < $1.count }) ?? "Inconnu"
    }
}
