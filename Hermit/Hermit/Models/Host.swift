import Foundation

struct Host: Codable, Identifiable {
    var id: UUID
    var displayName: String
    var hostname: String
    var port: Int
    var username: String
    var privateKeyRef: String
    var ribbonConfig: RibbonConfig
    var createdAt: Date

    init(
        id: UUID = UUID(),
        displayName: String,
        hostname: String,
        port: Int = 22,
        username: String,
        privateKeyRef: String = "",
        ribbonConfig: RibbonConfig = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.hostname = hostname
        self.port = port
        self.username = username
        self.privateKeyRef = privateKeyRef
        self.ribbonConfig = ribbonConfig
        self.createdAt = createdAt
    }
}
