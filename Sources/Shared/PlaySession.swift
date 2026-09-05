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
    var allowedApplicationCount: Int

    init(
        sessionID: UUID,
        phase: SessionPhase,
        playDurationMinutes: Int,
        breakDurationMinutes: Int,
        startedAt: Date,
        breakStartedAt: Date?,
        breakEndAt: Date?,
        lastUpdatedAt: Date,
        errorMessage: String?,
        activityNameRawValue: String,
        eventNameRawValue: String,
        allowedApplicationCount: Int
    ) {
        self.sessionID = sessionID
        self.phase = phase
        self.playDurationMinutes = playDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.startedAt = startedAt
        self.breakStartedAt = breakStartedAt
        self.breakEndAt = breakEndAt
        self.lastUpdatedAt = lastUpdatedAt
        self.errorMessage = errorMessage
        self.activityNameRawValue = activityNameRawValue
        self.eventNameRawValue = eventNameRawValue
        self.allowedApplicationCount = allowedApplicationCount
    }

    static func new(
        playMinutes: Int,
        breakMinutes: Int,
        allowedApplicationCount: Int,
        now: Date = Date()
    ) -> PlaySession {
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
            eventNameRawValue: "PlayTimerUsageLimit-\(sessionID.uuidString)",
            allowedApplicationCount: allowedApplicationCount
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

extension PlaySession {
    enum CodingKeys: String, CodingKey {
        case sessionID
        case phase
        case playDurationMinutes
        case breakDurationMinutes
        case startedAt
        case breakStartedAt
        case breakEndAt
        case lastUpdatedAt
        case errorMessage
        case activityNameRawValue
        case eventNameRawValue
        case allowedApplicationCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        phase = try container.decode(SessionPhase.self, forKey: .phase)
        playDurationMinutes = try container.decode(Int.self, forKey: .playDurationMinutes)
        breakDurationMinutes = try container.decode(Int.self, forKey: .breakDurationMinutes)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        breakStartedAt = try container.decodeIfPresent(Date.self, forKey: .breakStartedAt)
        breakEndAt = try container.decodeIfPresent(Date.self, forKey: .breakEndAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        activityNameRawValue = try container.decode(String.self, forKey: .activityNameRawValue)
        eventNameRawValue = try container.decode(String.self, forKey: .eventNameRawValue)
        allowedApplicationCount = try container.decodeIfPresent(Int.self, forKey: .allowedApplicationCount) ?? 0
    }
}
