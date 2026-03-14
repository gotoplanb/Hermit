import Foundation

enum VoiceProvider: String, Codable {
    case none
    case superWhisper
}

struct AppSettings: Codable {
    var voiceProvider: VoiceProvider

    static let `default` = AppSettings(voiceProvider: .none)

    static func load() -> AppSettings {
        guard let data = UserDefaults.standard.data(forKey: "appSettings"),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "appSettings")
        }
    }
}
