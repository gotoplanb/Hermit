import SwiftUI

struct NewSessionView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    @State private var displayName = ""
    @State private var tmuxSessionName = ""
    @State private var selectedHostID: UUID?
    @State private var showingNewHost = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Session") {
                    TextField("Display Name", text: $displayName)
                    TextField("tmux Session Name (optional)", text: $tmuxSessionName)
                }

                Section("Host") {
                    if dataStore.hosts.isEmpty {
                        Text("No hosts configured")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Select Host", selection: $selectedHostID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.hosts) { host in
                                Text(host.displayName).tag(host.id as UUID?)
                            }
                        }
                    }

                    Button("Create New Host") {
                        showingNewHost = true
                    }
                }

                if let hostID = selectedHostID,
                   let host = dataStore.hosts.first(where: { $0.id == hostID }) {
                    Section("Host Details") {
                        LabeledContent("Hostname", value: host.hostname)
                        LabeledContent("Port", value: "\(host.port)")
                        LabeledContent("Username", value: host.username)
                    }
                }
            }
            .navigationTitle("New Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveSession() }
                        .disabled(displayName.isEmpty || selectedHostID == nil)
                }
            }
            .sheet(isPresented: $showingNewHost) {
                NewHostView { newHost in
                    selectedHostID = newHost.id
                }
            }
        }
    }

    private func saveSession() {
        guard let hostID = selectedHostID else { return }
        let session = Session(
            displayName: displayName,
            hostID: hostID,
            tmuxSessionName: tmuxSessionName.isEmpty ? nil : tmuxSessionName
        )
        dataStore.addSession(session)
        dismiss()
    }
}
