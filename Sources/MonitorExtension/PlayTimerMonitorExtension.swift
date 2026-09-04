import DeviceActivity
import Foundation
import UserNotifications

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

        let content = UNMutableNotificationContent()
        content.title = "还有 5 分钟"
        content.body = "快到休息时间啦。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "playtimer-warning-\(session.sessionID.uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
