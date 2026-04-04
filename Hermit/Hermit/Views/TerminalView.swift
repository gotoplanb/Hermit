import SwiftUI

struct TerminalView: View {
    let session: Session

    @Environment(DataStore.self) private var dataStore
    @Environment(VoiceInputCoordinator.self) private var voiceCoordinator
    @State private var ssh = SSHConnectionManager()
    @State private var webViewStore = WebViewStore()
    @State private var voiceText = ""
    @State private var showingVoiceModal = false
    @State private var showingSnippets = false
    @State private var activeRibbonIndex = 0

    private var host: Host? { dataStore.host(for: session) }

    private var ribbonConfigs: [RibbonConfig] {
        host?.ribbonConfigs ?? RibbonConfig.presets
    }

    /// Total ribbon slots: user ribbons + copy ribbon as the last one
    private var totalRibbonCount: Int {
        ribbonConfigs.count + 1
    }

    private var isOnCopyRibbon: Bool {
        activeRibbonIndex % totalRibbonCount == ribbonConfigs.count
    }

    private var activeRibbon: RibbonConfig {
        ribbonConfigs[activeRibbonIndex % ribbonConfigs.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            TerminalWebView(
                onInput: { text in ssh.send(data: text) },
                onSizeChanged: { cols, rows in ssh.resize(cols: cols, rows: rows) },
                webViewStore: webViewStore
            )
            .ignoresSafeArea(.container, edges: .bottom)

            ribbonBar(config: activeRibbon)
        }
        .navigationTitle(session.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                connectionIndicator
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeRibbonIndex = (activeRibbonIndex + 1) % totalRibbonCount
                        }
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .accessibilityLabel(isOnCopyRibbon ? "Switch ribbon: Copy" : "Switch ribbon: \(activeRibbon.name)")
                    Button {
                        showingSnippets = true
                    } label: {
                        Image(systemName: "list.bullet.rectangle")
                    }
                    .accessibilityLabel("Snippets")
                }
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
        .sheet(isPresented: $showingSnippets) {
            SnippetsView { command in
                ssh.send(data: command)
            }
        }
        .onChange(of: isOnCopyRibbon) { _, onCopy in
            webViewStore.setSelectMode(onCopy)
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

    @ViewBuilder
    private func ribbonBar(config: RibbonConfig) -> some View {
        if isOnCopyRibbon {
            selectionRibbonBar
        } else {
            normalRibbonBar(config: config)
        }
    }

    @State private var showCopiedToast = false

    private var selectionRibbonBar: some View {
        HStack(spacing: 12) {
            Button {
                webViewStore.copyRecentLines()
                flashCopiedToast()
            } label: {
                Label("Copy Recent", systemImage: "doc.on.doc")
                    .font(.system(.body, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)

            Button {
                webViewStore.copyAll()
                flashCopiedToast()
            } label: {
                Text("Copy All")
                    .font(.system(.body, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .overlay {
            if showCopiedToast {
                Text("Copied!")
                    .font(.system(.body, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.green, in: Capsule())
                    .transition(.opacity.combined(with: .scale))
            }
        }
    }

    private func flashCopiedToast() {
        withAnimation(.easeIn(duration: 0.15)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCopiedToast = false
            }
        }
    }

    private func normalRibbonBar(config: RibbonConfig) -> some View {
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
