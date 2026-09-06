import Foundation

struct UserSettings: Codable, Equatable {
    var selectedPlayMinutes: Int
    var selectedBreakMinutes: Int
    var prefersBiometrics: Bool
    var isTestModeEnabled: Bool
    var selectedAllowedAppCollectionID: UUID?
    var testPlaySeconds: Int
    var testBreakSeconds: Int

    static let defaults = UserSettings(
        selectedPlayMinutes: AppConstants.defaultPlayMinutes,
        selectedBreakMinutes: AppConstants.defaultBreakMinutes,
        prefersBiometrics: true,
        isTestModeEnabled: false,
        selectedAllowedAppCollectionID: nil,
        testPlaySeconds: AppConstants.defaultTestPlaySeconds,
        testBreakSeconds: AppConstants.defaultTestBreakSeconds
    )

    init(
        selectedPlayMinutes: Int,
        selectedBreakMinutes: Int,
        prefersBiometrics: Bool,
        isTestModeEnabled: Bool,
        selectedAllowedAppCollectionID: UUID?,
        testPlaySeconds: Int = AppConstants.defaultTestPlaySeconds,
        testBreakSeconds: Int = AppConstants.defaultTestBreakSeconds
    ) {
        self.selectedPlayMinutes = selectedPlayMinutes
        self.selectedBreakMinutes = selectedBreakMinutes
        self.prefersBiometrics = prefersBiometrics
        self.isTestModeEnabled = isTestModeEnabled
        self.selectedAllowedAppCollectionID = selectedAllowedAppCollectionID
        self.testPlaySeconds = testPlaySeconds
        self.testBreakSeconds = testBreakSeconds
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPlayMinutes = try container.decodeIfPresent(Int.self, forKey: .selectedPlayMinutes) ?? AppConstants.defaultPlayMinutes
        selectedBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .selectedBreakMinutes) ?? AppConstants.defaultBreakMinutes
        prefersBiometrics = try container.decodeIfPresent(Bool.self, forKey: .prefersBiometrics) ?? true
        isTestModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .isTestModeEnabled) ?? false
        selectedAllowedAppCollectionID = try container.decodeIfPresent(UUID.self, forKey: .selectedAllowedAppCollectionID)
        testPlaySeconds = try container.decodeIfPresent(Int.self, forKey: .testPlaySeconds) ?? AppConstants.defaultTestPlaySeconds
        testBreakSeconds = try container.decodeIfPresent(Int.self, forKey: .testBreakSeconds) ?? AppConstants.defaultTestBreakSeconds
    }
}

extension UserSettings {
    enum CodingKeys: String, CodingKey {
        case selectedPlayMinutes
        case selectedBreakMinutes
        case prefersBiometrics
        case isTestModeEnabled
        case selectedAllowedAppCollectionID
        case testPlaySeconds
        case testBreakSeconds
    }
}
