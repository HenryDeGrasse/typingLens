import Core
import Foundation
import os

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

enum TypingProfileStoreError: Error {
    case applicationSupportDirectoryUnavailable
}

final class TypingProfileStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL?
    private(set) var lastPersistenceError: String?
    private static let logger = Logger(subsystem: "ai.gauntlet.typinglens", category: "TypingProfileStore")

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        (self.encoder, self.decoder) = Self.makeCoders()

        guard let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            self.storeURL = nil
            self.lastPersistenceError = "Application Support directory unavailable. Typing profile will not be saved."
            Self.logger.error("Application Support directory unavailable; typing profile persistence disabled.")
            return
        }

        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.gauntlet.typinglens"
        let folderURL = applicationSupportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        self.storeURL = folderURL.appendingPathComponent("typing-profile-store.json", isDirectory: false)
    }

    init(storeURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        (self.encoder, self.decoder) = Self.makeCoders()
        self.storeURL = storeURL
    }

    private static func makeCoders() -> (JSONEncoder, JSONDecoder) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        return (encoder, decoder)
    }

    var persistenceDescription: String {
        storeURL?.path ?? "(unavailable)"
    }

    func load() -> PersistedProfileStoreSnapshot {
        guard let storeURL else { return PersistedProfileStoreSnapshot() }
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return PersistedProfileStoreSnapshot()
        }

        do {
            let data = try Data(contentsOf: storeURL)
            return try decoder.decode(PersistedProfileStoreSnapshot.self, from: data)
        } catch {
            lastPersistenceError = "Could not read typing profile store: \(error.localizedDescription). Starting from an empty profile."
            Self.logger.error("Failed to load typing profile store: \(error.localizedDescription, privacy: .public)")
            return PersistedProfileStoreSnapshot()
        }
    }

    func save(_ snapshot: PersistedProfileStoreSnapshot) throws {
        guard let storeURL else {
            throw TypingProfileStoreError.applicationSupportDirectoryUnavailable
        }

        let folderURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(snapshot)
        try data.write(to: storeURL, options: [.atomic])
        lastPersistenceError = nil
    }

    func clear() throws {
        guard let storeURL,
              fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        try fileManager.removeItem(at: storeURL)
    }
}
