import Foundation

struct PlaySession: Codable, Equatable {
    var sessionID: UUID
    var phase: SessionPhase
    var playDurationMinutes: Int
    var breakDurationMinutes: Int
    var startedAt: Date
    var breakStartedAt: Date?
    var breakEndAt: Date?
    var lastUpdatedAt: Date
    var errorMessage: String?
    var activityNameRawValue: String
    var eventNameRawValue: String

    static func new(playMinutes: Int, breakMinutes: Int, now: Date = Date()) -> PlaySession {
        let sessionID = UUID()
        return PlaySession(
            sessionID: sessionID,
            phase: .playing,
            playDurationMinutes: playMinutes,
            breakDurationMinutes: breakMinutes,
            startedAt: now,
            breakStartedAt: nil,
            breakEndAt: nil,
            lastUpdatedAt: now,
            errorMessage: nil,
            activityNameRawValue: "PlayTimerChildMode-\(sessionID.uuidString)",
            eventNameRawValue: "PlayTimerUsageLimit-\(sessionID.uuidString)"
        )
    }

    func refreshed(now: Date = Date()) -> PlaySession {
        guard phase == .break, let breakEndAt, now >= breakEndAt else {
            return self
        }

        var copy = self
        copy.phase = .waitingParent
        copy.lastUpdatedAt = now
        return copy
    }
}
