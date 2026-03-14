import UIKit

enum SuperWhisperProvider {
    private static let superWhisperScheme = "superwhisper://transcribe"
    private static let callbackURL = "hermit://voice-callback"

    static var isAvailable: Bool {
        guard let url = URL(string: superWhisperScheme) else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    static func openForTranscription() {
        guard let url = URL(string: "\(superWhisperScheme)?callback=\(callbackURL)") else { return }
        UIApplication.shared.open(url)
    }
}
