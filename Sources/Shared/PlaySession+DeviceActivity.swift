import DeviceActivity
import Foundation

extension PlaySession {
    var activityName: DeviceActivityName {
        DeviceActivityName(activityNameRawValue)
    }

    var eventName: DeviceActivityEvent.Name {
        DeviceActivityEvent.Name(eventNameRawValue)
    }
}
