import Foundation

@Observable
final class DataStore {
    var hosts: [Host] = []
    var sessions: [Session] = []
    var iCloudAvailable: Bool { iCloudURL != nil }

    private let localFileURL: URL
    private let iCloudURL: URL?
    private var metadataQuery: NSMetadataQuery?

    private var fileURL: URL {
        iCloudURL ?? localFileURL
    }

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.localFileURL = docs.appendingPathComponent("hermit-data.json")

        // Try to get iCloud ubiquitous container
        if let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.zeromissionllc.hermit") {
            let iCloudDocsURL = containerURL.appendingPathComponent("Documents")
            try? FileManager.default.createDirectory(at: iCloudDocsURL, withIntermediateDirectories: true)
            self.iCloudURL = iCloudDocsURL.appendingPathComponent("hermit-data.json")
        } else {
            self.iCloudURL = nil
        }

        migrateLocalToiCloudIfNeeded()
        load()
        createFileIfNeeded()
        startWatchingForChanges()
    }

    deinit {
        metadataQuery?.stop()
    }

    // MARK: - Persistence

    func load() {
        let url = fileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            var data: Data?
            var readError: NSError?
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: url, options: [], error: &readError) { coordURL in
                data = try? Data(contentsOf: coordURL)
            }
            if let readError { throw readError }
            guard let data else { return }

            let backup = try JSONDecoder.hermit.decode(BackupData.self, from: data)
            self.hosts = backup.hosts.map { migrateHost($0) }
            self.sessions = backup.sessions
        } catch {
            print("Failed to load data: \(error)")
        }
    }

    func save() {
        do {
            let backup = BackupData(
                version: 1,
                exportedAt: Date(),
                hosts: hosts,
                sessions: sessions
            )
            let data = try JSONEncoder.hermit.encode(backup)
            let url = fileURL

            var writeError: NSError?
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &writeError) { coordURL in
                try? data.write(to: coordURL, options: .atomic)
            }
            if let writeError {
                print("Failed to save data: \(writeError)")
            }
        } catch {
            print("Failed to save data: \(error)")
        }
    }

    // MARK: - Host CRUD

    func addHost(_ host: Host) {
        hosts.append(host)
        save()
    }

    func deleteHost(_ host: Host) {
        sessions.removeAll { $0.hostID == host.id }
        hosts.removeAll { $0.id == host.id }
        save()
    }

    func host(for session: Session) -> Host? {
        hosts.first { $0.id == session.hostID }
    }

    // MARK: - Session CRUD

    func addSession(_ session: Session) {
        sessions.append(session)
        save()
    }

    func deleteSession(_ session: Session) {
        sessions.removeAll { $0.id == session.id }
        save()
    }

    func sessions(for host: Host) -> [Session] {
        sessions.filter { $0.hostID == host.id }
    }

    private func migrateHost(_ host: Host) -> Host {
        var host = host
        // Always sync ribbon config to current defaults
        // During active development, this ensures all hosts pick up button changes
        host.ribbonConfig = .default
        return host
    }

    private func createFileIfNeeded() {
        let url = fileURL
        if !FileManager.default.fileExists(atPath: url.path) {
            save()
        }
    }

    // MARK: - iCloud Sync

    private func migrateLocalToiCloudIfNeeded() {
        guard let iCloudURL else { return }

        // If local file exists but iCloud file doesn't, migrate
        if FileManager.default.fileExists(atPath: localFileURL.path),
           !FileManager.default.fileExists(atPath: iCloudURL.path) {
            do {
                let data = try Data(contentsOf: localFileURL)
                try data.write(to: iCloudURL, options: .atomic)
                try FileManager.default.removeItem(at: localFileURL)
            } catch {
                print("Failed to migrate to iCloud: \(error)")
            }
        }
    }

    private func startWatchingForChanges() {
        guard iCloudURL != nil else { return }

        let query = NSMetadataQuery()
        query.searchScopes = [NSMetadataQueryUbiquitousDocumentsScope]
        query.predicate = NSPredicate(format: "%K == %@", NSMetadataItemFSNameKey, "hermit-data.json")

        NotificationCenter.default.addObserver(
            forName: .NSMetadataQueryDidUpdate,
            object: query,
            queue: .main
        ) { [weak self] _ in
            self?.load()
        }

        query.start()
        metadataQuery = query
    }
}

struct BackupData: Codable {
    var version: Int
    var exportedAt: Date
    var hosts: [Host]
    var sessions: [Session]
}

extension JSONEncoder {
    static let hermit: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
}

extension JSONDecoder {
    static let hermit: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}
