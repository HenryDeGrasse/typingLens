import Core
import Foundation

final class ManualExclusionStore {
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storeURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder

        self.decoder = JSONDecoder()

        let applicationSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "ai.gauntlet.typinglens"
        let folderURL = applicationSupportDirectory.appendingPathComponent(bundleIdentifier, isDirectory: true)
        self.storeURL = folderURL.appendingPathComponent("manual-excluded-apps.json", isDirectory: false)
    }

    func load() -> [ExcludedApplication] {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storeURL)
            return try decoder.decode([ExcludedApplication].self, from: data)
        } catch {
            return []
        }
    }

    func save(_ excludedApplications: [ExcludedApplication]) throws {
        let folderURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(excludedApplications)
        try data.write(to: storeURL, options: [.atomic])
    }
}
