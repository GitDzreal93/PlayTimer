import CryptoKit
import Foundation
import Security

final class ParentPINStore {
    private let service = "com.wenlei.PlayTimer.parent-pin"
    private let account = "parent-pin"

    var hasPIN: Bool {
        (try? loadRecord()) != nil
    }

    func createPIN(_ pin: String) throws {
        guard Self.isValid(pin) else {
            throw PINError.invalidFormat
        }

        let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let digest = Self.digest(pin: pin, salt: salt)
        let record = PINRecord(salt: salt, digest: digest)
        let data = try JSONEncoder().encode(record)

        try deleteExisting()
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PINError.keychainStatus(status)
        }
    }

    func verify(_ pin: String) throws -> Bool {
        guard Self.isValid(pin) else { return false }
        let record = try loadRecord()
        return Self.digest(pin: pin, salt: record.salt) == record.digest
    }

    private func loadRecord() throws -> PINRecord {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw PINError.keychainStatus(status)
        }
        guard let data = item as? Data else {
            throw PINError.corruptRecord
        }
        return try JSONDecoder().decode(PINRecord.self, from: data)
    }

    private func deleteExisting() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw PINError.keychainStatus(status)
        }
    }

    private static func isValid(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy(\.isNumber)
    }

    private static func digest(pin: String, salt: Data) -> Data {
        var input = Data(pin.utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }
}

private struct PINRecord: Codable {
    var salt: Data
    var digest: Data
}

enum PINError: LocalizedError {
    case invalidFormat
    case corruptRecord
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "家长 PIN 需要是 4 到 6 位数字。"
        case .corruptRecord:
            "家长 PIN 数据无法读取，请重新设置。"
        case .keychainStatus(let status):
            "Keychain 操作失败：\(status)"
        }
    }
}
