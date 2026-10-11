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

    var recoveryQuestionPrompts: [String] {
        pinStore.recoveryQuestionPrompts
    }

    var hasPINRecoveryQuestions: Bool {
        pinStore.hasRecoveryQuestions
    }

    init() {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        settings = stateStore.loadSettings()
        allowedAppCollections = stateStore.loadAllowedAppCollections()
        session = stateStore.loadSession()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        hasParentPIN = pinStore.hasPIN
        normalizeSelectedCollection()

        #if DEBUG
        #if targetEnvironment(simulator)
        if let previewPhase = Self.simulatorPreviewPhase {
            hasParentPIN = true
            authorizationStatus = .approved
            if previewPhase == .ready {
                session = nil
            } else {
                var sample = PlaySession.new(
                    playSeconds: 25 * 60,
                    breakSeconds: 5 * 60,
                    allowedApplicationCount: 0,
                    allowedCollectionName: nil,
                    now: Date().addingTimeInterval(-6 * 60)
                )
                sample.phase = previewPhase
                if previewPhase == .break {
                    sample.breakStartedAt = Date().addingTimeInterval(-32)
                    sample.breakEndAt = Date().addingTimeInterval(4 * 60 + 28)
                }
                session = sample
            }
        } else if ProcessInfo.processInfo.arguments.contains("-PlayTimerPreviewAuthorization") {
            hasParentPIN = true
            authorizationStatus = .notDetermined
        }
        #endif
        #endif
    }

    #if DEBUG
    #if targetEnvironment(simulator)
    private static var simulatorPreviewPhase: SessionPhase? {
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-MarketingCaptureParentGate") { return .waitingParent }
        if arguments.contains("-PlayTimerPreviewReady") { return .ready }
        if arguments.contains("-PlayTimerPreviewPlaying") { return .playing }
        if arguments.contains("-PlayTimerPreviewBreak") { return .break }
        if arguments.contains("-PlayTimerPreviewWaiting") { return .waitingParent }
        if arguments.contains("-PlayTimerPreviewGate") { return .playing }
        return nil
    }
    #endif
    #endif

    var phase: SessionPhase {
        session?.refreshed().phase ?? .ready
    }

    var isAuthorized: Bool {
        if authorizationStatus == .approved { return true }
        if #available(iOS 26.4, *) {
            return authorizationStatus == .approvedWithDataAccess
        }
        return false
    }

    var allowedAppCount: Int {
        selectedAllowedAppCollection?.applicationCount ?? 0
    }

    var effectivePlayMinutes: Int {
        max(1, effectivePlaySeconds / 60)
    }

    var effectivePlaySeconds: Int {
        settings.isTestModeEnabled ? settings.selectedTestPlaySeconds : settings.selectedPlayMinutes * 60
    }

    var effectiveBreakSeconds: Int {
        settings.isTestModeEnabled ? settings.selectedTestBreakSeconds : settings.selectedBreakMinutes * 60
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
        #if DEBUG
        #if targetEnvironment(simulator)
        if Self.simulatorPreviewPhase != nil || ProcessInfo.processInfo.arguments.contains("-PlayTimerPreviewAuthorization") { return }
        #endif
        #endif
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        allowedAppCollections = stateStore.loadAllowedAppCollections()
        normalizeSelectedCollection()
        refreshSessionFromStore()
    }

    func requestScreenTimeAuthorization() async {
        guard !isBusy else { return }
        isBusy = true
        defer { isBusy = false }
        let statusBeforeRequest = AuthorizationCenter.shared.authorizationStatus

        do {
            try await Task.sleep(nanoseconds: 250_000_000)
            try await AuthorizationCenter.shared.requestAuthorization(for: .individual)
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            if !isAuthorized {
                alertMessage = "屏幕时间权限尚未获批。请检查系统设置后重试。"
            }
        } catch {
            authorizationStatus = AuthorizationCenter.shared.authorizationStatus
            if !isAuthorized {
                alertMessage = makeScreenTimeAuthorizationFailureMessage(
                    error: error,
                    statusBeforeRequest: statusBeforeRequest,
                    statusAfterRequest: authorizationStatus
                )
            }
        }
    }

    func saveSettings(
        playMinutes: Int? = nil,
        breakMinutes: Int? = nil,
        testPlaySeconds: Int? = nil,
        testBreakSeconds: Int? = nil,
        prefersBiometrics: Bool? = nil,
        isTestModeEnabled: Bool? = nil
    ) {
        if let playMinutes {
            settings.selectedPlayMinutes = playMinutes
        }
        if let breakMinutes {
            settings.selectedBreakMinutes = breakMinutes
        }
        if let testPlaySeconds {
            settings.selectedTestPlaySeconds = testPlaySeconds
        }
        if let testBreakSeconds {
            settings.selectedTestBreakSeconds = testBreakSeconds
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

    func createPIN(_ pin: String, questionsAndAnswers: [(question: String, answer: String)]) -> Bool {
        do {
            try pinStore.createPIN(pin, questionsAndAnswers: questionsAndAnswers)
            hasParentPIN = true
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func configurePINRecoveryQuestions(_ questionsAndAnswers: [(question: String, answer: String)]) -> Bool {
        do {
            try pinStore.configureRecoveryQuestions(questionsAndAnswers)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func verifyPINRecoveryAnswers(_ answers: [String]) -> RecoveryAnswerResult {
        do {
            return try pinStore.verifyRecoveryAnswers(answers)
        } catch {
            alertMessage = error.localizedDescription
            return .incorrect
        }
    }

    func resetPINUsingRecoveryQuestions(_ pin: String) -> Bool {
        do {
            try pinStore.resetPIN(pin)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func resetPINAndConfigureRecovery(
        _ pin: String,
        questionsAndAnswers: [(question: String, answer: String)]
    ) -> Bool {
        do {
            try pinStore.resetPINAndConfigureRecovery(pin, questionsAndAnswers: questionsAndAnswers)
            return true
        } catch {
            alertMessage = error.localizedDescription
            return false
        }
    }

    func verifyDeviceOwnerForPINRecovery() async -> Bool {
        do {
            return try await ParentBiometricAuthenticator().authenticateDeviceOwnerForPINRecovery()
        } catch {
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
            playSeconds: effectivePlaySeconds,
            breakSeconds: effectiveBreakSeconds,
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

    func syncSessionFromStoreAndMarkWaitingParentIfNeeded() {
        #if DEBUG
        #if targetEnvironment(simulator)
        if Self.simulatorPreviewPhase != nil { return }
        #endif
        #endif
        refreshSessionFromStore()
    }

    private func refreshSessionFromStore(now: Date = .now) {
        guard let storedSession = stateStore.loadPersistedSession() else {
            session = nil
            return
        }

        let refreshedSession = storedSession.refreshed(now: now)
        if refreshedSession != storedSession {
            do {
                try stateStore.saveSession(refreshedSession)
            } catch {
                alertMessage = error.localizedDescription
            }
        }

        let previousPhase = session?.phase
        session = refreshedSession
        let isRestrictedPhase = refreshedSession.phase == .break || refreshedSession.phase == .waitingParent
        let justEnteredRestrictedPhase = previousPhase != refreshedSession.phase ||
            (storedSession.phase == .playing && refreshedSession.phase != .playing)
        if isRestrictedPhase && justEnteredRestrictedPhase {
            ShieldController.applyChildModeShield()
        }
        if storedSession.phase == .playing && refreshedSession.phase == .break {
            notificationService.notifyBreakStarted(refreshedSession)
            notificationService.scheduleBreakFinished(refreshedSession)
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

    private func makeScreenTimeAuthorizationFailureMessage(
        error: Error,
        statusBeforeRequest: AuthorizationStatus,
        statusAfterRequest: AuthorizationStatus
    ) -> String {
        #if DEBUG
        let nsError = error as NSError
        print("Screen Time authorization failed: \(authorizationStatusName(statusBeforeRequest)) → \(authorizationStatusName(statusAfterRequest)), \(nsError.domain) \(nsError.code): \(nsError.localizedDescription)")
        #endif

        if statusAfterRequest == .denied {
            return "屏幕时间权限未获批准。请在系统设置中检查授权后重试。"
        }

        if let familyControlsError = error as? FamilyControlsError {
            switch familyControlsError {
            case .authorizationCanceled:
                return "已取消屏幕时间授权，可以稍后重试。"
            case .restricted, .unavailable, .authenticationMethodUnavailable:
                return "这台 iPad 当前无法完成屏幕时间授权，请检查设备限制与系统设置。"
            default:
                break
            }
        }

        #if targetEnvironment(simulator)
        let simulatorError = error as NSError
        if simulatorError.domain == NSCocoaErrorDomain && simulatorError.code == 4099 {
            return "模拟器无法连接屏幕时间系统服务。请在真机上完成授权验证。"
        }
        #endif

        return "屏幕时间授权未完成，请稍后重试。"
    }

    private func authorizationStatusName(_ status: AuthorizationStatus) -> String {
        if #available(iOS 26.4, *), status == .approvedWithDataAccess {
            return "approvedWithDataAccess"
        }
        switch status {
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .approved:
            return "approved"
        default:
            return "unknown(\(status.rawValue))"
        }
    }

}
