import FamilyControls
import Foundation

final class SharedStateStore {
    static let shared = SharedStateStore()

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSession() -> PlaySession? {
        read(PlaySession.self, filename: AppConstants.sessionFilename)?.refreshed()
    }

    func saveSession(_ session: PlaySession?) throws {
        if let session {
            try write(session, filename: AppConstants.sessionFilename)
        } else {
            try remove(filename: AppConstants.sessionFilename)
        }
    }

    func updateSession(_ update: (inout PlaySession) -> Void) throws {
        guard var session = loadSession() else { return }
        update(&session)
        session.lastUpdatedAt = Date()
        try saveSession(session)
    }

    func loadSettings() -> UserSettings {
        read(UserSettings.self, filename: AppConstants.settingsFilename) ?? .defaults
    }

    func saveSettings(_ settings: UserSettings) throws {
        try write(settings, filename: AppConstants.settingsFilename)
    }

    func loadAllowedAppSelection() -> FamilyActivitySelection {
        read(FamilyActivitySelection.self, filename: AppConstants.allowedAppsFilename) ?? FamilyActivitySelection()
    }

    func saveAllowedAppSelection(_ selection: FamilyActivitySelection) throws {
        try write(selection.sanitizedForAllowedApps(), filename: AppConstants.allowedAppsFilename)
    }

    func loadAllowedAppCollections() -> [AllowedAppCollection] {
        if let collections = read([AllowedAppCollection].self, filename: AppConstants.allowedAppCollectionsFilename) {
            return collections
        }

        let legacySelection = loadAllowedAppSelection()
        guard !legacySelection.applicationTokens.isEmpty else { return [] }
        return [AllowedAppCollection.make(name: "默认合集", selection: legacySelection)]
    }

    func saveAllowedAppCollections(_ collections: [AllowedAppCollection]) throws {
        try write(collections, filename: AppConstants.allowedAppCollectionsFilename)
    }

    private func read<T: Decodable>(_ type: T.Type, filename: String) -> T? {
        guard let url = fileURL(filename: filename) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(type, from: data)
        } catch {
            return nil
        }
    }

    private func write<T: Encodable>(_ value: T, filename: String) throws {
        guard let url = fileURL(filename: filename) else {
            throw SharedStateError.missingAppGroupContainer
        }

        let data = try encoder.encode(value)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
    }

    private func remove(filename: String) throws {
        guard let url = fileURL(filename: filename) else {
            throw SharedStateError.missingAppGroupContainer
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
    }

    private func fileURL(filename: String) -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppConstants.appGroupID)?
            .appendingPathComponent(filename)
    }
}

extension FamilyActivitySelection {
    func sanitizedForAllowedApps() -> FamilyActivitySelection {
        var copy = self
        copy.categoryTokens = []
        copy.webDomainTokens = []
        return copy
    }
}

enum SharedStateError: LocalizedError {
    case missingAppGroupContainer

    var errorDescription: String? {
        "App Group container is unavailable. Check the App Group entitlement."
    }
}
