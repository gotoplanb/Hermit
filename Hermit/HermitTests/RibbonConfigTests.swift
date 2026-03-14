import Testing
import Foundation
@testable import Hermit

@Suite("RibbonConfig Tests")
struct RibbonConfigTests {
    @Test func defaultConfigHasFiveButtons() {
        let config = RibbonConfig.default
        #expect(config.buttons.count == 5)
    }

    @Test func defaultButtonLabels() {
        let labels = RibbonConfig.default.buttons.map(\.label)
        #expect(labels == ["1", "2", "3", "esc", "mic.fill"])
    }

    @Test func escButtonSendsEscByte() throws {
        let escButton = RibbonConfig.default.buttons[3]
        guard case .sendString(let value) = escButton.action else {
            Issue.record("Expected sendString action")
            return
        }
        #expect(value == "\u{1B}")
        #expect(value.unicodeScalars.first?.value == 0x1B)
    }

    @Test func numberButtonsSendWithNewline() throws {
        for i in 0..<3 {
            let button = RibbonConfig.default.buttons[i]
            guard case .sendString(let value) = button.action else {
                Issue.record("Expected sendString action for button \(i)")
                return
            }
            #expect(value == "\(i + 1)\n")
        }
    }

    @Test func micButtonIsVoiceInput() {
        let mic = RibbonConfig.default.buttons[4]
        guard case .voiceInput = mic.action else {
            Issue.record("Expected voiceInput action")
            return
        }
        #expect(mic.labelType == .sfSymbol)
    }

    @Test func ribbonConfigRoundTrip() throws {
        let config = RibbonConfig.default
        let data = try JSONEncoder.hermit.encode(config)
        let decoded = try JSONDecoder.hermit.decode(RibbonConfig.self, from: data)
        #expect(decoded.buttons.count == config.buttons.count)
    }
}
