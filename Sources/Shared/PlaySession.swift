import Foundation

struct PlaySession: Codable, Equatable {
    var sessionID: UUID
    var phase: SessionPhase
    var playDurationMinutes: Int
    var breakDurationMinutes: Int
    var playDurationSeconds: Int
    var breakDurationSeconds: Int
    var startedAt: Date
    var breakStartedAt: Date?
    var breakEndAt: Date?
    var lastUpdatedAt: Date
    var errorMessage: String?
    var activityNameRawValue: String
    var eventNameRawValue: String
    var allowedApplicationCount: Int
    var allowedCollectionName: String?

    init(
        sessionID: UUID,
        phase: SessionPhase,
        playDurationMinutes: Int,
        breakDurationMinutes: Int,
        playDurationSeconds: Int,
        breakDurationSeconds: Int,
        startedAt: Date,
        breakStartedAt: Date?,
        breakEndAt: Date?,
        lastUpdatedAt: Date,
        errorMessage: String?,
        activityNameRawValue: String,
        eventNameRawValue: String,
        allowedApplicationCount: Int,
        allowedCollectionName: String?
    ) {
        self.sessionID = sessionID
        self.phase = phase
        self.playDurationMinutes = playDurationMinutes
        self.breakDurationMinutes = breakDurationMinutes
        self.playDurationSeconds = playDurationSeconds
        self.breakDurationSeconds = breakDurationSeconds
        self.startedAt = startedAt
        self.breakStartedAt = breakStartedAt
        self.breakEndAt = breakEndAt
        self.lastUpdatedAt = lastUpdatedAt
        self.errorMessage = errorMessage
        self.activityNameRawValue = activityNameRawValue
        self.eventNameRawValue = eventNameRawValue
        self.allowedApplicationCount = allowedApplicationCount
        self.allowedCollectionName = allowedCollectionName
    }

    static func new(
        playSeconds: Int,
        breakSeconds: Int,
        allowedApplicationCount: Int,
        allowedCollectionName: String?,
        now: Date = Date()
    ) -> PlaySession {
        let sessionID = UUID()
        return PlaySession(
            sessionID: sessionID,
            phase: .playing,
            playDurationMinutes: max(1, playSeconds / 60),
            breakDurationMinutes: max(1, breakSeconds / 60),
            playDurationSeconds: playSeconds,
            breakDurationSeconds: breakSeconds,
            startedAt: now,
            breakStartedAt: nil,
            breakEndAt: nil,
            lastUpdatedAt: now,
            errorMessage: nil,
            activityNameRawValue: "PlayTimerChildMode-\(sessionID.uuidString)",
            eventNameRawValue: "PlayTimerUsageLimit-\(sessionID.uuidString)",
            allowedApplicationCount: allowedApplicationCount,
            allowedCollectionName: allowedCollectionName
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
        case playDurationSeconds
        case breakDurationSeconds
        case startedAt
        case breakStartedAt
        case breakEndAt
        case lastUpdatedAt
        case errorMessage
        case activityNameRawValue
        case eventNameRawValue
        case allowedApplicationCount
        case allowedCollectionName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        phase = try container.decode(SessionPhase.self, forKey: .phase)
        playDurationMinutes = try container.decode(Int.self, forKey: .playDurationMinutes)
        breakDurationMinutes = try container.decode(Int.self, forKey: .breakDurationMinutes)
        playDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .playDurationSeconds) ?? playDurationMinutes * 60
        breakDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .breakDurationSeconds) ?? breakDurationMinutes * 60
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        breakStartedAt = try container.decodeIfPresent(Date.self, forKey: .breakStartedAt)
        breakEndAt = try container.decodeIfPresent(Date.self, forKey: .breakEndAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        activityNameRawValue = try container.decode(String.self, forKey: .activityNameRawValue)
        eventNameRawValue = try container.decode(String.self, forKey: .eventNameRawValue)
        allowedApplicationCount = try container.decodeIfPresent(Int.self, forKey: .allowedApplicationCount) ?? 0
        allowedCollectionName = try container.decodeIfPresent(String.self, forKey: .allowedCollectionName)
    }
}
