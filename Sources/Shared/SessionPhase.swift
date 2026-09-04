import Foundation

enum SessionPhase: String, Codable, Equatable {
    case ready
    case playing
    case `break`
    case waitingParent
    case error
}
