import Foundation
import ManagedSettings

enum AppConstants {
    static let appGroupID = "group.com.wenlei.PlayTimer"
    static let sessionFilename = "playtimer-session.json"
    static let settingsFilename = "playtimer-settings.json"
    static let allowedAppsFilename = "playtimer-allowed-apps.json"
    static let allowedAppCollectionsFilename = "playtimer-allowed-app-collections.json"
    static let managedSettingsStoreName = ManagedSettingsStore.Name("PlayTimerChildMode")
    static let defaultPlayMinutes = 25
    static let defaultBreakMinutes = 5
    static let playMinuteOptions = [15, 25, 30, 45, 60]
    static let breakMinuteOptions = [5, 10, 15]
    static let defaultTestPlaySeconds = 60
    static let defaultTestBreakSeconds = 30
    static let testPlaySecondOptions = [30, 60]
    static let testBreakSecondOptions = [30, 60]
}
