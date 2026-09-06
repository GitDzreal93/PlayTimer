import CommonCrypto
import CryptoKit
import Foundation
import Security

final class ParentPINStore {
    private let service = "com.wenlei.PlayTimer.parent-pin"
    private let account = "parent-pin"

    private let failuresKey = "com.wenlei.PlayTimer.pin-failures"
    private let lockUntilKey = "com.wenlei.PlayTimer.pin-locked-until"

    private let maxFailuresBeforeLock = 5
    private let baseLockSeconds: TimeInterval = 60

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasPIN: Bool {
        (try? loadRecord()) != nil
    }

    // MARK: - 锁定状态

    var isLocked: Bool {
        lockRemainingSeconds > 0
    }

    var lockRemainingSeconds: TimeInterval {
        let until = defaults.double(forKey: lockUntilKey)
        guard until > 0 else { return 0 }
        return max(0, until - Date().timeIntervalSince1970)
    }

    // MARK: - 创建与验证

    func createPIN(_ pin: String) throws {
        guard Self.isValid(pin) else {
            throw PINError.invalidFormat
        }

        let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let digest = Self.pbkdf2Digest(pin: pin, salt: salt)
        let record = PINRecord(salt: salt, digest: digest, iterations: Self.pbkdf2Iterations)
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

        resetFailures()
    }

    /// 验证 PIN。连续失败会触发指数退避锁定，锁定期间直接抛错。
    func verify(_ pin: String) throws -> Bool {
        guard Self.isValid(pin) else { return false }

        if isLocked {
            throw PINError.locked(remainingSeconds: lockRemainingSeconds)
        }

        let record = try loadRecord()
        let matches = Self.pbkdf2Digest(pin: pin, salt: record.salt, iterations: record.iterations) == record.digest

        if matches {
            // 旧格式（低迭代/单次哈希）验证成功后透明升级
            if record.iterations != Self.pbkdf2Iterations {
                try? rewrap(pin: pin)
            }
            resetFailures()
            return true
        }

        registerFailure()
        return false
    }

    // MARK: - 失败计数

    private func registerFailure() {
        var failures = defaults.integer(forKey: failuresKey) + 1
        if failures >= maxFailuresBeforeLock {
            let lockSeconds = baseLockSeconds * pow(2, Double(failures - maxFailuresBeforeLock))
            let capped = min(lockSeconds, 15 * 60)
            defaults.set(Date().timeIntervalSince1970 + capped, forKey: lockUntilKey)
            failures = maxFailuresBeforeLock
        }
        defaults.set(failures, forKey: failuresKey)
    }

    private func resetFailures() {
        defaults.removeObject(forKey: failuresKey)
        defaults.removeObject(forKey: lockUntilKey)
    }

    private func rewrap(pin: String) throws {
        guard Self.isValid(pin) else { return }
        let salt = SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
        let record = PINRecord(
            salt: salt,
            digest: Self.pbkdf2Digest(pin: pin, salt: salt),
            iterations: Self.pbkdf2Iterations
        )
        let data = try JSONEncoder().encode(record)

        try deleteExisting()
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        query[kSecValueData as String] = data
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw PINError.keychainStatus(status)
        }
    }

    // MARK: - Keychain 存取

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

        // 新格式：含 iterations；旧格式缺省为 1 次 SHA256 迭代（见 legacyDigest）
        if let record = try? JSONDecoder().decode(PINRecord.self, from: data), record.iterations > 1 {
            return record
        }
        if let legacy = try? JSONDecoder().decode(LegacyPINRecord.self, from: data) {
            return PINRecord(salt: legacy.salt, digest: legacy.digest, iterations: 1)
        }
        throw PINError.corruptRecord
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

    // MARK: - 哈希

    private static let pbkdf2Iterations = 210_000

    private static func isValid(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy(\.isNumber)
    }

    /// PBKDF2-SHA256。iterations == 1 时等价于单次 SHA256，兼容旧记录。
    private static func pbkdf2Digest(pin: String, salt: Data, iterations: Int = pbkdf2Iterations) -> Data {
        let passwordData = Data(pin.utf8)
        var derived = Data(repeating: 0, count: 32)

        let result = derived.withUnsafeMutableBytes { derivedBytes in
            salt.withUnsafeBytes { saltBytes in
                CCKeyDerivationPBKDF(
                    CCPBKDFAlgorithm(kCCPBKDF2),
                    passwordData.map { CChar(bitPattern: $0) },
                    passwordData.count,
                    saltBytes.bindMemory(to: UInt8.self).baseAddress,
                    salt.count,
                    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                    UInt32(iterations),
                    derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                    32
                )
            }
        }

        guard result == kCCSuccess else {
            // PBKDF2 失败时退回单次 SHA256（不应发生，保底可验证）
            return legacyDigest(pin: pin, salt: salt)
        }
        return derived
    }

    private static func legacyDigest(pin: String, salt: Data) -> Data {
        var input = Data(pin.utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }
}

private struct PINRecord: Codable {
    var salt: Data
    var digest: Data
    var iterations: Int

    init(salt: Data, digest: Data, iterations: Int) {
        self.salt = salt
        self.digest = digest
        self.iterations = iterations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        salt = try container.decode(Data.self, forKey: .salt)
        digest = try container.decode(Data.self, forKey: .digest)
        iterations = try container.decodeIfPresent(Int.self, forKey: .iterations) ?? 1
    }
}

private struct LegacyPINRecord: Codable {
    var salt: Data
    var digest: Data
}

enum PINError: LocalizedError {
    case invalidFormat
    case corruptRecord
    case keychainStatus(OSStatus)
    case locked(remainingSeconds: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "家长 PIN 需要是 4 到 6 位数字。"
        case .corruptRecord:
            return "家长 PIN 数据无法读取，请重新设置。"
        case .keychainStatus(let status):
            return "Keychain 操作失败：\(status)"
        case .locked(let remainingSeconds):
            let minutes = Int(remainingSeconds) / 60
            let seconds = Int(remainingSeconds) % 60
            return minutes > 0
                ? "失败次数过多，请 \(minutes) 分 \(seconds) 秒后再试。"
                : "失败次数过多，请 \(seconds) 秒后再试。"
        }
    }
}
