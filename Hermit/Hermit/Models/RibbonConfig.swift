import Foundation

struct RibbonConfig: Codable {
    var buttons: [RibbonButton]

    static let `default` = RibbonConfig(buttons: [
        RibbonButton(label: "1", labelType: .text, action: .sendString("1")),
        RibbonButton(label: "2", labelType: .text, action: .sendString("2")),
        RibbonButton(label: "return", labelType: .sfSymbol, action: .sendString("\r")),
        RibbonButton(label: "esc", labelType: .text, action: .sendString("\u{1B}")),
        RibbonButton(label: "mic.fill", labelType: .sfSymbol, action: .voiceInput),
    ])
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
