import Combine
import FamilyControls
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var session: PlaySession?
    @Published var settings: UserSettings
    @Published var authorizationStatus: AuthorizationStatus
    @Published var hasParentPIN: Bool
    @Published var isBusy = false
    @Published var alertMessage: String?

    private let stateStore = SharedStateStore.shared
    private let activityService = DeviceActivityService()
    private let pinStore = ParentPINStore()

    init() {
        settings = stateStore.loadSettings()
        session = stateStore.loadSession()
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
        hasParentPIN = pinStore.hasPIN
    }

    var phase: SessionPhase {
        session?.refreshed().phase ?? .ready
    }

    var isAuthorized: Bool {
        authorizationStatus == .approved
    }

    func refresh() async {
        authorizationStatus = AuthorizationCenter.shared.authorizationStatus
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

    func saveSettings(playMinutes: Int? = nil, breakMinutes: Int? = nil, prefersBiometrics: Bool? = nil) {
        if let playMinutes {
            settings.selectedPlayMinutes = playMinutes
        }
        if let breakMinutes {
            settings.selectedBreakMinutes = breakMinutes
        }
        if let prefersBiometrics {
            settings.prefersBiometrics = prefersBiometrics
        }

        do {
            try stateStore.saveSettings(settings)
        } catch {
            alertMessage = error.localizedDescription
        }
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
            playMinutes: settings.selectedPlayMinutes,
            breakMinutes: settings.selectedBreakMinutes
        )

        do {
            if let session {
                activityService.stopMonitoring(session: session)
            }
            try await activityService.startMonitoring(session: newSession)
            ShieldController.clearChildModeShield()
            try stateStore.saveSession(newSession)
            session = newSession
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
}
