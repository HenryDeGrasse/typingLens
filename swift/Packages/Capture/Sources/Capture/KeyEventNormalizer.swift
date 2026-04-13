import CoreGraphics
import Foundation

struct ClassifiedKeyEvent {
    let timestamp: Date
    let keyCode: Int64
    let kind: String
    let debugRenderedValue: String
    let aggregateToken: String?
    let isBackspace: Bool
}

enum KeyEventNormalizer {
    static func classify(_ observedEvent: ObservedKeyEvent) -> ClassifiedKeyEvent {
        ClassifiedKeyEvent(
            timestamp: observedEvent.timestamp,
            keyCode: observedEvent.keyCode,
            kind: observedEvent.kind,
            debugRenderedValue: observedEvent.renderedValue,
            aggregateToken: aggregateToken(for: observedEvent),
            isBackspace: observedEvent.isBackspace
        )
    }

    private static func aggregateToken(for observedEvent: ObservedKeyEvent) -> String? {
        if observedEvent.flags.contains(.maskCommand) || observedEvent.flags.contains(.maskControl) {
            return nil
        }

        if observedEvent.isBackspace {
            return "⌫"
        }

        switch observedEvent.renderedValue {
        case "␠":
            return "␠"
        case "↩︎":
            return "↩︎"
        case "⇥":
            return "⇥"
        case "⌫":
            return "⌫"
        case "⎋":
            return "⎋"
        default:
            break
        }

        if observedEvent.renderedValue.hasPrefix("[keyCode:") {
            return nil
        }

        let cleanedValue = observedEvent.renderedValue.trimmingCharacters(in: .controlCharacters)
        guard !cleanedValue.isEmpty else {
            return nil
        }

        guard cleanedValue.count == 1 else {
            return nil
        }

        return cleanedValue.lowercased()
    }
}
