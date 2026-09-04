import Foundation
import ManagedSettings

enum ShieldController {
    private static var store: ManagedSettingsStore {
        ManagedSettingsStore(named: AppConstants.managedSettingsStoreName)
    }

    static func applyChildModeShield() {
        let store = store
        store.shield.applicationCategories = .all()
        store.shield.webDomainCategories = .all()
    }

    static func clearChildModeShield() {
        store.clearAllSettings()
    }
}
