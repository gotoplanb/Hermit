import SwiftUI
import WebKit

/// WKWebView without WebKit's form accessory bar (the ^ ∨ ✓ strip above the keyboard).
/// Its previous/next-field arrows mean nothing in a terminal, and it costs ~2 rows
/// whenever xterm's input is focused. WebKit asks the web view for its
/// `inputAccessoryView`, so overriding it here suppresses the bar. The ✓ (dismiss)
/// is replaced by the hide-keyboard button in TerminalView's toolbar.
final class TerminalWKWebView: WKWebView {
    override var inputAccessoryView: UIView? { nil }
}

struct TerminalWebView: UIViewRepresentable {
    let onInput: (String) -> Void
    let onSizeChanged: ((Int, Int) -> Void)?
    let webViewStore: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "terminalInput")
        controller.add(context.coordinator, name: "terminalReady")
        controller.add(context.coordinator, name: "terminalSize")
        controller.add(context.coordinator, name: "terminalSelection")
        config.userContentController = controller

        let webView = TerminalWKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        // Match xterm's theme background (#1e1e1e in terminal.html) so the safe-area
        // inset WebKit leaves below the last row blends in instead of showing a black band.
        webView.backgroundColor = UIColor(red: 0x1e / 255, green: 0x1e / 255, blue: 0x1e / 255, alpha: 1)
        webView.scrollView.isScrollEnabled = false

        if let htmlURL = Bundle.main.url(forResource: "terminal", withExtension: "html") {
            webView.loadFileURL(htmlURL, allowingReadAccessTo: htmlURL.deletingLastPathComponent())
        }

        webViewStore.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onInput: onInput, onSizeChanged: onSizeChanged, webViewStore: webViewStore)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onInput: (String) -> Void
        let onSizeChanged: ((Int, Int) -> Void)?
        let webViewStore: WebViewStore

        init(onInput: @escaping (String) -> Void, onSizeChanged: ((Int, Int) -> Void)?, webViewStore: WebViewStore) {
            self.onInput = onInput
            self.onSizeChanged = onSizeChanged
            self.webViewStore = webViewStore
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            switch message.name {
            case "terminalReady":
                webViewStore.isReady = true
            case "terminalInput":
                if let text = message.body as? String {
                    onInput(text)
                }
            case "terminalSize":
                if let dict = message.body as? [String: Any],
                   let cols = dict["cols"] as? Int,
                   let rows = dict["rows"] as? Int {
                    onSizeChanged?(cols, rows)
                }
            case "terminalSelection":
                if let text = message.body as? String {
                    webViewStore.hasSelection = !text.isEmpty
                }
            default:
                break
            }
        }
    }
}

@Observable
final class WebViewStore {
    var webView: WKWebView?
    var isReady = false {
        didSet {
            if isReady { flushBuffer() }
        }
    }
    var hasSelection = false
    private var buffer: [String] = []

    func writeToTerminal(_ data: String) {
        if isReady {
            sendToJS(data)
        } else {
            buffer.append(data)
        }
    }

    /// Blur xterm's hidden textarea so the software keyboard goes away.
    func dismissKeyboard() {
        webView?.evaluateJavaScript("term.blur();")
        webView?.endEditing(true)
    }

    func fitTerminal() {
        webView?.evaluateJavaScript("fitTerminal();")
    }

    func copyRecentLines(_ count: Int = 30, completion: @escaping () -> Void = {}) {
        webView?.evaluateJavaScript("getContextLines(\(count));") { result, _ in
            if let text = result as? String, !text.isEmpty {
                UIPasteboard.general.string = text
            }
            completion()
        }
    }

    func setSelectMode(_ enabled: Bool) {
        webView?.evaluateJavaScript("setSelectMode(\(enabled));")
        if !enabled {
            hasSelection = false
        }
    }

    private func flushBuffer() {
        for data in buffer {
            sendToJS(data)
        }
        buffer.removeAll()
    }

    private func sendToJS(_ data: String) {
        let escaped = data
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "writeToTerminal('\(escaped)');"
        webView?.evaluateJavaScript(js)
    }
}
