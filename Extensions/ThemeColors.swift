import SwiftUI
import UIKit

private enum AppTheme: String {
    case light
    case sombre
    case dark

    static var current: AppTheme {
        let raw = UserDefaults.standard.string(forKey: "settings.theme") ?? "sombre"
        return AppTheme(rawValue: raw) ?? .sombre
    }
}

extension Int {
    var starsString: String { String(repeating: "★", count: self) + String(repeating: "☆", count: 5 - self) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (192, 132, 252)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }

    func toHexString() -> String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return String(
            format: "#%02lX%02lX%02lX",
            lroundf(Float(red * 255)),
            lroundf(Float(green * 255)),
            lroundf(Float(blue * 255))
        )
    }
}
extension Color {
    static let themeBlack = Color(
        UIColor { _ in
            switch AppTheme.current {
            case .light:
                return UIColor(red: 0.96, green: 0.96, blue: 0.98, alpha: 1)
            case .sombre:
                return UIColor(red: 0.05, green: 0.05, blue: 0.07, alpha: 1)
            case .dark:
                return UIColor(red: 0.07, green: 0.09, blue: 0.11, alpha: 1)
            }
        }
    )
    static let themeSurface = Color(
        UIColor { _ in
            switch AppTheme.current {
            case .light:
                return UIColor.white
            case .sombre:
                return UIColor(red: 0.11, green: 0.11, blue: 0.14, alpha: 1)
            case .dark:
                return UIColor(red: 0.10, green: 0.13, blue: 0.16, alpha: 1)
            }
        }
    )
    static let themeSilver = Color(
        UIColor { _ in
            switch AppTheme.current {
            case .light:
                return UIColor(red: 0.32, green: 0.33, blue: 0.38, alpha: 1)
            case .sombre:
                return UIColor(red: 0.78, green: 0.79, blue: 0.83, alpha: 1)
            case .dark:
                return UIColor(red: 0.70, green: 0.76, blue: 0.80, alpha: 1)
            }
        }
    )
    static let themeViolet = Color(red: 0.58, green: 0.41, blue: 0.95)
    static let themePink = Color(red: 0.96, green: 0.38, blue: 0.63)
    static let themeAccent = Color(
        UIColor { _ in
            switch AppTheme.current {
            case .light:
                return UIColor(red: 0.96, green: 0.38, blue: 0.63, alpha: 1)
            case .sombre:
                return UIColor(red: 0.58, green: 0.41, blue: 0.95, alpha: 1)
            case .dark:
                return UIColor(red: 0.24, green: 0.84, blue: 0.71, alpha: 1)
            }
        }
    )

    static let genderFemale = Color(red: 0.99, green: 0.89, blue: 0.93)
    static let genderMale   = Color(red: 0.91, green: 0.91, blue: 0.97)
    static let genderNB     = Color(red: 0.88, green: 0.95, blue: 0.94)
    static let genderOther  = Color(red: 1.00, green: 0.95, blue: 0.88)

    static func avatarBG(for gender: Gender?) -> Color {
        switch gender {
        case .female: return .genderFemale; case .male: return .genderMale
        case .nonBinary: return .genderNB; default: return .genderOther
        }
    }
    static func avatarFG(for gender: Gender?) -> Color {
        switch gender {
        case .female: return Color(red: 0.76, green: 0.09, blue: 0.34)
        case .male: return Color(red: 0.22, green: 0.28, blue: 0.67)
        case .nonBinary: return Color(red: 0.00, green: 0.47, blue: 0.42)
        default: return Color(red: 0.90, green: 0.32, blue: 0.11)
        }
    }
}
