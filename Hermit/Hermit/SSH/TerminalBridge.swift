import SwiftUI
import WebKit

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
        config.userContentController = controller

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
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
    private var buffer: [String] = []

    func writeToTerminal(_ data: String) {
        if isReady {
            sendToJS(data)
        } else {
            buffer.append(data)
        }
    }

    func fitTerminal() {
        webView?.evaluateJavaScript("fitTerminal();")
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
