import DeviceActivity
import Foundation

final class PlayTimerMonitorExtension: DeviceActivityMonitor {
    private let stateStore = SharedStateStore.shared

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard var session = stateStore.loadPersistedSession(),
              session.phase == .playing,
              session.activityNameRawValue == activity.rawValue,
              session.eventNameRawValue == event.rawValue
        else {
            return
        }

        let playEndAt = session.startedAt.addingTimeInterval(TimeInterval(session.playDurationSeconds))
        session.phase = .break
        session.breakStartedAt = playEndAt
        session.breakEndAt = playEndAt.addingTimeInterval(TimeInterval(session.breakDurationSeconds))
        session.lastUpdatedAt = Date()
        session.errorMessage = nil

        do {
            try stateStore.saveSession(session)
            ShieldController.applyChildModeShield()
            PlayTimerNotificationService.shared.notifyBreakStarted(session)
            PlayTimerNotificationService.shared.scheduleBreakFinished(session)
        } catch {
            ShieldController.applyChildModeShield()
        }
    }

    override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard let session = stateStore.loadPersistedSession(),
              session.phase == .playing,
              session.activityNameRawValue == activity.rawValue,
              session.eventNameRawValue == event.rawValue
        else {
            return
        }

        PlayTimerNotificationService.shared.notifyFiveMinuteWarning(session)
    }
}
