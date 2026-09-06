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
        let bufferMinutes = 30
        let windowMinutes = session.playDurationMinutes + session.breakDurationMinutes + bufferMinutes
        let intervalStart = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: session.startedAt
        )
        let intervalEndDate = calendar.date(
            byAdding: .minute,
            value: windowMinutes,
            to: session.startedAt
        ) ?? session.startedAt.addingTimeInterval(TimeInterval(windowMinutes * 60))
        let intervalEnd = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: intervalEndDate
        )

        let warningOffset = min(5, max(0, session.playDurationMinutes - 1))
        let schedule = DeviceActivitySchedule(
            intervalStart: intervalStart,
            intervalEnd: intervalEnd,
            repeats: false,
            warningTime: DateComponents(minute: warningOffset)
        )

        let threshold = DateComponents(minute: session.playDurationMinutes)
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
