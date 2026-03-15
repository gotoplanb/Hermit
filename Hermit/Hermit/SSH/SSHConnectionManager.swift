import Foundation
import Citadel
import Crypto
import NIOCore
import NIOSSH
import os

private let logger = Logger(subsystem: "com.zeromissionllc.hermit", category: "SSH")

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

    private var client: SSHClient?
    private var stdinWriter: TTYStdinWriter?
    private var connectionTask: Task<Void, Never>?

    func connect(host: Host, tmuxSessionName: String?) async {
        state = .connecting

        do {
            logger.info("Connecting to \(host.hostname):\(host.port) as \(host.username)")
            let authMethod = try buildAuthMethod(for: host)
            logger.info("Auth method built successfully")

            let sshClient = try await SSHClient.connect(
                host: host.hostname,
                port: host.port,
                authenticationMethod: authMethod,
                hostKeyValidator: .acceptAnything(),
                reconnect: .never
            )
            self.client = sshClient
            state = .connected

            let command: String
            if let tmux = tmuxSessionName {
                command = "tmux new-session -As \(tmux)"
            } else {
                command = ""
            }

            try await sshClient.withPTY(
                .init(
                    wantReply: true,
                    term: "xterm-256color",
                    terminalCharacterWidth: 80,
                    terminalRowHeight: 24,
                    terminalPixelWidth: 0,
                    terminalPixelHeight: 0,
                    terminalModes: .init([:])
                )
            ) { [weak self] inbound, outbound in
                self?.stdinWriter = outbound

                // Send tmux attach command if specified
                if !command.isEmpty {
                    var buf = ByteBufferAllocator().buffer(capacity: command.utf8.count + 1)
                    buf.writeString(command + "\n")
                    try await outbound.write(buf)
                }

                for try await event in inbound {
                    switch event {
                    case .stdout(let buffer):
                        if let str = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) {
                            await MainActor.run {
                                self?.onDataReceived?(str)
                            }
                        }
                    case .stderr(let buffer):
                        if let str = buffer.getString(at: buffer.readerIndex, length: buffer.readableBytes) {
                            await MainActor.run {
                                self?.onDataReceived?(str)
                            }
                        }
                    }
                }
            }
        } catch {
            logger.error("SSH connection failed: \(error)")
            await MainActor.run {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    func send(data: String) {
        guard let writer = stdinWriter else {
            logger.warning("send() called but stdinWriter is nil")
            return
        }
        Task {
            var buf = ByteBufferAllocator().buffer(capacity: data.utf8.count)
            buf.writeString(data)
            try? await writer.write(buf)
        }
    }

    func disconnect() {
        connectionTask?.cancel()
        connectionTask = nil
        stdinWriter = nil
        Task {
            try? await client?.close()
            client = nil
        }
        state = .disconnected
    }

    private func buildAuthMethod(for host: Host) throws -> SSHAuthenticationMethod {
        if host.privateKeyRef.isEmpty {
            throw SSHError.noKey
        }

        // Try Keychain first, fall back to dev key file in Documents
        let keyData: Data
        do {
            keyData = try KeychainManager.load(key: host.privateKeyRef)
        } catch {
            // Dev fallback: check for key file in app Documents
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let devKeyURL = docs.appendingPathComponent("dev-ssh-key")
            guard FileManager.default.fileExists(atPath: devKeyURL.path) else {
                throw SSHError.noKey
            }
            keyData = try Data(contentsOf: devKeyURL)
        }

        guard let keyString = String(data: keyData, encoding: .utf8) else {
            throw SSHError.invalidKey
        }

        // Try to parse as ed25519 OpenSSH key
        if keyString.contains("OPENSSH") {
            let rawKey = try parseOpenSSHEd25519(keyString)
            let privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: rawKey)
            return .ed25519(username: host.username, privateKey: privateKey)
        }

        // Fall back to RSA
        let privateKey = try Insecure.RSA.PrivateKey(sshRsa: keyString)
        return .rsa(username: host.username, privateKey: privateKey)
    }

    private func parseOpenSSHEd25519(_ pemString: String) throws -> Data {
        // OpenSSH private key format for ed25519:
        // Strip header/footer, base64 decode, then extract the 32-byte private key
        let lines = pemString.components(separatedBy: "\n")
            .filter { !$0.hasPrefix("-----") && !$0.isEmpty }
        let base64String = lines.joined()
        guard let decoded = Data(base64Encoded: base64String) else {
            throw SSHError.invalidKey
        }

        // OpenSSH format: magic, ciphername, kdfname, kdfoptions, number of keys,
        // public key, private key section
        // For unencrypted ed25519, the private key (seed) is 32 bytes
        // located after the public key in the private section
        // The private section contains: checkint, checkint, keytype, pubkey(32), privkey(64), comment
        // The privkey(64) = seed(32) + pubkey(32)

        let magic = "openssh-key-v1\0"
        guard decoded.count > magic.utf8.count,
              String(data: decoded.prefix(magic.utf8.count), encoding: .utf8) == magic else {
            throw SSHError.invalidKey
        }

        // Find the ed25519 private key seed (32 bytes) in the decoded data
        // Search for the key type string "ssh-ed25519" in the private section
        // The seed follows: keytype_len(4) + keytype + pubkey_len(4) + pubkey(32) + privkey_len(4) + privkey(64)
        // We want bytes 0-31 of the 64-byte privkey (that's the seed)

        // Simpler approach: scan for the second occurrence of "ssh-ed25519" (in private section)
        let keyTypeBytes: [UInt8] = Array("ssh-ed25519".utf8)
        let bytes = Array(decoded)
        var positions: [Int] = []
        for i in 0..<(bytes.count - keyTypeBytes.count) {
            if Array(bytes[i..<(i + keyTypeBytes.count)]) == keyTypeBytes {
                positions.append(i)
            }
        }

        guard positions.count >= 2 else {
            throw SSHError.invalidKey
        }

        // Second occurrence is in the private section
        let privSectionKeyTypeStart = positions[1]
        // From the raw string start: "ssh-ed25519"(11 bytes)
        // Then 4 bytes pubkey length + 32 bytes pubkey
        // Then 4 bytes privkey length + 64 bytes privkey (first 32 = seed)
        let offset = privSectionKeyTypeStart + keyTypeBytes.count + 4 + 32 + 4
        guard offset + 32 <= bytes.count else {
            throw SSHError.invalidKey
        }

        return Data(bytes[offset..<(offset + 32)])
    }
}

enum SSHError: LocalizedError {
    case noKey
    case invalidKey

    var errorDescription: String? {
        switch self {
        case .noKey: "No SSH key configured for this host"
        case .invalidKey: "Could not parse SSH private key"
        }
    }
}
