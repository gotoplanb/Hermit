import Foundation
import UIKit

@Observable
final class VoiceInputCoordinator {
    var isShowingVoiceModal = false
    var transcribedText = ""

    func handleVoiceButton(settings: AppSettings) {
        switch settings.voiceProvider {
        case .superWhisper:
            if SuperWhisperProvider.isAvailable {
                SuperWhisperProvider.openForTranscription()
                return
            }
            // Fall through to empty modal if Super Whisper not installed
            fallthrough
        case .none:
            transcribedText = ""
            isShowingVoiceModal = true
        }
    }

    func handleCallbackURL(_ url: URL) {
        guard url.scheme == "hermit",
              url.host == "voice-callback",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let text = components.queryItems?.first(where: { $0.name == "text" })?.value else {
            return
        }
        transcribedText = text
        isShowingVoiceModal = true
    }
}
