import SwiftUI

struct TerminalView: View {
    let session: Session

    @Environment(DataStore.self) private var dataStore
    @Environment(VoiceInputCoordinator.self) private var voiceCoordinator
    @State private var ssh = SSHConnectionManager()
    @State private var webViewStore = WebViewStore()
    @State private var voiceText = ""
    @State private var showingVoiceModal = false

    private var host: Host? { dataStore.host(for: session) }

    var body: some View {
        VStack(spacing: 0) {
            TerminalWebView(
                onInput: { text in ssh.send(data: text) },
                webViewStore: webViewStore
            )
            .ignoresSafeArea(.container, edges: .bottom)

            if let host {
                ribbonBar(config: host.ribbonConfig)
            }
        }
        .navigationTitle(session.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                connectionIndicator
            }
        }
        .task {
            guard let host else { return }
            ssh.onDataReceived = { data in
                webViewStore.writeToTerminal(data)
            }
            await ssh.connect(host: host, tmuxSessionName: session.tmuxSessionName)
        }
        .onDisappear {
            ssh.disconnect()
        }
        .sheet(isPresented: $showingVoiceModal) {
            VoiceInputModal(text: $voiceText) { finalText in
                ssh.send(data: finalText + "\r")
            }
        }
        .onChange(of: voiceCoordinator.isShowingVoiceModal) { _, show in
            if show {
                voiceText = voiceCoordinator.transcribedText
                showingVoiceModal = true
                voiceCoordinator.isShowingVoiceModal = false
            }
        }
    }

    private var connectionIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(indicatorColor)
                .frame(width: 8, height: 8)
            Text(session.displayName)
                .font(.headline)
        }
    }

    private var indicatorColor: Color {
        switch ssh.state {
        case .connected: .green
        case .connecting: .yellow
        case .disconnected: .gray
        case .failed: .red
        }
    }

    private func ribbonBar(config: RibbonConfig) -> some View {
        HStack(spacing: 12) {
            ForEach(config.buttons) { button in
                Button {
                    handleRibbonButton(button)
                } label: {
                    Group {
                        switch button.labelType {
                        case .text:
                            Text(button.label)
                                .font(.system(.body, design: .monospaced, weight: .medium))
                        case .sfSymbol:
                            Image(systemName: button.label)
                                .font(.body)
                        }
                    }
                    .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
    }

    private func handleRibbonButton(_ button: RibbonButton) {
        switch button.action {
        case .sendString(let string):
            ssh.send(data: string)
        case .voiceInput:
            let settings = AppSettings.load()
            voiceCoordinator.handleVoiceButton(settings: settings)
        }
    }
}
