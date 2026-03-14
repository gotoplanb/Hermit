import Foundation

@Observable
final class SSHConnectionManager {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    var state: ConnectionState = .disconnected
    var onDataReceived: ((String) -> Void)?

    func connect(host: Host, tmuxSessionName: String?) async {
        state = .connecting

        // Check if we have a key reference
        if !host.privateKeyRef.isEmpty {
            do {
                let keyData = try KeychainManager.load(key: host.privateKeyRef)
                guard String(data: keyData, encoding: .utf8) != nil else {
                    state = .failed("Invalid private key data")
                    return
                }
            } catch {
                state = .failed("Key not found: \(error.localizedDescription)")
                return
            }
        }

        // TODO: Replace with Citadel SSH connection
        // Citadel integration requires:
        // 1. SSHClient.connect(host:port:authenticationMethod:)
        // 2. Open a shell channel
        // 3. If tmuxSessionName set, send "tmux new-session -As <name>\n"
        // 4. Pipe channel data to onDataReceived
        // 5. Accept input via send(data:)

        // For now, show a placeholder message in the terminal
        state = .connected
        let welcomeMessage = "Hermit SSH Client\r\n"
            + "Host: \(host.hostname):\(host.port)\r\n"
            + "User: \(host.username)\r\n"
        if let tmux = tmuxSessionName {
            onDataReceived?(welcomeMessage + "tmux session: \(tmux)\r\n\r\n")
        } else {
            onDataReceived?(welcomeMessage + "(raw shell)\r\n\r\n")
        }
        onDataReceived?("SSH connection not yet implemented.\r\nUI and navigation are functional.\r\n\r\n$ ")
    }

    func send(data: String) {
        // TODO: Write data to SSH channel
        // For now, echo input back to terminal
        onDataReceived?(data)
    }

    func disconnect() {
        // TODO: Close SSH channel and connection
        state = .disconnected
    }
}
