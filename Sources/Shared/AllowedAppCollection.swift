import FamilyControls
import Foundation

struct AllowedAppCollection: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var selection: FamilyActivitySelection
    var createdAt: Date
    var updatedAt: Date

    var applicationCount: Int {
        selection.applicationTokens.count
    }

    static func make(name: String, selection: FamilyActivitySelection = FamilyActivitySelection()) -> AllowedAppCollection {
        let now = Date()
        return AllowedAppCollection(
            id: UUID(),
            name: name,
            selection: selection.sanitizedForAllowedApps(),
            createdAt: now,
            updatedAt: now
        )
    }

    func renamed(_ newName: String) -> AllowedAppCollection {
        var copy = self
        copy.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.updatedAt = Date()
        return copy
    }

    func replacingSelection(_ selection: FamilyActivitySelection) -> AllowedAppCollection {
        var copy = self
        copy.selection = selection.sanitizedForAllowedApps()
        copy.updatedAt = Date()
        return copy
    }
}
