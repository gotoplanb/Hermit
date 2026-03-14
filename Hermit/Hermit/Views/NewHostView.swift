import SwiftUI

struct NewHostView: View {
    @Environment(DataStore.self) private var dataStore
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((Host) -> Void)?

    @State private var displayName = ""
    @State private var hostname = ""
    @State private var port = "22"
    @State private var username = ""
    @State private var privateKeyPEM = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    TextField("Display Name", text: $displayName)
                    TextField("Hostname", text: $hostname)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Private Key") {
                    TextEditor(text: $privateKeyPEM)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 120)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Text("Paste your PEM-encoded private key above.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("New Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveHost() }
                        .disabled(displayName.isEmpty || hostname.isEmpty || username.isEmpty)
                }
            }
        }
    }

    private func saveHost() {
        let portNumber = Int(port) ?? 22
        let keychainRef = "ssh-key-\(UUID().uuidString)"

        if !privateKeyPEM.isEmpty {
            guard let keyData = privateKeyPEM.data(using: .utf8) else {
                errorMessage = "Invalid key data"
                return
            }
            do {
                try KeychainManager.save(key: keychainRef, data: keyData)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
        }

        let host = Host(
            displayName: displayName,
            hostname: hostname,
            port: portNumber,
            username: username,
            privateKeyRef: privateKeyPEM.isEmpty ? "" : keychainRef
        )
        dataStore.addHost(host)
        onCreated?(host)
        dismiss()
    }
}
