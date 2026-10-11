import DeviceActivity
import Foundation

final class PlayTimerMonitorExtension: DeviceActivityMonitor {
    private let stateStore = SharedStateStore.shared

    override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
        guard let session = stateStore.loadPersistedSession(),
              session.activityNameRawValue == activity.rawValue,
              session.eventNameRawValue == event.rawValue
        else {
            return
        }

        finishPlayIfDue(session, now: Date())
    }

    override func intervalDidEnd(for activity: DeviceActivityName) {
        guard let session = stateStore.loadPersistedSession(),
              session.deadlineActivityName == activity else {
            return
        }

        finishPlayIfDue(session, now: Date())
    }

    private func finishPlayIfDue(_ currentSession: PlaySession, now: Date) {
        guard currentSession.phase == .playing else { return }
        let playEndAt = currentSession.startedAt.addingTimeInterval(TimeInterval(currentSession.playDurationSeconds))
        guard now >= playEndAt else { return }

        var session = currentSession.refreshed(now: now)
        session.errorMessage = nil

        do {
            try stateStore.saveSession(session)
            ShieldController.applyChildModeShield()
            if session.phase == .break {
                PlayTimerNotificationService.shared.notifyBreakStarted(session)
                PlayTimerNotificationService.shared.scheduleBreakFinished(session)
            }
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
