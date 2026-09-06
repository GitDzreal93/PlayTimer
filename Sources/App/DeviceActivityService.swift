import DeviceActivity
import Foundation
import ManagedSettings

struct DeviceActivityService {
    private let center = DeviceActivityCenter()

    func startMonitoring(session: PlaySession, allowedApplications: Set<ApplicationToken>) async throws {
        stopMonitoring(session: session)

        // 窗口锚定会话开始时刻，覆盖玩耍 + 休息总时长并预留缓冲，
        // 避免日历日窗口在午夜重建导致用量清零。
        let calendar = Calendar.current
        let bufferSeconds = 30 * 60
        let windowSeconds = session.playDurationSeconds + session.breakDurationSeconds + bufferSeconds
        let intervalStart = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: session.startedAt
        )
        let intervalEndDate = session.startedAt.addingTimeInterval(TimeInterval(windowSeconds))
        let intervalEnd = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: intervalEndDate
        )

        // 5 分钟预警；会话本身不足 5 分钟时按剩余时间的一半给预警（至少 5 秒）
        let warningSeconds: Int
        if session.playDurationSeconds > 5 * 60 {
            warningSeconds = 5 * 60
        } else {
            warningSeconds = max(5, session.playDurationSeconds / 2)
        }
        let schedule = DeviceActivitySchedule(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            repeats: false,
            warningTime: DateComponents(second: warningSeconds)
        )

        let threshold = DateComponents(second: session.playDurationSeconds)
        let event: DeviceActivityEvent
        if #available(iOS 17.4, *) {
            event = DeviceActivityEvent(
                applications: allowedApplications,
                threshold: threshold,
                includesPastActivity: false
            )
        } else {
            event = DeviceActivityEvent(
                applications: allowedApplications,
                threshold: threshold
            )
        }

        try center.startMonitoring(
            session.activityName,
            during: schedule,
            events: [session.eventName: event]
        )
    }

    func stopMonitoring(session: PlaySession) {
        center.stopMonitoring([session.activityName, ActivityIdentifiers.childMode])
    }
}
