import Foundation

struct UserSettings: Codable, Equatable {
    var selectedPlayMinutes: Int
    var selectedBreakMinutes: Int
    var prefersBiometrics: Bool
    var selectedAllowedAppCollectionID: UUID?

    static let defaults = UserSettings(
        selectedPlayMinutes: AppConstants.defaultPlayMinutes,
        selectedBreakMinutes: AppConstants.defaultBreakMinutes,
        prefersBiometrics: true,
        selectedAllowedAppCollectionID: nil
    )

    init(
        selectedPlayMinutes: Int,
        selectedBreakMinutes: Int,
        prefersBiometrics: Bool,
        selectedAllowedAppCollectionID: UUID?
    ) {
        self.selectedPlayMinutes = selectedPlayMinutes
        self.selectedBreakMinutes = selectedBreakMinutes
        self.prefersBiometrics = prefersBiometrics
        self.selectedAllowedAppCollectionID = selectedAllowedAppCollectionID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedPlayMinutes = try container.decodeIfPresent(Int.self, forKey: .selectedPlayMinutes) ?? AppConstants.defaultPlayMinutes
        selectedBreakMinutes = try container.decodeIfPresent(Int.self, forKey: .selectedBreakMinutes) ?? AppConstants.defaultBreakMinutes
        prefersBiometrics = try container.decodeIfPresent(Bool.self, forKey: .prefersBiometrics) ?? true
        selectedAllowedAppCollectionID = try container.decodeIfPresent(UUID.self, forKey: .selectedAllowedAppCollectionID)
    }
}

extension UserSettings {
    enum CodingKeys: String, CodingKey {
        case selectedPlayMinutes
        case selectedBreakMinutes
        case prefersBiometrics
        case selectedAllowedAppCollectionID
    }
}
