import CryptoKit
import Foundation
import Security

final class ParentPINStore {
    private let service = "com.wenlei.PlayTimer.parent-pin"
    private let account = "parent-pin"

    var hasPIN: Bool {
        (try? loadRecord()) != nil
    }

    var recoveryQuestionPrompts: [String] {
        (try? loadRecord().recoveryQuestions?.map(\.prompt)) ?? []
    }

    var hasRecoveryQuestions: Bool {
        !recoveryQuestionPrompts.isEmpty
    }

    func createPIN(_ pin: String, questionsAndAnswers: [(question: String, answer: String)]) throws {
        guard Self.isValid(pin) else { throw PINError.invalidFormat }
        let challenges = try Self.makeChallenges(questionsAndAnswers)
        let salt = Self.randomSalt()
        try saveRecord(PINRecord(
            salt: salt,
            digest: Self.digest(pin: pin, salt: salt),
            recoveryQuestions: challenges
        ))
    }

    func configureRecoveryQuestions(_ questionsAndAnswers: [(question: String, answer: String)]) throws {
        let challenges = try Self.makeChallenges(questionsAndAnswers)
        var record = try loadRecord()
        record.recoveryQuestions = challenges
        record.failedRecoveryAttempts = 0
        record.recoveryLockedUntil = nil
        try saveRecord(record)
    }

    func resetPIN(_ pin: String) throws {
        guard Self.isValid(pin) else { throw PINError.invalidFormat }
        var record = try loadRecord()
        let salt = Self.randomSalt()
        record.salt = salt
        record.digest = Self.digest(pin: pin, salt: salt)
        record.failedRecoveryAttempts = 0
        record.recoveryLockedUntil = nil
        try saveRecord(record)
    }

    func resetPINAndConfigureRecovery(
        _ pin: String,
        questionsAndAnswers: [(question: String, answer: String)]
    ) throws {
        guard Self.isValid(pin) else { throw PINError.invalidFormat }
        let challenges = try Self.makeChallenges(questionsAndAnswers)
        var record = try loadRecord()
        let salt = Self.randomSalt()
        record.salt = salt
        record.digest = Self.digest(pin: pin, salt: salt)
        record.recoveryQuestions = challenges
        record.failedRecoveryAttempts = 0
        record.recoveryLockedUntil = nil
        try saveRecord(record)
    }

    func verifyRecoveryAnswers(_ answers: [String], now: Date = .now) throws -> RecoveryAnswerResult {
        var record = try loadRecord()
        guard let challenges = record.recoveryQuestions, !challenges.isEmpty else {
            return .notConfigured
        }
        if let lockedUntil = record.recoveryLockedUntil, lockedUntil > now {
            return .cooldown(seconds: Int(ceil(lockedUntil.timeIntervalSince(now))))
        }
        guard answers.count == challenges.count else { return .incorrect }

        let answersMatch = zip(challenges, answers).allSatisfy { challenge, answer in
            Self.digest(answer: answer, salt: challenge.salt) == challenge.digest
        }
        if answersMatch {
            record.failedRecoveryAttempts = 0
            record.recoveryLockedUntil = nil
            try saveRecord(record)
            return .verified
        }

        record.failedRecoveryAttempts += 1
        if record.failedRecoveryAttempts >= 5 {
            record.failedRecoveryAttempts = 0
            record.recoveryLockedUntil = now.addingTimeInterval(5 * 60)
            try saveRecord(record)
            return .cooldown(seconds: 5 * 60)
        }
        try saveRecord(record)
        return .incorrect
    }

    func verify(_ pin: String) throws -> Bool {
        guard Self.isValid(pin) else { return false }
        let record = try loadRecord()
        return Self.digest(pin: pin, salt: record.salt) == record.digest
    }

    private func saveRecord(_ record: PINRecord) throws {
        let data = try JSONEncoder().encode(record)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { throw PINError.keychainStatus(updateStatus) }

        var addQuery = query
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else { throw PINError.keychainStatus(status) }
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
        guard status == errSecSuccess else { throw PINError.keychainStatus(status) }
        guard let data = item as? Data else { throw PINError.corruptRecord }
        return try JSONDecoder().decode(PINRecord.self, from: data)
    }

    private static func makeChallenges(_ input: [(question: String, answer: String)]) throws -> [RecoveryChallenge] {
        guard input.count == 1 || input.count == 2,
              input.allSatisfy({
                  !$0.question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                      !normalizedAnswer($0.answer).isEmpty
              }),
              input.count == 1 || normalizedAnswer(input[0].answer) != normalizedAnswer(input[1].answer) else {
            throw PINError.invalidRecoveryQuestions
        }

        return input.map { item in
            let salt = randomSalt()
            return RecoveryChallenge(
                prompt: item.question.trimmingCharacters(in: .whitespacesAndNewlines),
                salt: salt,
                digest: digest(answer: item.answer, salt: salt)
            )
        }
    }

    private static func isValid(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy(\.isNumber)
    }

    private static func randomSalt() -> Data {
        SymmetricKey(size: .bits256).withUnsafeBytes { Data($0) }
    }

    private static func digest(pin: String, salt: Data) -> Data {
        var input = Data(pin.utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }

    private static func digest(answer: String, salt: Data) -> Data {
        var input = Data(normalizedAnswer(answer).utf8)
        input.append(salt)
        return Data(SHA256.hash(data: input))
    }

    private static func normalizedAnswer(_ answer: String) -> String {
        answer
            .precomposedStringWithCanonicalMapping
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}

private struct PINRecord: Codable {
    var salt: Data
    var digest: Data
    var recoveryQuestions: [RecoveryChallenge]?
    var failedRecoveryAttempts: Int
    var recoveryLockedUntil: Date?

    private enum CodingKeys: String, CodingKey {
        case salt, digest, recoveryQuestions, failedRecoveryAttempts, recoveryLockedUntil
    }

    init(salt: Data, digest: Data, recoveryQuestions: [RecoveryChallenge]? = nil, failedRecoveryAttempts: Int = 0, recoveryLockedUntil: Date? = nil) {
        self.salt = salt
        self.digest = digest
        self.recoveryQuestions = recoveryQuestions
        self.failedRecoveryAttempts = failedRecoveryAttempts
        self.recoveryLockedUntil = recoveryLockedUntil
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        salt = try values.decode(Data.self, forKey: .salt)
        digest = try values.decode(Data.self, forKey: .digest)
        recoveryQuestions = try values.decodeIfPresent([RecoveryChallenge].self, forKey: .recoveryQuestions)
        failedRecoveryAttempts = try values.decodeIfPresent(Int.self, forKey: .failedRecoveryAttempts) ?? 0
        recoveryLockedUntil = try values.decodeIfPresent(Date.self, forKey: .recoveryLockedUntil)
    }
}

private struct RecoveryChallenge: Codable {
    var prompt: String
    var salt: Data
    var digest: Data
}

enum RecoveryAnswerResult: Equatable {
    case verified
    case incorrect
    case cooldown(seconds: Int)
    case notConfigured
}

enum PINError: LocalizedError {
    case invalidFormat
    case invalidRecoveryQuestions
    case corruptRecord
    case keychainStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            "家长 PIN 需要是 4 到 6 位数字。"
        case .invalidRecoveryQuestions:
            "请选择找回问题并填写答案。"
        case .corruptRecord:
            "家长 PIN 数据无法读取，请重新设置。"
        case .keychainStatus(let status):
            "Keychain 操作失败：\(status)"
        }
    }
}
