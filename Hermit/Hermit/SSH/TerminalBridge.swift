import SwiftUI
import WebKit

struct TerminalWebView: UIViewRepresentable {
    let onInput: (String) -> Void
    let webViewStore: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.add(context.coordinator, name: "terminalInput")
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
        Coordinator(onInput: onInput)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        let onInput: (String) -> Void

        init(onInput: @escaping (String) -> Void) {
            self.onInput = onInput
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            if let text = message.body as? String {
                onInput(text)
            }
        }
    }
}

@Observable
final class WebViewStore {
    var webView: WKWebView?

    func writeToTerminal(_ data: String) {
        let escaped = data
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        let js = "writeToTerminal('\(escaped)');"
        webView?.evaluateJavaScript(js)
    }
}
