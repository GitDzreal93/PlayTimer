import DeviceActivity
import Foundation
import ManagedSettings

struct DeviceActivityService {
    private let center = DeviceActivityCenter()

    func startMonitoring(session: PlaySession, allowedApplications: Set<ApplicationToken>) async throws {
        stopMonitoring(session: session)

        let schedule = DeviceActivitySchedule(
            intervalStart: DateComponents(hour: 0, minute: 0, second: 0),
            intervalEnd: DateComponents(hour: 23, minute: 59, second: 59),
            repeats: true,
            warningTime: session.playDurationSeconds > 5 * 60 ? DateComponents(minute: 5) : nil
        )

        let threshold = DateComponents(
            minute: session.playDurationSeconds / 60,
            second: session.playDurationSeconds % 60
        )
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

        try center.startMonitoring(session.activityName, during: schedule, events: [session.eventName: event])

        // The visible countdown is based on elapsed wall time. Keep an independent
        // deadline monitor so a delayed usage-threshold callback cannot leave a
        // foreground game playable after that countdown ends.
        let deadline = session.startedAt.addingTimeInterval(TimeInterval(session.playDurationSeconds))
        let scheduledEnd = Date(timeIntervalSince1970: ceil(deadline.timeIntervalSince1970))
        let scheduledStart = min(session.startedAt, scheduledEnd.addingTimeInterval(-16 * 60))
        let calendar = Calendar.current
        let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let deadlineSchedule = DeviceActivitySchedule(
            intervalStart: calendar.dateComponents(components, from: scheduledStart),
            intervalEnd: calendar.dateComponents(components, from: scheduledEnd),
            repeats: false
        )
        do {
            try center.startMonitoring(session.deadlineActivityName, during: deadlineSchedule)
        } catch {
            center.stopMonitoring([session.activityName])
            throw error
        }
    }

    func stopMonitoring(session: PlaySession) {
        center.stopMonitoring([session.activityName, session.deadlineActivityName, ActivityIdentifiers.childMode])
    }
}
