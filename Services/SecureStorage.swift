import Foundation
import Security
import CryptoKit

enum SecureStorageError: Error {
    case keychain(OSStatus)
    case crypto
    case io
}

final class SecureStorage {
    private let service = "com.bodyx.secure"
    private let account = "encounters.key"
    private let fileName = "encounters.secure"

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent(fileName)
    }

    func save<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let key = try fetchOrCreateKey()
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else { throw SecureStorageError.crypto }
        do {
            try combined.write(to: fileURL, options: .atomic)
        } catch {
            throw SecureStorageError.io
        }
    }

    func load<T: Decodable>(_ type: T.Type) throws -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let encrypted = try Data(contentsOf: fileURL)
        let key = try fetchOrCreateKey()
        let box = try AES.GCM.SealedBox(combined: encrypted)
        let data = try AES.GCM.open(box, using: key)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private func fetchOrCreateKey() throws -> SymmetricKey {
        if let data = try readKeyData() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        try storeKeyData(data)
        return key
    }

    private func readKeyData() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw SecureStorageError.keychain(status) }
        return item as? Data
    }

    private func storeKeyData(_ data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw SecureStorageError.keychain(status) }
    }
}

enum AppPasscodeStoreError: Error {
    case invalidPasscode
    case keychain(OSStatus)
    case decoding
}

enum AppPasscodeStore {
    static let minimumLength = 4
    static let maximumLength = 6

    private static let service = "com.bodyx.secure"
    private static let account = "app.passcode"

    static var hasPasscode: Bool {
        (try? readRecord()) != nil
    }

    static func normalized(_ value: String) -> String {
        String(value.filter(\.isNumber).prefix(maximumLength))
    }

    static func set(_ passcode: String) throws {
        let passcode = normalized(passcode)
        guard passcode.count >= minimumLength else { throw AppPasscodeStoreError.invalidPasscode }

        let salt = UUID().uuidString
        let record = AppPasscodeRecord(
            salt: salt,
            hash: hash(passcode: passcode, salt: salt)
        )
        let data = try JSONEncoder().encode(record)

        var query = baseQuery
        SecItemDelete(query as CFDictionary)
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw AppPasscodeStoreError.keychain(status) }
    }

    static func validate(_ passcode: String) -> Bool {
        guard let record = try? readRecord() else { return false }
        return hash(passcode: normalized(passcode), salt: record.salt) == record.hash
    }

    static func clear() {
        SecItemDelete(baseQuery as CFDictionary)
    }

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private static func readRecord() throws -> AppPasscodeRecord? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw AppPasscodeStoreError.keychain(status) }
        guard let data = item as? Data else { throw AppPasscodeStoreError.decoding }

        return try JSONDecoder().decode(AppPasscodeRecord.self, from: data)
    }

    private static func hash(passcode: String, salt: String) -> String {
        let data = Data("\(salt):\(passcode)".utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

private struct AppPasscodeRecord: Codable {
    let salt: String
    let hash: String
}
