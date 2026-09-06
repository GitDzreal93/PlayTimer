import Combine
import FamilyControls
import Foundation
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    @Published var session: PlaySession?
    @Published var settings: UserSettings
    @Published var allowedAppCollections: [AllowedAppCollection]
    @Published var authorizationStatus: AuthorizationStatus
    @Published var hasParentPIN: Bool
    @Published var isBusy = false
    @Published var alertMessage: String?

    private let stateStore = SharedStateStore.shared
    private let activityService = DeviceActivityService()
    private let notificationService = PlayTimerNotificationService.shared
    private let notificationDelegate = PlayTimerNotificationDelegate()
    private let pinStore = ParentPINStore()

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        settings = stateStore.loadSettings()
        allowedAppCollections = stateStore.loadAllowedAppCollections()
        session = stateStore.loadSession()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        hasParentPIN = pinStore.hasPIN
        normalizeSelectedCollection()
    }

    var phase: SessionPhase {
        session?.refreshed().phase ?? .ready
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    var allowedAppCount: Int {
        selectedAllowedAppCollection?.applicationCount ?? 0
    }

    var effectivePlayMinutes: Int {
        settings.isTestModeEnabled ? 1 : settings.selectedPlayMinutes
    }

    var selectedAllowedAppCollection: AllowedAppCollection? {
        guard let selectedID = settings.selectedAllowedAppCollectionID else {
            return nil
        }
        return allowedAppCollections.first { $0.id == selectedID }
    }

    var selectedAllowedAppSelection: FamilyActivitySelection {
        selectedAllowedAppCollection?.selection ?? FamilyActivitySelection()
    }

    func refresh() async {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        allowedAppCollections = stateStore.loadAllowedAppCollections()
        normalizeSelectedCollection()
        session = stateStore.loadSession()
        if let session, session != self.session {
            try? stateStore.saveSession(session)
            self.session = session
        }
    }

    func requestScreenTimeAuthorization() async {
        isBusy = true
        defer { isBusy = false }

        do {
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func saveSettings(
        playMinutes: Int? = nil,
        breakMinutes: Int? = nil,
        prefersBiometrics: Bool? = nil,
        isTestModeEnabled: Bool? = nil
    ) {
        if let playMinutes {
            settings.selectedPlayMinutes = playMinutes
        }
        if let breakMinutes {
            settings.selectedBreakMinutes = breakMinutes
        }
        if let prefersBiometrics {
            settings.prefersBiometrics = prefersBiometrics
        }
        if let isTestModeEnabled {
            settings.isTestModeEnabled = isTestModeEnabled
        }

        do {
            try stateStore.saveSettings(settings)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func saveAllowedAppSelection(_ selection: FamilyActivitySelection) {
        let sanitized = selection.sanitizedForAllowedApps()
        guard let selectedID = settings.selectedAllowedAppCollectionID else {
            createAllowedAppCollection(name: "默认合集", selection: sanitized)
            return
        }
        updateAllowedAppSelection(sanitized, for: selectedID)
    }

    func createAllowedAppCollection(name: String, selection: FamilyActivitySelection = FamilyActivitySelection()) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let collection = AllowedAppCollection.make(
            name: trimmedName.isEmpty ? nextCollectionName() : trimmedName,
            selection: selection
        )

        allowedAppCollections.append(collection)
        settings.selectedAllowedAppCollectionID = collection.id
        persistCollectionsAndSettings()
    }

    func selectAllowedAppCollection(_ id: UUID?) {
        settings.selectedAllowedAppCollectionID = id
        persistSettings()
    }

    func renameAllowedAppCollection(_ id: UUID, name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              let index = allowedAppCollections.firstIndex(where: { $0.id == id })
        else {
            return
        }

        allowedAppCollections[index] = allowedAppCollections[index].renamed(trimmedName)
        persistCollections()
    }

    func updateAllowedAppSelection(_ selection: FamilyActivitySelection, for id: UUID) {
        guard let index = allowedAppCollections.firstIndex(where: { $0.id == id }) else { return }
        allowedAppCollections[index] = allowedAppCollections[index].replacingSelection(selection)
        persistCollections()
    }

    func deleteAllowedAppCollection(_ id: UUID) {
        allowedAppCollections.removeAll { $0.id == id }
        if settings.selectedAllowedAppCollectionID == id {
            settings.selectedAllowedAppCollectionID = allowedAppCollections.first?.id
        }
        persistCollectionsAndSettings()
    }

    func createPIN(_ pin: String) -> Bool {
        do {
            try pinStore.createPIN(pin)
            hasParentPIN = true
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func verifyPIN(_ pin: String) -> Bool {
        do {
            return try pinStore.verify(pin)
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func verifyBiometrics() async -> Bool {
        guard settings.prefersBiometrics else { return false }
        do {
            return try await ParentBiometricAuthenticator().authenticate()
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func startChildMode() async {
        guard isAuthorized else {
            alertMessage = "需要先授权屏幕时间权限。"
            return
        }

        isBusy = true
        defer { isBusy = false }

        let newSession = PlaySession.new(
            playMinutes: effectivePlayMinutes,
            breakMinutes: settings.selectedBreakMinutes,
            allowedApplicationCount: allowedAppCount,
            allowedCollectionName: selectedAllowedAppCollection?.name
        )

        do {
            if let session {
                activityService.stopMonitoring(session: session)
                notificationService.cancelSessionNotifications(session)
            }
            _ = await notificationService.requestAuthorizationIfNeeded()
            let allowedApplications = selectedAllowedAppSelection.applicationTokens
            try await activityService.startMonitoring(
                session: newSession,
                allowedApplications: allowedApplications
            )
            ShieldController.applyAllowedAppsShield(allowedApplications: allowedApplications)
            try stateStore.saveSession(newSession)
            session = newSession
            notificationService.notifySessionStarted(newSession)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func endChildMode() {
        isBusy = true
        defer { isBusy = false }

        do {
            if let session {
                activityService.stopMonitoring(session: session)
                notificationService.cancelSessionNotifications(session)
            }
            ShieldController.clearChildModeShield()
            try stateStore.saveSession(nil)
            session = nil
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    func markWaitingParentIfNeeded() {
        guard let refreshed = session?.refreshed(), refreshed != session else { return }
        do {
            try stateStore.saveSession(refreshed)
            session = refreshed
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func normalizeSelectedCollection() {
        guard let selectedID = settings.selectedAllowedAppCollectionID else { return }

        let selectedExists = allowedAppCollections.contains { $0.id == selectedID }
        if !selectedExists {
            settings.selectedAllowedAppCollectionID = nil
            persistSettings()
        }
    }

    private func nextCollectionName() -> String {
        let base = "新合集"
        guard allowedAppCollections.contains(where: { $0.name == base }) else { return base }

        var index = 2
        while allowedAppCollections.contains(where: { $0.name == "\(base) \(index)" }) {
            index += 1
        }
        return "\(base) \(index)"
    }

    private func persistCollectionsAndSettings() {
        persistCollections()
        persistSettings()
    }

    private func persistCollections() {
        do {
            try stateStore.saveAllowedAppCollections(allowedAppCollections)
        } catch {
            alertMessage = error.localizedDescription
        }
    }

    private func persistSettings() {
        do {
            try stateStore.saveSettings(settings)
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}
