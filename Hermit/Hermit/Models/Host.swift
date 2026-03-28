import Foundation

struct Host: Codable, Identifiable {
    var id: UUID
    var displayName: String
    var hostname: String
    var port: Int
    var username: String
    var privateKeyRef: String
    var ribbonConfigs: [RibbonConfig]
    var createdAt: Date

    /// First ribbon config, for backward compatibility.
    var ribbonConfig: RibbonConfig {
        ribbonConfigs.first ?? .default
    }

    init(
        id: UUID = UUID(),
        displayName: String,
        hostname: String,
        port: Int = 22,
        username: String,
        privateKeyRef: String = "",
        ribbonConfigs: [RibbonConfig] = RibbonConfig.presets,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.hostname = hostname
        self.port = port
        self.username = username
        self.privateKeyRef = privateKeyRef
        self.ribbonConfigs = ribbonConfigs
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, displayName, hostname, port, username, privateKeyRef
        case ribbonConfigs, ribbonConfig, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        displayName = try c.decode(String.self, forKey: .displayName)
        hostname = try c.decode(String.self, forKey: .hostname)
        port = try c.decode(Int.self, forKey: .port)
        username = try c.decode(String.self, forKey: .username)
        privateKeyRef = try c.decode(String.self, forKey: .privateKeyRef)
        createdAt = try c.decode(Date.self, forKey: .createdAt)

        // Migrate from single ribbonConfig to ribbonConfigs array
        if let configs = try? c.decode([RibbonConfig].self, forKey: .ribbonConfigs) {
            ribbonConfigs = configs
        } else if let single = try? c.decode(RibbonConfig.self, forKey: .ribbonConfig) {
            ribbonConfigs = [single, .planMode]
        } else {
            ribbonConfigs = RibbonConfig.presets
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(hostname, forKey: .hostname)
        try c.encode(port, forKey: .port)
        try c.encode(username, forKey: .username)
        try c.encode(privateKeyRef, forKey: .privateKeyRef)
        try c.encode(ribbonConfigs, forKey: .ribbonConfigs)
        try c.encode(createdAt, forKey: .createdAt)
    }
}
