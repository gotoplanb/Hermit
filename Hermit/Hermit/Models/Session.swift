import Foundation

struct Session: Codable, Identifiable {
    var id: UUID
    var displayName: String
    var hostID: UUID
    var tmuxSessionName: String?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        hostID: UUID,
        tmuxSessionName: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.hostID = hostID
        self.tmuxSessionName = tmuxSessionName
        self.createdAt = createdAt
    }
}
