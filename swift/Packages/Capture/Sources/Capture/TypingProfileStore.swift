import Core
import Foundation

struct PersistedProfileDayRecord: Codable {
    var dayIdentifier: String
    var summary: TypingProfileSummary
}

struct PersistedProfileStoreSnapshot: Codable {
    var schemaVersion: Int
    var dayRecords: [PersistedProfileDayRecord]

    init(
        schemaVersion: Int = 1,
        dayRecords: [PersistedProfileDayRecord] = []
    ) {
        self.schemaVersion = schemaVersion
        self.dayRecords = dayRecords
    }
}

final class TypingProfileStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder

        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.gauntlet.typinglens"
        let folderURL = applicationSupportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        self.storeURL = folderURL.appendingPathComponent("typing-profile-store.json", isDirectory: false)
    }

    var persistenceDescription: String {
        storeURL.path
    }

    func load() -> PersistedProfileStoreSnapshot {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return PersistedProfileStoreSnapshot()
        }

        do {
            let data = try Data(contentsOf: storeURL)
            return try decoder.decode(PersistedProfileStoreSnapshot.self, from: data)
        } catch {
            return PersistedProfileStoreSnapshot()
        }
    }

    func save(_ snapshot: PersistedProfileStoreSnapshot) throws {
        let folderURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: storeURL, options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        try fileManager.removeItem(at: storeURL)
    }
}
