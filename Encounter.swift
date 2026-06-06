import Foundation
import MapKit

enum Gender: String, Codable {
    case male      = "Homme"
    case female    = "Femme"
    case nonBinary = "Non-binaire"
    case other     = "Autre"
    
    static var selectableCases: [Gender] { [.male, .female] }

    var icon: String {
        switch self {
        case .male: return "♂"; case .female: return "♀"
        case .nonBinary: return "⚧"; case .other: return "?"
        }
    }
}

enum EncounterContext: String, CaseIterable, Codable {
    case app     = "App de rencontre"
    case party   = "Soirée"
    case friends = "Amis communs"
    case travel  = "Voyage"
    case work    = "Travail"
    case bar     = "Bar / Club"
    case other   = "Autre"

    var icon: String {
        switch self {
        case .app: return "iphone"
        case .party: return "music.note"
        case .friends: return "person.2.fill"
        case .travel: return "airplane"
        case .work: return "briefcase.fill"
        case .bar: return "wineglass.fill"
        case .other: return "ellipsis.circle"
        }
    }
}

enum EncounterOutcome: String, CaseIterable, Codable {
    case excellent = "Excellent"
    case good = "Bien"
    case neutral = "Moyen"
    case bad = "Pas top"

    var icon: String {
        switch self {
        case .excellent: return "sparkles"
        case .good: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle.fill"
        case .bad: return "hand.thumbsdown.fill"
        }
    }
}

enum EncounterType: String, CaseIterable, Codable {
    case body = "Bodycount"
    case preli = "Prelicount"
    case kiss = "Kisscount"

    var icon: String {
        switch self {
        case .body: return "flame.fill"
        case .kiss: return "heart.circle.fill"
        case .preli: return "sparkles"
        }
    }
    
    var emoji: String {
        switch self {
        case .body: return "🔥"
        case .kiss: return "😘"
        case .preli: return "✨"
        }
    }
}

struct Encounter: Identifiable, Codable {
    var id: UUID = UUID()
    var personId: UUID? = nil
    var firstName: String
    var age: Int? = nil
    var date: Date
    var gender: Gender?
    var context: EncounterContext?
    var city: String
    var rating: Double
    var note: String
    var pinOnMap: Bool
    var precisePlace: String = ""
    var outcome: EncounterOutcome? = nil
    var wouldMeetAgain: Bool = false
    var type: EncounterType? = .body
    var tags: [String] = []
    var greenFlags: [String] = []
    var redFlags: [String] = []
    var latitude: Double?
    var longitude: Double?
    var photoDataBase64: String = ""
    var customEmoji: String = ""
    var customEmojiBackgroundHex: String = "#C084FC"

    var initials: String {
        let parts = firstName.split(separator: " ")
        if parts.count >= 2 { return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased() }
        return String(firstName.prefix(2)).uppercased()
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var daysAgo: String {
        let d = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        if d == 0 { return "Aujourd'hui" }
        if d == 1 { return "Hier" }
        if d < 30  { return "Il y a \(d) jours" }
        if d < 365 { return "Il y a \(d/30) mois" }
        return "Il y a \(d/365) an\(d/365 > 1 ? "s" : "")"
    }

    var formattedDate: String {
        let f = DateFormatter(); f.locale = Locale(identifier: "fr_FR"); f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    var yearString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy"; return f.string(from: date)
    }

    static let samples: [Encounter] = [
        Encounter(firstName: "Léa B.", date: Calendar.current.date(byAdding: .day, value: -22, to: Date())!, gender: .female, context: .friends, city: "Paris 11e", rating: 5, note: "Super soirée chez des amis. On a vraiment bien accroché.", pinOnMap: true, type: .body, latitude: 48.860, longitude: 2.378),
        Encounter(firstName: "Jules M.", date: Calendar.current.date(byAdding: .month, value: -2, to: Date())!, gender: .male, context: .app, city: "Lyon", rating: 4, note: "Rencontre via une app, très sympa.", pinOnMap: true, type: .kiss, latitude: 45.748, longitude: 4.847),
        Encounter(firstName: "Sophie R.", date: Calendar.current.date(byAdding: .month, value: -4, to: Date())!, gender: .female, context: .bar, city: "Bordeaux", rating: 3, note: "", pinOnMap: false, type: .preli),
        Encounter(firstName: "Tom K.", date: Calendar.current.date(byAdding: .month, value: -7, to: Date())!, gender: .male, context: .party, city: "Paris 9e", rating: 5, note: "Soirée inoubliable.", pinOnMap: true, type: .body, latitude: 48.878, longitude: 2.337),
        Encounter(firstName: "Camille A.", date: Calendar.current.date(byAdding: .month, value: -9, to: Date())!, gender: .nonBinary, context: .travel, city: "Ibiza", rating: 4, note: "Vacances parfaites.", pinOnMap: true, type: .kiss, latitude: 38.908, longitude: 1.433),
    ]
}

enum RatingScale {
    static let minimum: Double = 0.5
    static let maximum: Double = 5
    static let step: Double = 0.5
    static let values: [Double] = stride(from: minimum, through: maximum, by: step).map { $0 }
    static let descendingValues: [Double] = Array(values.reversed())

    static func normalized(_ rating: Double) -> Double {
        let rounded = (rating / step).rounded() * step
        return min(max(rounded, 0), maximum)
    }

    static func formatted(_ rating: Double) -> String {
        let value = normalized(rating)
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(Int(value))
        }

        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    static func formattedAverage(_ rating: Double) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "fr_FR")
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: rating)) ?? String(format: "%.1f", rating)
    }
}
