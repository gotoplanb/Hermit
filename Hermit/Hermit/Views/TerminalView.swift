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
    // Set when ↑Page is pressed; cleared (with a `q` to tmux) by Copy Recent / Mic so the
    // user isn't stranded in tmux copy mode after scrolling back.
    @State private var inTmuxCopyMode = false

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
                webViewStore.copyRecentLines {
                    exitTmuxCopyModeIfNeeded()
                }
                flashCopiedToast()
            } label: {
                Label("Copy Recent", systemImage: "doc.on.doc")
                    .font(.system(.body, weight: .medium))
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)

            Button {
                // tmux: prefix (Ctrl-B) + PgUp — enters copy mode on the first press and
                // scrolls up one page; subsequent presses keep scrolling (prefix+PgUp in
                // copy mode re-runs `copy-mode -u`).
                ssh.send(data: "\u{02}\u{1B}[5~")
                inTmuxCopyMode = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                    Text("Page")
                }
                .font(.system(.body, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .accessibilityLabel("Page up in tmux")

            Button {
                // PgDn without the tmux prefix: scrolls down inside copy mode and auto-exits
                // when the bottom is reached. The prefix would route prefix+PgDn (no default
                // binding) and do nothing in copy mode.
                ssh.send(data: "\u{1B}[6~")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                    Text("Page")
                }
                .font(.system(.body, weight: .medium))
                .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .accessibilityLabel("Page down in tmux")

            Button {
                exitTmuxCopyModeIfNeeded()
                triggerVoiceInput()
            } label: {
                Image(systemName: "mic.fill")
                    .font(.body)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .accessibilityLabel("Voice input")
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

    private func triggerVoiceInput() {
        let settings = AppSettings.load()
        voiceCoordinator.handleVoiceButton(settings: settings)
    }

    private func exitTmuxCopyModeIfNeeded() {
        guard inTmuxCopyMode else { return }
        ssh.send(data: "q")
        inTmuxCopyMode = false
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
