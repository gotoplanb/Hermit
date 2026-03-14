import SwiftUI

struct SessionListView: View {
    @Environment(DataStore.self) private var dataStore
    @State private var showingNewSession = false
    @State private var showingSettings = false
    @State private var selectedSession: Session?

    var body: some View {
        NavigationStack {
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
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
            .navigationDestination(item: $selectedSession) { session in
                TerminalView(session: session)
            }
        }
    }

    private var sessionList: some View {
        List {
            ForEach(dataStore.hosts) { host in
                let hostSessions = dataStore.sessions(for: host)
                if !hostSessions.isEmpty {
                    Section(host.displayName) {
                        ForEach(hostSessions) { session in
                            Button {
                                selectedSession = session
                            } label: {
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
