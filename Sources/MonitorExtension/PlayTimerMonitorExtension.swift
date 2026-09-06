import DeviceActivity
import Foundation

final class PlayTimerMonitorExtension: DeviceActivityMonitor {
    private let stateStore = SharedStateStore.shared

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard var session = stateStore.loadSession(),
              session.phase == .playing,
              session.activityNameRawValue == activity.rawValue,
              session.eventNameRawValue == event.rawValue
        else {
            return
        }

        let now = Date()
        session.phase = .break
        session.breakStartedAt = now
        session.breakEndAt = Calendar.current.date(byAdding: .minute, value: session.breakDurationMinutes, to: now)
        session.lastUpdatedAt = now
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
        guard let session = stateStore.loadSession(),
              session.phase == .playing,
              session.activityNameRawValue == activity.rawValue,
              session.eventNameRawValue == event.rawValue
        else {
            return
        }

        PlayTimerNotificationService.shared.notifyFiveMinuteWarning(session)
    }
}
