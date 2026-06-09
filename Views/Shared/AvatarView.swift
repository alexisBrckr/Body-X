import SwiftUI

struct AvatarView: View {
    @AppStorage("settings.privacyMode") private var privacyMode = false

    let initials: String
    let gender: Gender?
    var encounterType: EncounterType? = nil
    var photoDataBase64: String = ""
    var customEmoji: String = ""
    var customEmojiBackgroundHex: String = "#C084FC"
    var size: CGFloat = 40
    var respectsPrivacyMode: Bool = true

    private var uiImage: UIImage? {
        guard let data = Data(base64Encoded: photoDataBase64), !photoDataBase64.isEmpty else { return nil }
        return UIImage(data: data)
    }

    private var shouldMaskIdentity: Bool {
        privacyMode && respectsPrivacyMode
    }

    var body: some View {
        ZStack {
            if shouldMaskIdentity {
                Circle().fill(Color.themeSurface)
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundColor(.themeAccent)
            } else if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else if !customEmoji.isEmpty {
                Circle().fill(Color(hex: customEmojiBackgroundHex))
                Text(customEmoji)
                    .font(.system(size: size * 0.42))
            } else {
                Circle().fill(Color.avatarBG(for: gender))
                Text(initials)
                    .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                    .foregroundColor(Color.avatarFG(for: gender))
            }
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let encounterType, !shouldMaskIdentity {
                Text(encounterType.emoji)
                    .font(.system(size: max(10, size * 0.28)))
                    .padding(3)
                    .background(Circle().fill(Color.themeBlack))
                    .overlay(Circle().stroke(Color.themeSilver.opacity(0.35), lineWidth: 1))
                    .offset(x: 2, y: 2)
            }
        }
    }
}
