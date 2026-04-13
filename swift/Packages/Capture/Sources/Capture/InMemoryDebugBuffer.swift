import Core
import Foundation

/// Keeps debug-only captured text in RAM. This type intentionally has no file I/O.
final class InMemoryDebugBuffer {
    private let maxPreviewCharacters: Int
    private let maxEvents: Int

    private(set) var previewText: String
    private(set) var events: [DebugPreviewEvent]

    init(
        maxPreviewCharacters: Int = 200,
        maxEvents: Int = 24
    ) {
        self.maxPreviewCharacters = maxPreviewCharacters
        self.maxEvents = maxEvents
        self.previewText = ""
        self.events = []
    }

    func append(
        renderedValue: String,
        kind: String,
        keyCode: Int64,
        timestamp: Date = Date()
    ) {
        previewText.append(renderedValue)
        if previewText.count > maxPreviewCharacters {
            previewText = String(previewText.suffix(maxPreviewCharacters))
        }

        events.insert(
            DebugPreviewEvent(
                timestamp: timestamp,
                kind: kind,
                renderedValue: renderedValue,
                keyCode: keyCode
            ),
            at: 0
        )

        if events.count > maxEvents {
            events.removeLast(events.count - maxEvents)
        }
    }

    func reset() {
        previewText = ""
        events.removeAll(keepingCapacity: true)
    }
}
