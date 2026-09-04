import Foundation
import ManagedSettings

enum AppConstants {
    static let appGroupID = "group.com.wenlei.PlayTimer"
    static let sessionFilename = "playtimer-session.json"
    static let settingsFilename = "playtimer-settings.json"
    static let managedSettingsStoreName = ManagedSettingsStore.Name("PlayTimerChildMode")
    static let defaultPlayMinutes = 25
    static let defaultBreakMinutes = 5
    static let playMinuteOptions = [15, 25, 30, 45, 60]
    static let breakMinuteOptions = [5, 10, 15]
}
