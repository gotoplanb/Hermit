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
        GeometryReader { proxy in
            // Wide screens (the iPhone Duo's unfolded inner display, which is landscape in
            // its native "portrait") are short on rows, so the ribbon moves to a vertical
            // rail on the trailing edge instead of eating height at the bottom.
            // AnyLayout keeps the web view's identity across a fold/unfold, so the
            // terminal isn't torn down and rebuilt when the layout flips.
            let axis: Axis = proxy.size.width > proxy.size.height ? .vertical : .horizontal
            let layout = axis == .vertical
                ? AnyLayout(HStackLayout(spacing: 0))
                : AnyLayout(VStackLayout(spacing: 0))

            layout {
                TerminalWebView(
                    onInput: { text in ssh.send(data: text) },
                    onSizeChanged: { cols, rows in ssh.resize(cols: cols, rows: rows) },
                    webViewStore: webViewStore
                )
                .ignoresSafeArea(.container, edges: .bottom)

                ribbonBar(config: activeRibbon, axis: axis)
            }
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
                // Wrap in bracketed-paste markers so the TUI treats the dictated text
                // as a single paste regardless of arrival timing — the \r after the
                // closing marker is then unambiguously an Enter keypress. Sending it
                // as one write also avoids a race between two detached Tasks, which
                // could reorder the Enter ahead of long text on slow links.
                ssh.send(data: "\u{1B}[200~\(finalText)\u{1B}[201~\r")
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
    private func ribbonBar(config: RibbonConfig, axis: Axis) -> some View {
        Group {
            if isOnCopyRibbon {
                selectionRibbonBar(axis: axis)
            } else {
                normalRibbonBar(config: config, axis: axis)
            }
        }
        .frame(maxWidth: axis == .horizontal ? .infinity : nil,
               maxHeight: axis == .vertical ? .infinity : nil)
        // Bleed only into the home-indicator area, not up behind the navigation bar.
        .background(.regularMaterial, ignoresSafeAreaEdges: .bottom)
    }

    /// Lays ribbon buttons out in a row (bottom bar) or a column (side rail). Buttons
    /// share the available length instead of using fixed widths, so the bar can never
    /// be wider than the screen. (A fixed-width bar used to overflow 402pt screens and
    /// push the whole terminal off the leading edge, clipping the first column.)
    @ViewBuilder
    private func ribbonStack(axis: Axis, @ViewBuilder content: () -> some View) -> some View {
        switch axis {
        case .horizontal:
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        case .vertical:
            VStack(spacing: 10) {
                Spacer(minLength: 0) // bottom-align: closest to a thumb holding the device
                content()
            }
            .frame(width: Self.railButtonWidth)
            .padding(.horizontal, 10)
            .padding(.vertical, 12)
        }
    }

    private static let railButtonWidth: CGFloat = 56

    @State private var showCopiedToast = false

    private func selectionRibbonBar(axis: Axis) -> some View {
        ribbonStack(axis: axis) {
            Button {
                webViewStore.copyRecentLines {
                    exitTmuxCopyModeIfNeeded()
                }
                flashCopiedToast()
            } label: {
                // Longest label that fits: "Copy Recent" on roomy rows, "Copy" on narrow
                // phones, icon-only in the rail. VoiceOver always reads "Copy Recent".
                ViewThatFits(in: .horizontal) {
                    Label("Copy Recent", systemImage: "doc.on.doc").fixedSize()
                    Label("Copy", systemImage: "doc.on.doc").fixedSize()
                    Image(systemName: "doc.on.doc")
                }
                .font(.system(.body, weight: .medium))
                .modifier(RibbonLabelFrame(axis: axis))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle)
            .accessibilityLabel("Copy Recent")

            Button {
                // tmux: prefix (Ctrl-B) + PgUp — enters copy mode on the first press and
                // scrolls up one page; subsequent presses keep scrolling (prefix+PgUp in
                // copy mode re-runs `copy-mode -u`).
                ssh.send(data: "\u{02}\u{1B}[5~")
                inTmuxCopyMode = true
            } label: {
                pageLabel(systemImage: "arrow.up", axis: axis)
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
                pageLabel(systemImage: "arrow.down", axis: axis)
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
                    .modifier(RibbonLabelFrame(axis: axis))
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.roundedRectangle)
            .accessibilityLabel("Voice input")
        }
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

    /// "↑ Page" in a row; arrow over a small "Page" caption in the narrow rail.
    private func pageLabel(systemImage: String, axis: Axis) -> some View {
        let layout = axis == .vertical
            ? AnyLayout(VStackLayout(spacing: 2))
            : AnyLayout(HStackLayout(spacing: 4))
        return layout {
            Image(systemName: systemImage)
            Text("Page")
                .font(axis == .vertical ? .caption2 : .system(.body, weight: .medium))
        }
        .font(.system(.body, weight: .medium))
        .modifier(RibbonLabelFrame(axis: axis))
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

    private func normalRibbonBar(config: RibbonConfig, axis: Axis) -> some View {
        ribbonStack(axis: axis) {
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
                    .modifier(RibbonLabelFrame(axis: axis))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle)
            }
        }
    }

    private func handleRibbonButton(_ button: RibbonButton) {
        switch button.action {
        case .sendString(let string):
            ssh.send(data: string)
        case .voiceInput:
            let settings = AppSettings.load()
            voiceCoordinator.handleVoiceButton(settings: settings)
        case .acceptSuggestion:
            // Claude Code now requires Tab to accept the dim suggestion before Enter
            // submits. Send Tab first, then \r as a standalone write so the TUI
            // processes the accept before the submit (same pattern as voice input).
            ssh.send(data: "\t")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                ssh.send(data: "\r")
            }
        }
    }
}

/// Sizing for a ribbon button label. In a bottom row, buttons split the width evenly
/// (capped so they don't turn into slabs on wide screens); in the side rail they take
/// the rail's width. Height is a 44pt minimum touch target, and text scales down
/// rather than pushing the bar wider than the screen.
private struct RibbonLabelFrame: ViewModifier {
    let axis: Axis

    func body(content: Content) -> some View {
        content
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            // minWidth 0: the button's own padding keeps the tap target >= 44pt wide,
            // and a fixed label minimum is what let the old bar overflow narrow screens.
            .frame(minWidth: 0, maxWidth: axis == .horizontal ? 120 : .infinity, minHeight: 44)
    }
}
