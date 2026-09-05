import AudioToolbox

enum PlayTimerAudioCueService {
    static func playBreakStartedCue() {
        AudioServicesPlayAlertSound(SystemSoundID(1005))
    }

    static func playBreakFinishedCue() {
        AudioServicesPlayAlertSound(SystemSoundID(1025))
    }
}
