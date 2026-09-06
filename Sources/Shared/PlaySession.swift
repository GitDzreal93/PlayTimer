import Foundation

struct PlaySession: Codable, Equatable {
    var sessionID: UUID
    var phase: SessionPhase
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

        // 旧版本以分钟存储，仅用于解码兼容
        case legacyPlayDurationMinutes = "playDurationMinutes"
        case legacyBreakDurationMinutes = "breakDurationMinutes"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sessionID = try container.decode(UUID.self, forKey: .sessionID)
        phase = try container.decode(SessionPhase.self, forKey: .phase)
        playDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .playDurationSeconds)
            ?? (try container.decodeIfPresent(Int.self, forKey: .legacyPlayDurationMinutes).map { $0 * 60 })
            ?? AppConstants.defaultPlayMinutes * 60
        breakDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .breakDurationSeconds)
            ?? (try container.decodeIfPresent(Int.self, forKey: .legacyBreakDurationMinutes).map { $0 * 60 })
            ?? AppConstants.defaultBreakMinutes * 60
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sessionID, forKey: .sessionID)
        try container.encode(phase, forKey: .phase)
        try container.encode(playDurationSeconds, forKey: .playDurationSeconds)
        try container.encode(breakDurationSeconds, forKey: .breakDurationSeconds)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(breakStartedAt, forKey: .breakStartedAt)
        try container.encodeIfPresent(breakEndAt, forKey: .breakEndAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encodeIfPresent(errorMessage, forKey: .errorMessage)
        try container.encode(activityNameRawValue, forKey: .activityNameRawValue)
        try container.encode(eventNameRawValue, forKey: .eventNameRawValue)
        try container.encode(allowedApplicationCount, forKey: .allowedApplicationCount)
        try container.encodeIfPresent(allowedCollectionName, forKey: .allowedCollectionName)
    }

    var playDurationText: String {
        AppConstants.durationText(seconds: playDurationSeconds)
    }

    var breakDurationText: String {
        AppConstants.durationText(seconds: breakDurationSeconds)
    }
}
