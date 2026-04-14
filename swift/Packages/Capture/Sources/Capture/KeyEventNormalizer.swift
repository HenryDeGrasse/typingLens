import Core
import CoreGraphics
import Foundation

struct ClassifiedKeyEvent {
    let timestamp: Date
    let keyCode: Int64
    let eventPhase: ObservedKeyEventPhase
    let kind: String
    let debugRenderedValue: String
    let advancedAggregateToken: String?
    let keyClass: KeyClass
    let isBackspace: Bool
    let isAutoRepeat: Bool
    let countsAsPrintable: Bool
    let shouldUseInProfile: Bool
    let shouldTrackDwell: Bool
}

enum KeyEventNormalizer {
    private static let modifierKeyCodes: Set<Int64> = [
        54, 55, 56, 57, 58, 59, 60, 61, 62, 63
    ]

    private static let navigationKeyCodes: Set<Int64> = [
        53, 71, 72, 73, 74, 75, 76, 77, 78, 79, 80,
        96, 97, 98, 99, 100, 101, 103, 105, 107, 109,
        111, 113, 114, 115, 116, 117, 118, 119, 120,
        121, 122, 123, 124, 125, 126
    ]

    static func classify(_ observedEvent: ObservedKeyEvent) -> ClassifiedKeyEvent {
        let keyClass = keyClass(for: observedEvent)
        let suppressForProfile = observedEvent.flags.contains(.maskCommand)
            || observedEvent.flags.contains(.maskControl)
            || observedEvent.isAutoRepeat

        let shouldTrackDwell = true
        let isProfileRelevantKeyClass: Bool = [
            .letter,
            .number,
            .punctuation,
            .whitespace,
            .returnKey,
            .backspace
        ].contains(keyClass)

        let shouldUseInProfile = observedEvent.phase == .keyDown
            && isProfileRelevantKeyClass
            && !suppressForProfile

        return ClassifiedKeyEvent(
            timestamp: observedEvent.timestamp,
            keyCode: observedEvent.keyCode,
            eventPhase: observedEvent.phase,
            kind: observedEvent.kind,
            debugRenderedValue: observedEvent.renderedValue,
            advancedAggregateToken: advancedAggregateToken(for: observedEvent),
            keyClass: keyClass,
            isBackspace: observedEvent.isBackspace,
            isAutoRepeat: observedEvent.isAutoRepeat,
            countsAsPrintable: [.letter, .number, .punctuation].contains(keyClass),
            shouldUseInProfile: shouldUseInProfile,
            shouldTrackDwell: shouldTrackDwell && isProfileRelevantKeyClass && !suppressForProfile
        )
    }

    private static func keyClass(for observedEvent: ObservedKeyEvent) -> KeyClass {
        if observedEvent.isBackspace {
            return .backspace
        }

        if modifierKeyCodes.contains(observedEvent.keyCode) {
            return .modifier
        }

        if navigationKeyCodes.contains(observedEvent.keyCode) {
            return .navigation
        }

        switch observedEvent.renderedValue {
        case "␠", "⇥":
            return .whitespace
        case "↩︎":
            return .returnKey
        default:
            break
        }

        if observedEvent.renderedValue.hasPrefix("[keyCode:") {
            return .other
        }

        let cleanedValue = observedEvent.renderedValue.trimmingCharacters(in: .controlCharacters)
        guard !cleanedValue.isEmpty else {
            return .other
        }

        if cleanedValue.range(of: "^[A-Za-z]$", options: .regularExpression) != nil {
            return .letter
        }

        if cleanedValue.range(of: "^[0-9]$", options: .regularExpression) != nil {
            return .number
        }

        if cleanedValue.count == 1 {
            return .punctuation
        }

        return .other
    }

    private static func advancedAggregateToken(for observedEvent: ObservedKeyEvent) -> String? {
        guard observedEvent.phase == .keyDown else {
            return nil
        }

        if observedEvent.flags.contains(.maskCommand) || observedEvent.flags.contains(.maskControl) || observedEvent.isAutoRepeat {
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
        guard !cleanedValue.isEmpty, cleanedValue.count == 1 else {
            return nil
        }

        return cleanedValue.lowercased()
    }
}
