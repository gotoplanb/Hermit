import Testing
import Foundation
@testable import Hermit

@Suite("Model Codable Tests")
struct ModelTests {
    @Test func hostRoundTrip() throws {
        let host = Host(
            displayName: "Test Mac",
            hostname: "192.168.1.1",
            port: 22,
            username: "dev",
            privateKeyRef: "key-ref-123"
        )
        let data = try JSONEncoder.hermit.encode(host)
        let decoded = try JSONDecoder.hermit.decode(Host.self, from: data)
        #expect(decoded.displayName == host.displayName)
        #expect(decoded.hostname == host.hostname)
        #expect(decoded.port == host.port)
        #expect(decoded.username == host.username)
        #expect(decoded.privateKeyRef == host.privateKeyRef)
    }

    @Test func sessionRoundTrip() throws {
        let session = Session(
            displayName: "claude-session",
            hostID: UUID(),
            tmuxSessionName: "claude"
        )
        let data = try JSONEncoder.hermit.encode(session)
        let decoded = try JSONDecoder.hermit.decode(Session.self, from: data)
        #expect(decoded.displayName == session.displayName)
        #expect(decoded.tmuxSessionName == session.tmuxSessionName)
    }

    @Test func sessionWithNilTmux() throws {
        let session = Session(displayName: "raw-shell", hostID: UUID())
        let data = try JSONEncoder.hermit.encode(session)
        let decoded = try JSONDecoder.hermit.decode(Session.self, from: data)
        #expect(decoded.tmuxSessionName == nil)
    }
}
