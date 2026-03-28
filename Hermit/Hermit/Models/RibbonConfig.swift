import Foundation

struct RibbonConfig: Codable {
    var name: String
    var buttons: [RibbonButton]

    static let `default` = RibbonConfig(name: "Default", buttons: [
        RibbonButton(label: "1", labelType: .text, action: .sendString("1")),
        RibbonButton(label: "2", labelType: .text, action: .sendString("2")),
        RibbonButton(label: "return", labelType: .sfSymbol, action: .sendString("\r")),
        RibbonButton(label: "escape", labelType: .sfSymbol, action: .sendString("\u{1B}")),
        RibbonButton(label: "mic.fill", labelType: .sfSymbol, action: .voiceInput),
    ])

    static let planMode = RibbonConfig(name: "Plan Mode", buttons: [
        RibbonButton(label: "1", labelType: .text, action: .sendString("1")),
        RibbonButton(label: "2", labelType: .text, action: .sendString("2")),
        RibbonButton(label: "3", labelType: .text, action: .sendString("3")),
        RibbonButton(label: "4", labelType: .text, action: .sendString("4")),
        RibbonButton(label: "5", labelType: .text, action: .sendString("5")),
    ])

    static let presets: [RibbonConfig] = [.default, .planMode]
}

struct RibbonButton: Codable, Identifiable {
    var id: UUID
    var label: String
    var labelType: LabelType
    var action: ButtonAction

    init(
        id: UUID = UUID(),
        label: String,
        labelType: LabelType,
        action: ButtonAction
    ) {
        self.id = id
        self.label = label
        self.labelType = labelType
        self.action = action
    }
}

enum LabelType: String, Codable {
    case text
    case sfSymbol
}

enum ButtonAction: Codable {
    case sendString(String)
    case voiceInput
}
