import Testing
import Foundation
@testable import Hermit

@Suite("URL Scheme Tests")
struct URLSchemeTests {
    @Test func parsesVoiceCallbackURL() {
        let coordinator = VoiceInputCoordinator()
        let url = URL(string: "hermit://voice-callback?text=hello%20world")!
        coordinator.handleCallbackURL(url)
        #expect(coordinator.transcribedText == "hello world")
        #expect(coordinator.isShowingVoiceModal == true)
    }

    @Test func ignoresInvalidScheme() {
        let coordinator = VoiceInputCoordinator()
        let url = URL(string: "other://voice-callback?text=hello")!
        coordinator.handleCallbackURL(url)
        #expect(coordinator.isShowingVoiceModal == false)
    }

    @Test func ignoresInvalidHost() {
        let coordinator = VoiceInputCoordinator()
        let url = URL(string: "hermit://other-action?text=hello")!
        coordinator.handleCallbackURL(url)
        #expect(coordinator.isShowingVoiceModal == false)
    }

    @Test func handlesMissingTextParameter() {
        let coordinator = VoiceInputCoordinator()
        let url = URL(string: "hermit://voice-callback")!
        coordinator.handleCallbackURL(url)
        #expect(coordinator.isShowingVoiceModal == false)
    }

    @Test func handlesEncodedSpecialCharacters() {
        let coordinator = VoiceInputCoordinator()
        let url = URL(string: "hermit://voice-callback?text=say%20%22hello%22%20%26%20goodbye")!
        coordinator.handleCallbackURL(url)
        #expect(coordinator.transcribedText == "say \"hello\" & goodbye")
    }
}
