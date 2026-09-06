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
        let statusBeforeRequest = AuthorizationCenter.shared.authorizationStatus

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            alertMessage = makeScreenTimeAuthorizationFailureMessage(
                error: error,
                statusBeforeRequest: statusBeforeRequest,
                statusAfterRequest: authorizationStatus
            )
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
            alertMessage = makeBiometricFailureMessage(error)
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

    func syncSessionFromStoreAndMarkWaitingParentIfNeeded() {
        let storedSession = stateStore.loadSession()
        if storedSession != session {
            session = storedSession
        }

        markWaitingParentIfNeeded()
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

    private func makeScreenTimeAuthorizationFailureMessage(
        error: Error,
        statusBeforeRequest: AuthorizationStatus,
        statusAfterRequest: AuthorizationStatus
    ) -> String {
        var details = [
            "Screen Time 授权失败。",
            "授权方式: individual",
            "FamilyControls: \(familyControlsErrorName(error))",
            "授权前状态: \(authorizationStatusName(statusBeforeRequest))",
            "授权后状态: \(authorizationStatusName(statusAfterRequest))"
        ]
        details.append(contentsOf: nsErrorDetails(error))
        return details.joined(separator: "\n")
    }

    private func makeBiometricFailureMessage(_ error: Error) -> String {
        var details = ["家长身份验证失败。"]
        details.append(contentsOf: nsErrorDetails(error))
        return details.joined(separator: "\n")
    }

    private func familyControlsErrorName(_ error: Error) -> String {
        guard let familyControlsError = error as? FamilyControlsError else {
            return "不是 FamilyControlsError"
        }

        switch familyControlsError {
        case .restricted:
            return "restricted"
        case .unavailable:
            return "unavailable"
        case .invalidAccountType:
            return "invalidAccountType"
        case .invalidArgument:
            return "invalidArgument"
        case .authorizationConflict:
            return "authorizationConflict"
        case .authorizationCanceled:
            return "authorizationCanceled"
        case .networkError:
            return "networkError"
        case .authenticationMethodUnavailable:
            return "authenticationMethodUnavailable"
        @unknown default:
            return "unknown(\(familyControlsError.localizedDescription))"
        }
    }

    private func authorizationStatusName(_ status: AuthorizationStatus) -> String {
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .approved:
            return "approved"
        @unknown default:
            return "unknown(\(status.rawValue))"
        }
    }

    private func nsErrorDetails(_ error: Error) -> [String] {
        let nsError = error as NSError
        return [
            "NSError domain: \(nsError.domain)",
            "NSError code: \(nsError.code)",
            "说明: \(nsError.localizedDescription)"
        ]
    }
}
