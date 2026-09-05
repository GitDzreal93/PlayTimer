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
            warningTime: DateComponents(minute: 5)
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
