import Core
import Foundation

final class AggregateMetricsStore {
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
        self.storeURL = folderURL.appendingPathComponent("aggregate-metrics.json", isDirectory: false)
    }

    var persistenceDescription: String {
        storeURL.path
    }

    func load() -> AggregateTypingMetrics {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return AggregateTypingMetrics()
        }

        do {
            let data = try Data(contentsOf: storeURL)
            return try decoder.decode(AggregateTypingMetrics.self, from: data)
        } catch {
            return AggregateTypingMetrics()
        }
    }

    func save(_ metrics: AggregateTypingMetrics) throws {
        let folderURL = storeURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let data = try encoder.encode(metrics)
        try data.write(to: storeURL, options: [.atomic])
    }

    func clear() throws {
        guard fileManager.fileExists(atPath: storeURL.path) else {
            return
        }

        try fileManager.removeItem(at: storeURL)
    }
}
