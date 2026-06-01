import Foundation

enum InputSanitizer {
    static func cleanSingleLine(_ raw: String, maxLength: Int = 120) -> String {
        let noControl = raw.replacingOccurrences(of: "[\\p{Cc}\\p{Cf}]", with: "", options: .regularExpression)
        let collapsed = noControl
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return String(collapsed.prefix(maxLength))
    }

    static func cleanMultiLine(_ raw: String, maxLength: Int = 2000) -> String {
        // Keep user-entered spaces/newlines while removing unsafe control chars.
        let normalizedNewlines = raw
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let noControl = normalizedNewlines.replacingOccurrences(
            of: "[\\p{Cc}&&[^\\n\\t]]",
            with: "",
            options: .regularExpression
        )
        return String(noControl.prefix(maxLength))
    }

    static func cleanEmoji(_ raw: String) -> String {
        let cleaned = cleanSingleLine(raw, maxLength: 8)
        return String(cleaned.prefix(2))
    }
}
