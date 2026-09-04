import Foundation

struct UserSettings: Codable, Equatable {
    var selectedPlayMinutes: Int
    var selectedBreakMinutes: Int
    var prefersBiometrics: Bool

    static let defaults = UserSettings(
        selectedPlayMinutes: AppConstants.defaultPlayMinutes,
        selectedBreakMinutes: AppConstants.defaultBreakMinutes,
        prefersBiometrics: true
    )
}
