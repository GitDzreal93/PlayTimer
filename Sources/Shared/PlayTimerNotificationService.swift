import Foundation
import UserNotifications

struct PlayTimerNotificationService {
    static let shared = PlayTimerNotificationService()

    private let center = UNUserNotificationCenter.current()

    func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                return false
            }
        @unknown default:
            return false
        }
    }

    func notifySessionStarted(_ session: PlaySession) {
        let body: String
        if let name = session.allowedCollectionName, session.allowedApplicationCount > 0 {
            body = "\(name) 已开始，预计剩余 \(Self.durationText(seconds: session.playDurationSeconds))。"
        } else {
            body = "儿童模式已开始，预计剩余 \(Self.durationText(seconds: session.playDurationSeconds))。"
        }

        addImmediateNotification(
            identifier: "playtimer-started-\(session.sessionID.uuidString)",
            title: "PlayTimer 已开始",
            body: body
        )
    }

    func notifyBreakStarted(_ session: PlaySession) {
        let body: String
        if let breakEndAt = session.breakEndAt {
            body = "本轮 \(Self.durationText(seconds: session.playDurationSeconds)) 已用完，休息到 \(Self.timeFormatter.string(from: breakEndAt))。"
        } else {
            body = "本轮 \(Self.durationText(seconds: session.playDurationSeconds)) 已用完，现在休息 \(Self.durationText(seconds: session.breakDurationSeconds))。"
        }

        addImmediateNotification(
            identifier: "playtimer-break-started-\(session.sessionID.uuidString)",
            title: "休息时间到了",
            body: body
        )
    }

    func scheduleBreakFinished(_ session: PlaySession) {
        let seconds = max(1, session.breakDurationSeconds)
        let content = makeContent(
            title: "休息结束",
            body: "请家长验证后开始新一轮，或结束儿童模式。"
        )
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request = UNNotificationRequest(
            identifier: "playtimer-break-finished-\(session.sessionID.uuidString)",
            content: content,
            trigger: trigger
        )

        center.add(request)
    }

    func notifyFiveMinuteWarning(_ session: PlaySession) {
        addImmediateNotification(
            identifier: "playtimer-warning-\(session.sessionID.uuidString)",
            title: "还有 5 分钟",
            body: "快到休息时间啦。"
        )
    }

    func cancelSessionNotifications(_ session: PlaySession) {
        let identifiers = [
            "playtimer-started-\(session.sessionID.uuidString)",
            "playtimer-warning-\(session.sessionID.uuidString)",
            "playtimer-break-started-\(session.sessionID.uuidString)",
            "playtimer-break-finished-\(session.sessionID.uuidString)"
        ]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private func addImmediateNotification(identifier: String, title: String, body: String) {
        let request = UNNotificationRequest(
            identifier: identifier,
            content: makeContent(title: title, body: body),
            trigger: nil
        )
        center.add(request)
    }

    private func makeContent(title: String, body: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        return content
    }

    private static func durationText(seconds: Int) -> String {
        if seconds % 60 == 0 {
            return "\(seconds / 60) 分钟"
        }
        return "\(seconds) 秒"
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}
