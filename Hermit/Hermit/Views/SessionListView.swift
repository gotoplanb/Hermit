import SwiftUI

struct SessionListView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingNewSession = false
    @State private var showingSettings = false
    @State private var selectedSessionID: Session.ID?
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var selectedSession: Session? {
        guard let selectedSessionID else { return nil }
        return dataStore.sessions.first { $0.id == selectedSessionID }
    }

    /// A split view: on wide screens (the iPhone Duo unfolded) sessions sit in a sidebar
    /// next to the terminal; on narrow ones (iPhone, Duo folded) it collapses into the
    /// familiar list -> push -> back stack. The sidebar toggle hides the list when you
    /// want the terminal full-width.
    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            Group {
                if dataStore.hosts.isEmpty {
                    ContentUnavailableView(
                        "No Sessions",
                        systemImage: "terminal",
                        description: Text("Add a session to get started.")
                    )
                } else {
                    sessionList
                }
            }
            .navigationTitle("Hermit")
            .toolbar {
                // In the split sidebar the top row also holds the sidebar toggle, and
                // with Settings there too the title truncates to "He…" — so Settings
                // moves to the sidebar's bottom bar when the split is showing.
                ToolbarItem(placement: horizontalSizeClass == .regular ? .bottomBar : .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNewSession = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewSession) {
                NewSessionView()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 320)
        } detail: {
            if let selectedSession {
                // A new identity per session: switching sessions tears down the old
                // terminal (disconnecting it) and connects the new one.
                TerminalView(session: selectedSession)
                    .id(selectedSession.id)
            } else {
                ContentUnavailableView(
                    "No Session Selected",
                    systemImage: "terminal",
                    description: Text("Choose a session from the list.")
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .onChange(of: dataStore.sessions.map(\.id)) { _, ids in
            // The open session was deleted: close its terminal.
            if let selectedSessionID, !ids.contains(selectedSessionID) {
                self.selectedSessionID = nil
            }
        }
    }

    private var sessionList: some View {
        List(selection: $selectedSessionID) {
            ForEach(dataStore.hosts) { host in
                let hostSessions = dataStore.sessions(for: host).sorted {
                    // Raw shell (no tmux) first, then alphabetical by display name
                    if $0.tmuxSessionName == nil && $1.tmuxSessionName != nil { return true }
                    if $0.tmuxSessionName != nil && $1.tmuxSessionName == nil { return false }
                    return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
                }
                if !hostSessions.isEmpty {
                    Section(host.displayName) {
                        ForEach(hostSessions) { session in
                            // A selectable row (not a Button) so the split view can
                            // highlight the open session and, when collapsed, push it.
                            NavigationLink(value: session.id) {
                                VStack(alignment: .leading) {
                                    Text(session.displayName)
                                        .font(.body)
                                    if let tmux = session.tmuxSessionName {
                                        Text("tmux: \(tmux)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    dataStore.deleteSession(session)
                                }
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets {
                                dataStore.deleteSession(hostSessions[index])
                            }
                        }
                    }
                }
            }
        }
    }
}

extension Session: Hashable {
    static func == (lhs: Session, rhs: Session) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
