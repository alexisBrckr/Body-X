import SwiftUI

struct EncounterRowView: View {
    @AppStorage("settings.privacyMode") private var privacyMode = false

    let encounter: Encounter

    private var displayName: String {
        privacyMode ? L10n.text("Personne masquée", "Hidden person") : encounter.firstName
    }

    private var cityText: String {
        privacyMode ? L10n.text("Lieu masqué", "Hidden location") : encounter.city
    }

    var body: some View {
        HStack(spacing: 14) {
            AvatarView(
                initials: encounter.initials,
                gender: encounter.gender,
                encounterType: encounter.type ?? .body,
                photoDataBase64: encounter.photoDataBase64,
                customEmoji: encounter.customEmoji,
                customEmojiBackgroundHex: encounter.customEmojiBackgroundHex,
                size: 52
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(displayName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Text(encounter.formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    if !encounter.city.isEmpty {
                        Text("·")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(cityText)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }

                if encounter.rating > 0 {
                    StarRatingView(rating: encounter.rating, size: 12)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(.systemGray3))
        }
        .padding(.vertical, 6)
    }
}
